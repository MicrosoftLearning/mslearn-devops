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
param enableObservability bool = false
param sourceVersion string = ''

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
    enableObservability: enableObservability
    environmentName: environmentName
    sourceVersion: sourceVersion
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
output AZURE_APPLICATION_INSIGHTS_NAME string = foundation.outputs.applicationInsightsName
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = foundation.outputs.workspaceName
output AZURE_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID string = foundation.outputs.workspaceResourceId
