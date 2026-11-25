targetScope = 'subscription'
@minLength(1)
param environmentName string
param location string
param principalId string
param principalType string = 'User'
param useExistingFoundry bool = false
param existingFoundryResourceGroup string = ''
param existingFoundryAccountName string = ''
param existingFoundryEndpoint string = ''
param deploymentName string = 'gpt-5.4-mini'
param foundryLocation string = location
param runtimeStack string = 'dotnet|11'
param webSku string = 'B1'

resource group 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: { 'azd-env-name': environmentName }
}
module foundation '../chat-foundation.bicep' = {
  name: 'eshop-chat-foundation'
  scope: group
  params: {
    location: location
    foundryLocation: foundryLocation
    deploymentPrincipalId: principalId
    deploymentPrincipalType: principalType
    tags: { 'azd-env-name': environmentName }
    runtimeStack: runtimeStack
    webSku: webSku
    useExistingFoundry: useExistingFoundry
    existingFoundryResourceGroup: existingFoundryResourceGroup
    existingFoundryAccountName: existingFoundryAccountName
    existingFoundryEndpoint: existingFoundryEndpoint
    deploymentName: deploymentName
  }
}
output AZURE_RESOURCE_GROUP string = group.name
output AZURE_WEBAPP_NAME string = foundation.outputs.webAppName
output AZURE_CHAT_APP_NAME string = foundation.outputs.chatAppName
output AZD_CHAT_FOUNDATION object = foundation.outputs
output WEB_URI string = foundation.outputs.webAppUrl
