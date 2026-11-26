#requires -Version 7.4
param([Parameter(Mandatory)][ValidateSet('Initialize', 'Configure', 'Verify')][string] $Phase)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$root = Split-Path $PSScriptRoot -Parent
$settings = (azd env get-values -o json | Out-String) | ConvertFrom-Json -AsHashtable
foreach ($key in 'AZURE_ENV_NAME', 'AZURE_SUBSCRIPTION_ID', 'AZURE_LOCATION') {
    if (-not $settings.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($settings[$key])) { throw "Configure $key using azd env set." }
}
az account set --subscription $settings.AZURE_SUBSCRIPTION_ID
if ($Phase -eq 'Initialize') {
    $sourceVersion = (git -C $root rev-parse HEAD).Trim()
    if ($settings.ContainsKey('ENABLE_OBSERVABILITY') -and $settings.ENABLE_OBSERVABILITY -notin 'true', 'false') {
        throw 'ENABLE_OBSERVABILITY must be true or false.'
    }
    if ($settings.ContainsKey('ENABLE_OBSERVABILITY') -and $settings.ENABLE_OBSERVABILITY -eq 'true') {
        $changes = git -C $root status --porcelain -- src infra scripts Directory.Packages.props Directory.Build.props global.json azure.yaml
        if ($changes) { throw 'Commit application and deployment changes before the observability build so source.commit identifies the deployed source.' }
    }
    azd env set SOURCE_VERSION $sourceVersion
    $runtime = & (Join-Path $PSScriptRoot 'Get-AppServiceRuntime.ps1')
    azd env set AZURE_DOTNET_RUNTIME_STACK $runtime
    $account = (az account show -o json | Out-String) | ConvertFrom-Json
    if (-not $settings.ContainsKey('CHAT_API_CLIENT_ID') -or -not $settings.CHAT_API_CLIENT_ID) {
        $clientId = & (Join-Path $PSScriptRoot 'New-ChatApiRegistration.ps1') `
            -DisplayName "eshop-chat-$($settings.AZURE_ENV_NAME)" -TenantId $account.tenantId
        azd env set CHAT_API_CLIENT_ID $clientId
    }
    if (-not $settings.ContainsKey('FOUNDRY_LOCATION') -or -not $settings.FOUNDRY_LOCATION) {
        azd env set FOUNDRY_LOCATION $settings.AZURE_LOCATION
    }
    $artifacts = Join-Path $root "artifacts/azd/$($settings.AZURE_ENV_NAME)/$([guid]::NewGuid().ToString('N'))"
    & (Join-Path $PSScriptRoot 'Build-Course.ps1') -ArtifactRoot $artifacts `
        -SourceVersion $sourceVersion -BuildChatImage
    azd env set AZD_CHAT_ARTIFACT_ROOT $artifacts
    azd env set AZD_CHAT_METADATA_ROOT (Join-Path $artifacts 'Metadata')
    return
}
foreach ($key in 'AZURE_RESOURCE_GROUP', 'CHAT_API_CLIENT_ID', 'AZD_CHAT_ARTIFACT_ROOT', 'AZD_CHAT_METADATA_ROOT', 'AZD_CHAT_FOUNDATION') {
    if (-not $settings.ContainsKey($key) -or -not $settings[$key]) { throw "Missing azd output $key; run azd provision." }
}
$metadata = $settings.AZD_CHAT_METADATA_ROOT
New-Item $metadata -ItemType Directory -Force | Out-Null
$foundation = $settings.AZD_CHAT_FOUNDATION | ConvertFrom-Json -AsHashtable
if (-not $foundation.ContainsKey('webAppName') -or -not $foundation.webAppName.ContainsKey('value')) {
    throw 'The foundation output does not match the ARM deployment output contract.'
}
$foundation | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $metadata 'foundation.json') -Encoding utf8NoBOM
$env:AZURE_RESOURCE_GROUP = $settings.AZURE_RESOURCE_GROUP
$env:AZURE_LOCATION = $settings.AZURE_LOCATION
$env:CHAT_API_CLIENT_ID = $settings.CHAT_API_CLIENT_ID
$deploy = Join-Path $settings.AZD_CHAT_ARTIFACT_ROOT 'Scripts/Deploy-Course.ps1'
if ($Phase -eq 'Configure') {
    foreach ($step in 'PublishImage', 'DeployChat', 'ConfigureWeb') {
        & $deploy -Phase $step -ArtifactRoot $settings.AZD_CHAT_ARTIFACT_ROOT -MetadataRoot $metadata
    }
    $container = Get-Content (Join-Path $metadata 'container.json') -Raw | ConvertFrom-Json
    azd env set CHAT_URI $container.chatUrl.value
} else {
    & $deploy -Phase Verify -ArtifactRoot $settings.AZD_CHAT_ARTIFACT_ROOT -MetadataRoot $metadata
}
