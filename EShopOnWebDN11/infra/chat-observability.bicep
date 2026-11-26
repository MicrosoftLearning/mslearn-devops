param location string = resourceGroup().location
param workspaceResourceId string
param webPrincipalId string
param chatPrincipalId string
param tags object = {}

resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-eshop-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    DisableLocalAuth: true
  }
}

var publisherRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')
resource ingestionAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in [webPrincipalId, chatPrincipalId]: {
  name: guid(insights.id, principalId, publisherRole)
  scope: insights
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: publisherRole
  }
}]

output connectionString string = insights.properties.ConnectionString
output name string = insights.name
