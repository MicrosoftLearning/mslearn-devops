param accountName string
param location string
param deploymentName string = 'gpt-5.4-mini'
param modelName string = 'gpt-5.4-mini'
param modelVersion string = '2026-03-17'
@minValue(1)
param capacity int = 30

// This API supports Foundry projects and matches the tested starter deployment.
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: accountName
    allowProjectManagement: true
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}
resource model 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: account
  name: deploymentName
  sku: { name: 'GlobalStandard', capacity: capacity }
  properties: {
    model: { format: 'OpenAI', name: modelName, version: modelVersion }
  }
}
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: account
  name: 'eshop-catalog'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: { displayName: 'eShop catalog assistant' }
  dependsOn: [model]
}
output endpoint string = 'https://${accountName}.openai.azure.com/openai/v1/'
output name string = account.name
output projectEndpoint string = project.properties.endpoints['AI Foundry API']
