// ---------------------------------------------------------------------------
// All Azure resources for Demo 07A — App Service + Cosmos DB
// ---------------------------------------------------------------------------
param location string
param resourceToken string
param tags object

// Object ID of the principal running `azd up` — granted Cosmos DB data access
// so the deployment user can query data during setup and validation.
param deploymentPrincipalId string = ''

// ===== Monitoring =====

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceToken}'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ===== Cosmos DB (Serverless) =====

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: 'cosmos-${resourceToken}'
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    capabilities: [{ name: 'EnableServerless' }]
    locations: [{ locationName: location, failoverPriority: 0 }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosAccount
  name: 'catalogdb'
  properties: {
    resource: { id: 'catalogdb' }
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDatabase
  name: 'products'
  properties: {
    resource: {
      id: 'products'
      partitionKey: { paths: ['/category'], kind: 'Hash' }
    }
  }
}

// ===== App Service =====

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'plan-${resourceToken}'
  location: location
  tags: tags
  kind: 'linux'
  sku: { name: 'B1' }
  properties: { reserved: true }
}

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: 'app-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  // System-assigned managed identity — used for keyless Cosmos DB authentication
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      alwaysOn: true
      appSettings: [
        { name: 'COSMOS_ACCOUNT_ENDPOINT',               value: cosmosAccount.properties.documentEndpoint }
        { name: 'COSMOS_DATABASE_NAME',                  value: 'catalogdb' }
        { name: 'COSMOS_CONTAINER_NAME',                 value: 'products' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING',  value: appInsights.properties.ConnectionString }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Cosmos DB RBAC — built-in "Cosmos DB Built-in Data Contributor" role
// Role definition ID is a fixed well-known GUID for all Cosmos SQL accounts.
// ---------------------------------------------------------------------------

// App Service managed identity → full data-plane access (read + write)
resource cosmosRoleAppService 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, appService.id, '00000000-0000-0000-0000-000000000002')
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    principalId: appService.identity.principalId
    scope: cosmosAccount.id
  }
}

// Deploying user → data-plane access so they can validate and seed data
resource cosmosRoleDeployer 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = if (!empty(deploymentPrincipalId)) {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, deploymentPrincipalId, '00000000-0000-0000-0000-000000000002')
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    principalId: deploymentPrincipalId
    scope: cosmosAccount.id
  }
}

// ===== Azure Monitor Alert: HTTP 5xx =====

resource httpErrorAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-http5xx-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    severity: 2
    enabled: true
    scopes: [appService.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xxErrors'
          metricName: 'Http5xx'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// ===== Azure Monitor Alert: Dependency Failures =====

resource dependencyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-depfail-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    severity: 2
    enabled: true
    scopes: [appInsights.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'DependencyFailures'
          metricName: 'dependencies/failed'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// ===== Azure Monitor Alert: App Service CPU Spike =====

resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-cpu-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    severity: 2
    enabled: true
    scopes: [appService.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCpuPercentage'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// ===== Azure Monitor Alert: App Service Latency =====

resource responseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-responsetime-${resourceToken}'
  location: 'global'
  tags: tags
  properties: {
    severity: 2
    enabled: true
    scopes: [appService.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighAverageResponseTime'
          metricName: 'AverageResponseTime'
          operator: 'GreaterThan'
          threshold: 3000
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// ===== Outputs =====

output apiUrl string = 'https://${appService.properties.defaultHostName}'
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output appServicePrincipalId string = appService.identity.principalId
output appServiceName string = appService.name
