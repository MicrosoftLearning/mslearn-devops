#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Compute, Az.Network, Az.Resources

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Configuration
$RESOURCE_GROUP = 'rg-agentic-iaclab'
$LOCATION = 'eastus'

$VNET_NAME = 'vnet-agentic-iaclab'
$VNET_PREFIX = '10.10.0.0/16'

$APP_SUBNET_NAME = 'snet-app'
$APP_SUBNET_PREFIX = '10.10.1.0/24'
$DATA_SUBNET_NAME = 'snet-data'
$DATA_SUBNET_PREFIX = '10.10.2.0/24'

$VM_NAME = 'vm-iaclab'
$VM_SIZE = 'Standard_B2s'
$VM_IMAGE_PUBLISHER = 'Canonical'
$VM_IMAGE_OFFER = '0001-com-ubuntu-server-jammy'
$VM_IMAGE_SKU = '22_04-lts-gen2'
$VM_IMAGE_VERSION = 'latest'
$VM_ADMIN_USERNAME = 'azureuser'
$NIC_NAME = 'nic-vm-iaclab'
$SSH_PRIVATE_KEY_PATH = Join-Path $HOME '.ssh/id_rsa'
$SSH_PUBLIC_KEY_PATH = "$SSH_PRIVATE_KEY_PATH.pub"
$SSH_KEY_BITS = 4096

$ENVIRONMENT_TAG_KEY = 'Environment'
$ENVIRONMENT_TAG_VALUE = 'Training'
$OWNER_TAG_KEY = 'Owner'
$OWNER_TAG_VALUE = 'agentic-iaclab'

$POLL_INTERVAL_SECONDS = 15
$VM_CREATION_TIMEOUT_SECONDS = 900

$TAGS = @{
    $ENVIRONMENT_TAG_KEY = $ENVIRONMENT_TAG_VALUE
    $OWNER_TAG_KEY = $OWNER_TAG_VALUE
}

function Write-Log {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "`n==> $Message"
}

function Stop-WithError {
    param([Parameter(Mandatory)][string]$Message)

    throw $Message
}

function Test-ResourceName {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Stop-WithError "$Label cannot be empty."
    }
    if ($Value -notmatch '^[a-zA-Z0-9._-]+$') {
        Stop-WithError "$Label contains unsupported characters: $Value"
    }
}

function Test-Cidr {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Cidr
    )

    $cidrMatch = [regex]::Match($Cidr, '^(.+)/(\d{1,2})$')
    if (-not $cidrMatch.Success) {
        Stop-WithError "$Label is not a valid IPv4 CIDR: $Cidr"
    }

    $address = $null
    $isValidAddress = [System.Net.IPAddress]::TryParse(
        $cidrMatch.Groups[1].Value,
        [ref]$address
    )
    $prefixLength = [int]$cidrMatch.Groups[2].Value

    if (-not $isValidAddress -or
        $address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or
        $prefixLength -lt 0 -or
        $prefixLength -gt 32) {
        Stop-WithError "$Label is not a valid IPv4 CIDR: $Cidr"
    }
}

function Test-PositiveInteger {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][int]$Value
    )

    if ($Value -le 0) {
        Stop-WithError "$Label must be a positive integer: $Value"
    }
}

function Set-ResourceTags {
    param([Parameter(Mandatory)][string]$ResourceId)

    Update-AzTag -ResourceId $ResourceId -Tag $TAGS -Operation Merge | Out-Null
}

