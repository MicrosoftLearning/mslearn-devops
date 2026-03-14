targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment (used for resource group and resource naming)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Object ID of the Azure AD principal running azd up - granted Cosmos DB data access')
param deploymentPrincipalId string = ''

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var tags = { 'azd-env-name': environmentName, SecurityControl: 'Ignore' }
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// All resources (deployed at resource-group scope)
// ---------------------------------------------------------------------------
module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    deploymentPrincipalId: deploymentPrincipalId
  }
}

// ---------------------------------------------------------------------------
// Outputs (consumed by azd and shown after `azd up`)
// ---------------------------------------------------------------------------
output AZURE_RESOURCE_GROUP string = rg.name
output API_URL string = resources.outputs.apiUrl
output AZURE_COSMOS_ENDPOINT string = resources.outputs.cosmosEndpoint
output APP_SERVICE_PRINCIPAL_ID string = resources.outputs.appServicePrincipalId
output APP_SERVICE_NAME string = resources.outputs.appServiceName
