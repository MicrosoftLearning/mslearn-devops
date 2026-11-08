targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'eastus'

@description('Name of the resource group to create.')
@minLength(1)
param resourceGroupName string = 'rg-agentic-iaclab'

@description('Name of the virtual network.')
@minLength(1)
param vnetName string = 'vnet-agentic-iaclab'

@description('Virtual network address space.')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Name of the application subnet.')
@minLength(1)
param appSubnetName string = 'snet-app'

@description('Application subnet address prefix.')
param appSubnetAddressPrefix string = '10.10.1.0/24'

@description('Name of the data subnet.')
@minLength(1)
param dataSubnetName string = 'snet-data'

@description('Data subnet address prefix.')
param dataSubnetAddressPrefix string = '10.10.2.0/24'

@description('Name of the virtual machine network interface.')
@minLength(1)
param nicName string = 'nic-vm-iaclab'

@description('Name of the virtual machine.')
@minLength(1)
param vmName string = 'vm-iaclab'

@description('Virtual machine size.')
param vmSize string = 'Standard_B2s'

@description('Publisher of the virtual machine image.')
param vmImagePublisher string = 'Canonical'

@description('Offer of the virtual machine image.')
param vmImageOffer string = '0001-com-ubuntu-server-jammy'

@description('SKU of the virtual machine image.')
param vmImageSku string = '22_04-lts-gen2'

@description('Version of the virtual machine image.')
param vmImageVersion string = 'latest'

@description('Virtual machine administrator username.')
@minLength(1)
param vmAdminUsername string = 'azureuser'

@description('SSH public key used to authenticate to the virtual machine.')
@secure()
param sshPublicKey string

@description('Tags applied to all resources that support tags.')
param tags object = {
  Environment: 'Training'
  Owner: 'agentic-iaclab'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module network 'modules/network.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    appSubnetName: appSubnetName
    appSubnetAddressPrefix: appSubnetAddressPrefix
    dataSubnetName: dataSubnetName
    dataSubnetAddressPrefix: dataSubnetAddressPrefix
    nicName: nicName
    tags: tags
  }
}

module virtualMachine 'modules/virtual-machine.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    vmName: vmName
    vmSize: vmSize
    vmImagePublisher: vmImagePublisher
    vmImageOffer: vmImageOffer
    vmImageSku: vmImageSku
    vmImageVersion: vmImageVersion
    vmAdminUsername: vmAdminUsername
    sshPublicKey: sshPublicKey
    nicId: network.outputs.nicId
    tags: tags
  }
}

output resourceGroupId string = resourceGroup.id
output vnetId string = network.outputs.vnetId
output nicId string = network.outputs.nicId
output vmId string = virtualMachine.outputs.vmId
output vmProvisioningState string = virtualMachine.outputs.provisioningState