param location string = resourceGroup().location
param workspaceResourceId string
@minLength(1)
param environmentName string
@description('Existing action group ID. Leave empty for an alert visible in Azure Monitor without notifications.')
param actionGroupId string = ''

resource alert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: 'eshop-chat-failures'
  location: location
  kind: 'LogAlert'
  properties: {
    displayName: 'eShop Chat: repeated failed answers'
    description: 'Three failed ChatApi answers in five minutes. Inspect the correlated Foundry dependency and deployment configuration; do not restart automatically.'
    enabled: true
    severity: 3
    scopes: [workspaceResourceId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    autoMitigate: true
    criteria: {
      allOf: [{
        query: format('''
          AppDependencies
          | where AppRoleName == "eshop-chat" and Name == "eshop.chat"
          | where tostring(Properties["deployment.environment"]) == base64_decode_tostring("{0}")
          | where tostring(Properties["chat.outcome"]) == "failed"
          | summarize FailedChatOperations = count()
          ''', base64(environmentName))
        timeAggregation: 'Maximum'
        metricMeasureColumn: 'FailedChatOperations'
        operator: 'GreaterThanOrEqual'
        threshold: 3
        failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
      }]
    }
    actions: {
      actionGroups: empty(actionGroupId) ? [] : [actionGroupId]
    }
  }
}
