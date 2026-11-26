param location string = resourceGroup().location
param chatAppName string
param environmentId string
param chatIdentityId string
param chatIdentityClientId string
param registryLoginServer string
@description('Immutable registry image reference ending in @sha256:<digest>.')
param image string
param foundryEndpoint string
param foundryDeploymentName string
param tenantId string
param chatApiClientId string
param webIdentityClientId string

resource chat 'Microsoft.App/containerApps@2025-07-01' = {
  name: chatAppName
  location: location
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${chatIdentityId}': {} } }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: { external: true, allowInsecure: false, targetPort: 8080, transport: 'auto' }
      registries: [{ server: registryLoginServer, identity: chatIdentityId }]
    }
    template: {
      containers: [{
        name: 'chat'
        image: image
        resources: { cpu: json('0.5'), memory: '1Gi' }
        env: [
          { name: 'ASPNETCORE_ENVIRONMENT', value: 'Production' }
          { name: 'ASPNETCORE_HTTP_PORTS', value: '8080' }
          { name: 'AllowedHosts', value: '*' }
          { name: 'Foundry__Endpoint', value: foundryEndpoint }
          { name: 'Foundry__DeploymentName', value: foundryDeploymentName }
          { name: 'Foundry__Credential', value: 'ManagedIdentity' }
          { name: 'Foundry__ManagedIdentityClientId', value: chatIdentityClientId }
          { name: 'Authentication__Enabled', value: 'true' }
          { name: 'Authentication__TenantId', value: tenantId }
          { name: 'Authentication__ClientId', value: chatApiClientId }
          { name: 'Authentication__AllowedClientId', value: webIdentityClientId }
        ]
        probes: [
          { type: 'Startup', httpGet: { path: '/health', port: 8080 }, periodSeconds: 10, failureThreshold: 30 }
          { type: 'Readiness', httpGet: { path: '/health', port: 8080 }, periodSeconds: 10 }
          { type: 'Liveness', httpGet: { path: '/health', port: 8080 }, periodSeconds: 30 }
        ]
      }]
      scale: { minReplicas: 1, maxReplicas: 2 }
    }
  }
}
output chatUrl string = 'https://${chat.properties.configuration.ingress!.fqdn}/'
