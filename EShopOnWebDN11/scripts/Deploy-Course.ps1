#requires -Version 7.4
param(
    [Parameter(Mandatory)][ValidateSet('Foundation', 'PublishImage', 'DeployChat', 'ConfigureWeb', 'DeployWeb', 'Verify')][string] $Phase,
    [Parameter(Mandatory)][string] $ArtifactRoot,
    [Parameter(Mandatory)][string] $MetadataRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Get-RequiredEnvironment([string] $Name) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Configure $Name." }
    return $value
}
function Write-Parameters([string] $Name, [hashtable] $Values) {
    $parameters = @{}
    foreach ($key in $Values.Keys) { $parameters[$key] = @{ value = $Values[$key] } }
    $path = Join-Path $MetadataRoot "$Name.parameters.json"
    @{ parameters = $parameters } | ConvertTo-Json -Depth 12 | Set-Content $path -Encoding utf8NoBOM
    return "@$path"
}
function Deploy-Template([string] $Name, [hashtable] $Values) {
    $parameters = Write-Parameters $Name $Values
    $json = az deployment group create --name "eshop-$Name" --resource-group $resourceGroup `
        --template-file (Join-Path $ArtifactRoot "Bicep/chat-$Name.bicep") `
        --parameters $parameters --query properties.outputs -o json
    $json | Set-Content (Join-Path $MetadataRoot "$Name.json") -Encoding utf8NoBOM
    return ($json | Out-String | ConvertFrom-Json -AsHashtable)
}
function Invoke-RegistryCommand([string] $Command, [string[]] $Arguments) {
    $log = Join-Path $MetadataRoot 'registry-command.log'
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            $PSNativeCommandUseErrorActionPreference = $false
            & $Command @Arguments *> $log
            $code = $LASTEXITCODE
        } finally { $PSNativeCommandUseErrorActionPreference = $true }
        $text = Get-Content $log -Raw
        Write-Host $text
        if ($code -eq 0) { Remove-Item $log; return }
        if ($text -notmatch '(?i)unauthorized|denied|authorizationfailed|\b401\b|\b403\b' -or $attempt -eq 12) {
            throw "$Command failed ($code). Review the registry permissions/error above."
        }
        function Get-ObservabilityParameters {
            if (-not $foundation.ContainsKey('observabilityEnabled')) { return @{} }
            $values = @{ enableObservability = $foundation.observabilityEnabled.value }
            foreach ($key in 'observabilityConnectionString', 'observabilityEnvironmentName', 'observabilitySourceVersion') {
                if (-not $foundation.ContainsKey($key)) { throw "Missing foundation output $key; reprovision using the matching artifact." }
                $values[$key] = $foundation[$key].value
            }
            return $values
        }
        Write-Host "Waiting for new ACR RBAC grants to propagate (attempt $attempt/12)."
        Start-Sleep -Seconds 10
    }
}
$resourceGroup = Get-RequiredEnvironment 'AZURE_RESOURCE_GROUP'
$location = Get-RequiredEnvironment 'AZURE_LOCATION'
$apiClientId = Get-RequiredEnvironment 'CHAT_API_CLIENT_ID'
$parsedApiClient = [guid]::Empty
if (-not [guid]::TryParse($apiClientId, [ref] $parsedApiClient)) {
    throw 'CHAT_API_CLIENT_ID must be the API registration application/client GUID.'
}
$apiClientId = $parsedApiClient.ToString()
New-Item $MetadataRoot -ItemType Directory -Force | Out-Null
$manifest = Get-Content (Join-Path $ArtifactRoot 'manifest.json') -Raw | ConvertFrom-Json -AsHashtable
if (-not $manifest.hasChatImage) { throw 'Use the full-workload CI artifact, including its tested container image.' }
if ($Phase -eq 'Foundation') {
    $runtime = & (Join-Path $PSScriptRoot 'Get-AppServiceRuntime.ps1')
    $principal = Get-RequiredEnvironment 'DEPLOYMENT_PRINCIPAL_ID'
    $parsed = [guid]::Empty
    if (-not [guid]::TryParse($principal, [ref] $parsed)) { throw 'DEPLOYMENT_PRINCIPAL_ID must be the deployment service principal object GUID.' }
    if ($env:USE_EXISTING_FOUNDRY -and $env:USE_EXISTING_FOUNDRY -notin 'true', 'false') {
        throw 'USE_EXISTING_FOUNDRY must be true or false.'
    }
    $reuse = $env:USE_EXISTING_FOUNDRY -eq 'true'
    $parameters = @{
        location = $location
        foundryLocation = $location
        deploymentPrincipalId = $principal
        useExistingFoundry = $reuse
        runtimeStack = $runtime
    }
    if ($env:ENABLE_OBSERVABILITY -and $env:ENABLE_OBSERVABILITY -notin 'true', 'false') {
        throw 'ENABLE_OBSERVABILITY must be true or false.'
    }
    if ($env:ENABLE_OBSERVABILITY -eq 'true') {
        $parameters.enableObservability = $true
        $parameters.environmentName = $resourceGroup
        $parameters.sourceVersion = $manifest.sourceVersion
    }
    if (-not [string]::IsNullOrWhiteSpace($env:FOUNDRY_LOCATION)) { $parameters.foundryLocation = $env:FOUNDRY_LOCATION }
    if (-not [string]::IsNullOrWhiteSpace($env:FOUNDRY_DEPLOYMENT_NAME)) { $parameters.deploymentName = $env:FOUNDRY_DEPLOYMENT_NAME }
    if ($reuse) {
        $parameters.existingFoundryResourceGroup = Get-RequiredEnvironment 'EXISTING_FOUNDRY_RESOURCE_GROUP'
        $parameters.existingFoundryAccountName = Get-RequiredEnvironment 'EXISTING_FOUNDRY_ACCOUNT_NAME'
        $parameters.existingFoundryEndpoint = Get-RequiredEnvironment 'EXISTING_FOUNDRY_ENDPOINT'
        $parameters.deploymentName = Get-RequiredEnvironment 'FOUNDRY_DEPLOYMENT_NAME'
        $uri = $null
        if (-not [uri]::TryCreate($parameters.existingFoundryEndpoint, [UriKind]::Absolute, [ref] $uri) -or
            $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
            ($uri.AbsolutePath -ne '/' -and $uri.AbsolutePath.TrimEnd('/') -ne '/openai/v1' -and
                -not $uri.AbsolutePath.StartsWith('/api/projects/'))) {
            throw 'EXISTING_FOUNDRY_ENDPOINT must be an HTTPS resource or project endpoint without credentials.'
        }
        $state = az cognitiveservices account deployment show -g $parameters.existingFoundryResourceGroup `
            -n $parameters.existingFoundryAccountName --deployment-name $parameters.deploymentName `
            --query properties.provisioningState -o tsv
        if ($state -ne 'Succeeded') { throw 'The existing model deployment is not ready.' }
    }
    az group create --name $resourceGroup --location $location -o none
    Deploy-Template 'foundation' $parameters | Out-Null
    return
}
$foundation = Get-Content (Join-Path $MetadataRoot 'foundation.json') -Raw | ConvertFrom-Json -AsHashtable
if ($Phase -eq 'PublishImage') {
    docker load --input (Join-Path $ArtifactRoot 'ChatApi.tar')
    $actualId = (docker image inspect $manifest.imageTag --format '{{.Id}}').Trim()
    if ($actualId -ne $manifest.imageId) { throw 'Loaded image does not match the tested CI image.' }
    $registry = $foundation.registryLoginServer.value
    $target = "$registry/$($manifest.imageTag)"
    Invoke-RegistryCommand 'az' @('acr', 'login', '--name', $foundation.registryName.value)
    docker tag $manifest.imageTag $target
    Invoke-RegistryCommand 'docker' @('push', $target)
    $digests = (docker image inspect $target --format '{{json .RepoDigests}}' | Out-String) | ConvertFrom-Json
    $matching = @($digests | Where-Object {
        $_ -match "^$([regex]::Escape($registry))/eshoponweb/chat@sha256:[0-9a-f]{64}$"
    })
    if ($matching.Count -ne 1) {
        throw 'The registry did not return the expected immutable image digest.'
    }
    $image = $matching[0]
    @{ image = $image } | ConvertTo-Json | Set-Content (Join-Path $MetadataRoot 'image.json') -Encoding utf8NoBOM
} elseif ($Phase -eq 'DeployChat') {
    $image = Get-Content (Join-Path $MetadataRoot 'image.json') -Raw | ConvertFrom-Json
    $parameters = @{ location = $location; chatApiClientId = $apiClientId; image = $image.image }
    foreach ($key in 'chatAppName', 'environmentId', 'chatIdentityId', 'chatIdentityClientId',
        'registryLoginServer', 'foundryEndpoint', 'foundryDeploymentName', 'tenantId', 'webIdentityClientId') {
        $parameters[$key] = $foundation[$key].value
    }
    $parameters += Get-ObservabilityParameters
    Deploy-Template 'container' $parameters | Out-Null
} elseif ($Phase -in 'ConfigureWeb', 'DeployWeb') {
    $zip = Join-Path $ArtifactRoot 'Website/Web.zip'
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.webZipSha256) {
        throw 'The website ZIP does not match the tested CI artifact.'
    }
    $chat = Get-Content (Join-Path $MetadataRoot 'container.json') -Raw | ConvertFrom-Json -AsHashtable
    $parameters = @{
        webAppName = $foundation.webAppName.value
        chatUrl = $chat.chatUrl.value
        chatApiClientId = $apiClientId
        webIdentityClientId = $foundation.webIdentityClientId.value
    }
    $parameters += Get-ObservabilityParameters
    Deploy-Template 'web-config' $parameters | Out-Null
    if ($Phase -eq 'DeployWeb') {
        az webapp deploy --resource-group $resourceGroup --name $foundation.webAppName.value `
            --src-path $zip --type zip --clean true --restart true
    }
} elseif ($Phase -eq 'Verify') {
    $chat = Get-Content (Join-Path $MetadataRoot 'container.json') -Raw | ConvertFrom-Json -AsHashtable
    & (Join-Path $ArtifactRoot 'Scripts/Test-CourseDeployment.ps1') `
        -WebUrl $foundation.webAppUrl.value -ChatUrl $chat.chatUrl.value
}
