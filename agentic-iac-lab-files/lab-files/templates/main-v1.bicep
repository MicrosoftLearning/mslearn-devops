// ============================================================
// main-v1.bicep — Hub-Spoke Network (Version 1 — Incomplete)
//
// Lab Use: Task 5 — Documentation Generation
// This is the OLDER version of the template. Compare it to the
// improved template you build in Task 2 to generate a changelog.
//
// What is missing compared to the v2 template:
//   - Azure Bastion and AzureBastionSubnet
//   - Log Analytics workspace
//   - Diagnostic settings for the firewall
//   - User-Assigned Managed Identity
//   - CostCenter parameter (required by org policy — causes deployment failure)
//   - Tags missing on several resources
//   - Uses older API versions (2022-07-01)
// ============================================================

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used in resource naming and tags.')
@allowed(['training', 'staging', 'production'])
param environment string = 'training'

@description('Owner alias for tagging.')
param owner string

// ---- Variables ----

var hubVnetName = 'vnet-hub-${environment}'
var spokeVnetName = 'vnet-spoke-${environment}'
var firewallName = 'fw-iaclab-${environment}'
var firewallPublicIpName = 'pip-fw-iaclab-${environment}'
var nsgAppName = 'nsg-app-${environment}'

var hubAddressPrefix = '10.0.0.0/16'
var spokeAddressPrefix = '10.1.0.0/16'

// ---- NSG: Application Subnet ----

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgAppName
  location: location
  // Missing tags
  properties: {
    securityRules: [
      {
        name: 'Deny-SSH-Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Block inbound SSH from the internet'
        }
      }
      {
        name: 'Deny-RDP-Inbound'
        properties: {
          priority: 110
          protocol: 'Tcp'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          description: 'Block inbound RDP from the internet'
        }
      }
    ]
  }
}

// ---- Hub Virtual Network ----

resource hubVnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: hubVnetName
  location: location
  tags: {
    Environment: environment
    Owner: owner
    // Missing: CostCenter tag
  }
  properties: {
    addressSpace: {
      addressPrefixes: [ hubAddressPrefix ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        // NOTE: This is /27 — too small for Azure Firewall (requires /26 minimum).
        // This will cause a deployment failure. Fix identified in Task 6.
        properties: {
          addressPrefix: '10.0.0.0/27'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.1.0/27'
        }
      }
    ]
  }
}

// ---- Spoke Virtual Network ----

resource spokeVnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: spokeVnetName
  location: location
  tags: {
    Environment: environment
    Owner: owner
  }
  properties: {
    addressSpace: {
      addressPrefixes: [ spokeAddressPrefix ]
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.1.0.0/24'
          networkSecurityGroup: {
            id: nsgApp.id
          }
        }
      }
    ]
  }
}

// ---- VNet Peering: Hub → Spoke ----

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  parent: hubVnet
  name: 'hub-to-spoke'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

// ---- VNet Peering: Spoke → Hub ----

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  parent: spokeVnet
  name: 'spoke-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ---- Public IP for Azure Firewall ----

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: firewallPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  // Missing tags
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ---- Azure Firewall ----

resource firewall 'Microsoft.Network/azureFirewalls@2022-07-01' = {
  name: firewallName
  location: location
  tags: {
    Environment: environment
    Owner: owner
    // Missing: CostCenter tag
  }
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'fw-ipconfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'AzureFirewallSubnet')
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
    // No threat intelligence mode set (should be 'Alert' or 'Deny')
    // No firewall policy attached
  }
  dependsOn: [ hubVnet ]
}

// ---- Outputs ----

output hubVnetId string = hubVnet.id
output spokeVnetId string = spokeVnet.id
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIpAddress string = firewallPublicIp.properties.ipAddress
