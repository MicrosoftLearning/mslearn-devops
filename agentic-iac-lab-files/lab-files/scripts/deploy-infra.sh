#!/usr/bin/env bash
set -Eeuo pipefail

# Configuration
RESOURCE_GROUP="rg-agentic-iaclab"
LOCATION="eastus"

VNET_NAME="vnet-agentic-iaclab"
VNET_PREFIX="10.10.0.0/16"

APP_SUBNET_NAME="snet-app"
APP_SUBNET_PREFIX="10.10.1.0/24"
DATA_SUBNET_NAME="snet-data"
DATA_SUBNET_PREFIX="10.10.2.0/24"

VM_NAME="vm-iaclab"
VM_SIZE="Standard_B2s"
VM_IMAGE="Ubuntu2204"
VM_ADMIN_USERNAME="azureuser"
NIC_NAME="nic-vm-iaclab"

ENVIRONMENT_TAG_KEY="Environment"
ENVIRONMENT_TAG_VALUE="Training"
OWNER_TAG_KEY="Owner"
OWNER_TAG_VALUE="agentic-iaclab"

POLL_INTERVAL_SECONDS=15
VM_CREATION_TIMEOUT_SECONDS=900

TAGS=(
    "${ENVIRONMENT_TAG_KEY}=${ENVIRONMENT_TAG_VALUE}"
    "${OWNER_TAG_KEY}=${OWNER_TAG_VALUE}"
)

trap 'echo "ERROR: Command failed at line $LINENO: $BASH_COMMAND" >&2' ERR

log() {
    printf '\n==> %s\n' "$1"
}

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

validate_name() {
    local label="$1"
    local value="$2"

    [[ -n "$value" ]] || fail "$label cannot be empty."
    [[ "$value" =~ ^[a-zA-Z0-9._-]+$ ]] ||
        fail "$label contains unsupported characters: $value"
}

validate_cidr() {
    local label="$1"
    local cidr="$2"

    [[ "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] ||
        fail "$label is not a valid IPv4 CIDR: $cidr"

    local address="${cidr%/*}"
    local octet
    local octets

    IFS='.' read -r -a octets <<< "$address"

    for octet in "${octets[@]}"; do
        ((10#$octet <= 255)) ||
            fail "$label contains an invalid IPv4 octet: $cidr"
    done
}

validate_positive_integer() {
    local label="$1"
    local value="$2"

    [[ "$value" =~ ^[1-9][0-9]*$ ]] ||
        fail "$label must be a positive integer: $value"
}

tag_resource() {
    local resource_id="$1"

    az tag update \
        --resource-id "$resource_id" \
        --operation Merge \
        --tags "${TAGS[@]}" \
        --output none
}

wait_for_vm() {
    local elapsed=0
    local status

    log "Waiting for VM provisioning to complete"

    while ((elapsed < VM_CREATION_TIMEOUT_SECONDS)); do
        status="$(
            az vm show \
                --resource-group "$RESOURCE_GROUP" \
                --name "$VM_NAME" \
                --query provisioningState \
                --output tsv 2>/dev/null || true
        )"

        case "$status" in
            Succeeded)
                log "VM provisioning succeeded"
                return 0
                ;;
            Failed | Canceled)
                fail "VM provisioning ended with status: $status"
                ;;
            "")
                status="NotFound"
                ;;
        esac

        printf 'VM status: %s. Checking again in %s seconds...\n' \
            "$status" "$POLL_INTERVAL_SECONDS"

        sleep "$POLL_INTERVAL_SECONDS"
        elapsed=$((elapsed + POLL_INTERVAL_SECONDS))
    done

    fail "Timed out after ${VM_CREATION_TIMEOUT_SECONDS}s waiting for VM provisioning."
}

validate_name "Resource group name" "$RESOURCE_GROUP"
validate_name "VNet name" "$VNET_NAME"
validate_name "Application subnet name" "$APP_SUBNET_NAME"
validate_name "Data subnet name" "$DATA_SUBNET_NAME"
validate_name "VM name" "$VM_NAME"
validate_name "NIC name" "$NIC_NAME"

validate_cidr "VNet prefix" "$VNET_PREFIX"
validate_cidr "Application subnet prefix" "$APP_SUBNET_PREFIX"
validate_cidr "Data subnet prefix" "$DATA_SUBNET_PREFIX"

validate_positive_integer "Polling interval" "$POLL_INTERVAL_SECONDS"
validate_positive_integer "VM creation timeout" "$VM_CREATION_TIMEOUT_SECONDS"

[[ "$APP_SUBNET_PREFIX" != "$DATA_SUBNET_PREFIX" ]] ||
    fail "Subnet prefixes must be different."

command -v az >/dev/null 2>&1 ||
    fail "Azure CLI is not installed or is not in PATH."

az account show --output none 2>/dev/null ||
    fail "Not signed in to Azure. Run: az login"

az account list-locations \
    --query "[?name=='${LOCATION}'].name | [0]" \
    --output tsv |
    grep -qx "$LOCATION" ||
    fail "Azure location '$LOCATION' is unavailable or invalid."

log "Creating resource group"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags "${TAGS[@]}" \
    --output none

log "Creating virtual network"
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --location "$LOCATION" \
    --address-prefixes "$VNET_PREFIX" \
    --tags "${TAGS[@]}" \
    --output none

log "Creating application subnet"
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$APP_SUBNET_NAME" \
    --address-prefixes "$APP_SUBNET_PREFIX" \
    --output none

log "Creating data subnet"
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$DATA_SUBNET_NAME" \
    --address-prefixes "$DATA_SUBNET_PREFIX" \
    --output none

log "Creating VM network interface"
if ! az network nic show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --output none 2>/dev/null; then
    az network nic create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$NIC_NAME" \
        --location "$LOCATION" \
        --vnet-name "$VNET_NAME" \
        --subnet "$APP_SUBNET_NAME" \
        --tags "${TAGS[@]}" \
        --output none
fi

NIC_ID="$(
    az network nic show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$NIC_NAME" \
        --query id \
        --output tsv
)"
tag_resource "$NIC_ID"

log "Starting Ubuntu VM creation"
if ! az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --output none 2>/dev/null; then
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --location "$LOCATION" \
        --image "$VM_IMAGE" \
        --size "$VM_SIZE" \
        --admin-username "$VM_ADMIN_USERNAME" \
        --generate-ssh-keys \
        --nics "$NIC_ID" \
        --tags "${TAGS[@]}" \
        --no-wait \
        --output none
else
    log "VM already exists; creation skipped"
fi

wait_for_vm

VM_ID="$(
    az vm show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --query id \
        --output tsv
)"
tag_resource "$VM_ID"

log "Deployment completed successfully"
az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --query \
    "{name:name,location:location,size:hardwareProfile.vmSize,status:provisioningState}" \
    --output table