function Wait-ForVm {
    param([System.Management.Automation.Job]$CreationJob)

    $elapsed = 0
    Write-Log 'Waiting for VM provisioning to complete'

    while ($elapsed -lt $VM_CREATION_TIMEOUT_SECONDS) {
        if ($CreationJob -and $CreationJob.State -eq 'Failed') {
            $jobError = Receive-Job -Job $CreationJob -ErrorAction SilentlyContinue 2>&1 |
                Out-String
            Stop-WithError "VM creation job failed: $($jobError.Trim())"
        }

        $vm = Get-AzVM `
            -ResourceGroupName $RESOURCE_GROUP `
            -Name $VM_NAME `
            -ErrorAction SilentlyContinue
        $status = if ($vm) { $vm.ProvisioningState } else { 'NotFound' }

        switch ($status) {
            'Succeeded' {
                Write-Log 'VM provisioning succeeded'
                return
            }
            { $_ -in 'Failed', 'Canceled' } {
                Stop-WithError "VM provisioning ended with status: $status"
            }
        }

        Write-Host "VM status: $status. Checking again in $POLL_INTERVAL_SECONDS seconds..."
        Start-Sleep -Seconds $POLL_INTERVAL_SECONDS
        $elapsed += $POLL_INTERVAL_SECONDS
    }

    Stop-WithError "Timed out after ${VM_CREATION_TIMEOUT_SECONDS}s waiting for VM provisioning."
}

try {
    Test-ResourceName 'Resource group name' $RESOURCE_GROUP
    Test-ResourceName 'VNet name' $VNET_NAME
    Test-ResourceName 'Application subnet name' $APP_SUBNET_NAME
    Test-ResourceName 'Data subnet name' $DATA_SUBNET_NAME
    Test-ResourceName 'VM name' $VM_NAME
    Test-ResourceName 'NIC name' $NIC_NAME

    Test-Cidr 'VNet prefix' $VNET_PREFIX
    Test-Cidr 'Application subnet prefix' $APP_SUBNET_PREFIX
    Test-Cidr 'Data subnet prefix' $DATA_SUBNET_PREFIX

    Test-PositiveInteger 'Polling interval' $POLL_INTERVAL_SECONDS
    Test-PositiveInteger 'VM creation timeout' $VM_CREATION_TIMEOUT_SECONDS
    Test-PositiveInteger 'SSH key size' $SSH_KEY_BITS

    if ($APP_SUBNET_PREFIX -eq $DATA_SUBNET_PREFIX) {
        Stop-WithError 'Subnet prefixes must be different.'
    }

    if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
        Stop-WithError 'Not signed in to Azure. Run: Connect-AzAccount'
    }

    $azureLocation = Get-AzLocation |
        Where-Object Location -EQ $LOCATION |
        Select-Object -First 1
    if (-not $azureLocation) {
        Stop-WithError "Azure location '$LOCATION' is unavailable or invalid."
    }

    Write-Log 'Creating resource group'
    $resourceGroup = Get-AzResourceGroup -Name $RESOURCE_GROUP -ErrorAction SilentlyContinue
    if (-not $resourceGroup) {
        $resourceGroup = New-AzResourceGroup `
            -Name $RESOURCE_GROUP `
            -Location $LOCATION `
            -Tag $TAGS
    }
    Set-ResourceTags $resourceGroup.ResourceId

    Write-Log 'Creating virtual network'
    $vnet = Get-AzVirtualNetwork `
        -ResourceGroupName $RESOURCE_GROUP `
        -Name $VNET_NAME `
        -ErrorAction SilentlyContinue
    if (-not $vnet) {
        $vnet = New-AzVirtualNetwork `
            -ResourceGroupName $RESOURCE_GROUP `
            -Name $VNET_NAME `
            -Location $LOCATION `
            -AddressPrefix $VNET_PREFIX `
            -Tag $TAGS
    }
    Set-ResourceTags $vnet.Id

    Write-Log 'Creating application subnet'
    $appSubnet = Get-AzVirtualNetworkSubnetConfig `
        -VirtualNetwork $vnet `
        -Name $APP_SUBNET_NAME `
        -ErrorAction SilentlyContinue
    if (-not $appSubnet) {
        Add-AzVirtualNetworkSubnetConfig `
            -VirtualNetwork $vnet `
            -Name $APP_SUBNET_NAME `
            -AddressPrefix $APP_SUBNET_PREFIX | Out-Null
        $vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet
    }

    Write-Log 'Creating data subnet'
    $dataSubnet = Get-AzVirtualNetworkSubnetConfig `
        -VirtualNetwork $vnet `
        -Name $DATA_SUBNET_NAME `
        -ErrorAction SilentlyContinue
    if (-not $dataSubnet) {
        Add-AzVirtualNetworkSubnetConfig `
            -VirtualNetwork $vnet `
            -Name $DATA_SUBNET_NAME `
            -AddressPrefix $DATA_SUBNET_PREFIX | Out-Null
        $vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet
    }

    $appSubnet = Get-AzVirtualNetworkSubnetConfig `
        -VirtualNetwork $vnet `
        -Name $APP_SUBNET_NAME

    Write-Log 'Creating VM network interface'
    $nic = Get-AzNetworkInterface `
        -ResourceGroupName $RESOURCE_GROUP `
        -Name $NIC_NAME `
        -ErrorAction SilentlyContinue
    if (-not $nic) {
        $nic = New-AzNetworkInterface `
            -ResourceGroupName $RESOURCE_GROUP `
            -Name $NIC_NAME `
            -Location $LOCATION `
            -SubnetId $appSubnet.Id `
            -Tag $TAGS
    }
    $NIC_ID = $nic.Id
    Set-ResourceTags $NIC_ID

    Write-Log 'Starting Ubuntu VM creation'
    $vm = Get-AzVM `
        -ResourceGroupName $RESOURCE_GROUP `
        -Name $VM_NAME `
        -ErrorAction SilentlyContinue
    $vmCreationJob = $null

    if (-not $vm) {
        if (-not (Test-Path -LiteralPath $SSH_PUBLIC_KEY_PATH -PathType Leaf)) {
            $sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
            if (-not $sshKeygen) {
                Stop-WithError 'ssh-keygen is required to generate the VM SSH key.'
            }

            $sshDirectory = Split-Path -Parent $SSH_PRIVATE_KEY_PATH
            New-Item -ItemType Directory -Path $sshDirectory -Force | Out-Null
            & $sshKeygen.Source `
                -t rsa `
                -b $SSH_KEY_BITS `
                -f $SSH_PRIVATE_KEY_PATH `
                -N '' | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Stop-WithError "ssh-keygen exited with code $LASTEXITCODE."
            }
        }

        $sshPublicKey = (Get-Content -LiteralPath $SSH_PUBLIC_KEY_PATH -Raw).Trim()
        if ([string]::IsNullOrWhiteSpace($sshPublicKey)) {
            Stop-WithError "SSH public key is empty: $SSH_PUBLIC_KEY_PATH"
        }

        $placeholderPassword = ConvertTo-SecureString `
            -String "$(New-Guid)Aa1!" `
            -AsPlainText `
            -Force
        $credential = [pscredential]::new($VM_ADMIN_USERNAME, $placeholderPassword)

        $vmConfig = New-AzVMConfig `
            -VMName $VM_NAME `
            -VMSize $VM_SIZE `
            -Tags $TAGS
        $vmConfig = Set-AzVMOperatingSystem `
            -VM $vmConfig `
            -Linux `
            -ComputerName $VM_NAME `
            -Credential $credential `
            -DisablePasswordAuthentication
        $vmConfig = Add-AzVMSshPublicKey `
            -VM $vmConfig `
            -KeyData $sshPublicKey `
            -Path "/home/$VM_ADMIN_USERNAME/.ssh/authorized_keys"
        $vmConfig = Set-AzVMSourceImage `
            -VM $vmConfig `
            -PublisherName $VM_IMAGE_PUBLISHER `
            -Offer $VM_IMAGE_OFFER `
            -Skus $VM_IMAGE_SKU `
            -Version $VM_IMAGE_VERSION
        $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $NIC_ID

        $vmCreationJob = New-AzVM `
            -ResourceGroupName $RESOURCE_GROUP `
            -Location $LOCATION `
            -VM $vmConfig `
            -AsJob
    }
    else {
        Write-Log 'VM already exists; creation skipped'
    }

    Wait-ForVm -CreationJob $vmCreationJob

    $vm = Get-AzVM -ResourceGroupName $RESOURCE_GROUP -Name $VM_NAME
    $VM_ID = $vm.Id
    Set-ResourceTags $VM_ID

    Write-Log 'Deployment completed successfully'
    [pscustomobject]@{
        Name              = $vm.Name
        Location          = $vm.Location
        Size              = $vm.HardwareProfile.VmSize
        ProvisioningState = $vm.ProvisioningState
    } | Format-Table -AutoSize
}
catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}