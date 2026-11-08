@description('Azure region for the virtual machine.')
param location string

@description('Name of the virtual machine.')
param vmName string

@description('Virtual machine size.')
param vmSize string

@description('Publisher of the virtual machine image.')
param vmImagePublisher string

@description('Offer of the virtual machine image.')
param vmImageOffer string

@description('SKU of the virtual machine image.')
param vmImageSku string

@description('Version of the virtual machine image.')
param vmImageVersion string

@description('Virtual machine administrator username.')
param vmAdminUsername string

@description('SSH public key used to authenticate to the virtual machine.')
@secure()
param sshPublicKey string

@description('Resource ID of the virtual machine network interface.')
param nicId string

@description('Tags applied to the virtual machine.')
param tags object

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmImageSku
        version: vmImageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${vmAdminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

output vmId string = vm.id
output provisioningState string = vm.properties.provisioningState