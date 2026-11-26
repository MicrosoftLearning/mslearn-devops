param webAppName string
param chatUrl string
param chatApiClientId string
param webIdentityClientId string
param enableObservability bool = false
param observabilityConnectionString string = ''
param observabilityEnvironmentName string = ''
param observabilitySourceVersion string = ''

resource web 'Microsoft.Web/sites@2022-09-01' existing = { name: webAppName }
resource settings 'Microsoft.Web/sites/config@2022-09-01' = {
  parent: web
  name: 'appsettings'
  properties: union({
    ASPNETCORE_ENVIRONMENT: 'Production'
    UseOnlyInMemoryDatabase: 'true'
    ShopChat__Enabled: 'true'
    ShopChat__BaseUrl: chatUrl
    ShopChat__AuthenticationScope: 'api://${chatApiClientId}/.default'
    ShopChat__ManagedIdentityClientId: webIdentityClientId
    SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
    WEBSITE_RUN_FROM_PACKAGE: '1'
  }, enableObservability ? {
    Observability__Enabled: 'true'
    Observability__ConnectionString: observabilityConnectionString
    Observability__ManagedIdentityClientId: webIdentityClientId
    Observability__EnvironmentName: observabilityEnvironmentName
    Observability__SourceVersion: observabilitySourceVersion
  } : {})
}
