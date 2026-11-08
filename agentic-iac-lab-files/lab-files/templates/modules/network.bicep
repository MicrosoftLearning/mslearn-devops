@description('Azure region for the network resources.')
param location string

@description('Name of the virtual network.')
param vnetName string

@description('Virtual network address space.')
param vnetAddressPrefix string

@description('Name of the application subnet.')
param appSubnetName string

@description('Application subnet address prefix.')
param appSubnetAddressPrefix string

@description('Name of the data subnet.')
param dataSubnetName string

@description('Data subnet address prefix.')
param dataSubnetAddressPrefix string

@description('Name of the virtual machine network interface.')
param nicName string

@description('Tags applied to network resources that support tags.')
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource appSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: appSubnetName
  properties: {
    addressPrefix: appSubnetAddressPrefix
  }
}

resource dataSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: dataSubnetName
  properties: {
    addressPrefix: dataSubnetAddressPrefix
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: appSubnet.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output appSubnetId string = appSubnet.id
output nicId string = nic.id