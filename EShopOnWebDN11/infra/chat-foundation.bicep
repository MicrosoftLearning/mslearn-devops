param location string = resourceGroup().location
param foundryLocation string = location
@description('Object ID of the deployment user or service principal, not an application/client ID.')
param deploymentPrincipalId string
@allowed(['User', 'ServicePrincipal'])
param deploymentPrincipalType string = 'ServicePrincipal'
param tags object = {}
param runtimeStack string = 'dotnet|11'
param useExistingFoundry bool = false
param existingFoundryResourceGroup string = resourceGroup().name
param existingFoundryAccountName string = ''
param existingFoundryEndpoint string = ''
param deploymentName string = 'gpt-5.4-mini'
param modelName string = 'gpt-5.4-mini'
param modelVersion string = '2026-03-17'
@minValue(1)
param modelCapacity int = 30
param webSku string = 'B1'

var suffix = uniqueString(resourceGroup().id)
var foundryName = 'aoai-${suffix}'
resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-web-${suffix}'
  location: location
  tags: tags
}
resource chatIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-chat-${suffix}'
  location: location
  tags: tags
}
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr${suffix}'
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: false }
}
resource pushAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, deploymentPrincipalId, 'push')
  scope: registry
  properties: {
    principalId: deploymentPrincipalId
    principalType: deploymentPrincipalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
  }
}
resource pullAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, chatIdentity.id, 'pull')
  scope: registry
  properties: {
    principalId: chatIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  }
}
resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-eshop-${suffix}'
  location: location
  tags: tags
  properties: { sku: { name: 'PerGB2018' }, retentionInDays: 30 }
}
resource environment 'Microsoft.App/managedEnvironments@2025-07-01' = {
  name: 'cae-eshop-${suffix}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}
resource plan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'plan-eshop-${suffix}'
  location: location
  tags: tags
  kind: 'linux'
  sku: { name: webSku }
  properties: { reserved: true }
}
resource web 'Microsoft.Web/sites@2022-09-01' = {
  name: 'web-eshop-${suffix}'
  location: location
  tags: union(tags, { 'azd-service-name': 'web' })
  kind: 'app,linux'
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${webIdentity.id}': {} } }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: runtimeStack
      appCommandLine: 'dotnet Web.dll'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: true
      healthCheckPath: '/health/live'
      appSettings: [
        { name: 'ASPNETCORE_ENVIRONMENT', value: 'Production' }
        { name: 'UseOnlyInMemoryDatabase', value: 'true' }
        { name: 'ShopChat__Enabled', value: 'false' }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'false' }
        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1' }
      ]
    }
  }
}
module foundry 'chat-foundry.bicep' = if (!useExistingFoundry) {
  name: 'foundry'
  params: {
    accountName: foundryName
    location: foundryLocation
    deploymentName: deploymentName
    modelName: modelName
    modelVersion: modelVersion
    capacity: modelCapacity
  }
}
module inferenceAccess 'chat-foundry-access.bicep' = {
  name: 'foundry-inference-access'
  scope: resourceGroup(useExistingFoundry ? existingFoundryResourceGroup : resourceGroup().name)
  params: {
    accountName: useExistingFoundry ? existingFoundryAccountName : foundry!.outputs.name
    principalId: chatIdentity.properties.principalId
  }
}
output webAppName string = web.name
output webAppUrl string = 'https://${web.properties.defaultHostName}'
output webIdentityClientId string = webIdentity.properties.clientId
output chatIdentityClientId string = chatIdentity.properties.clientId
output chatIdentityId string = chatIdentity.id
output registryName string = registry.name
output registryLoginServer string = registry.properties.loginServer
output environmentId string = environment.id
output chatAppName string = 'chat-eshop-${suffix}'
output foundryEndpoint string = useExistingFoundry ? existingFoundryEndpoint : foundry!.outputs.endpoint
output foundryDeploymentName string = deploymentName
output tenantId string = tenant().tenantId
