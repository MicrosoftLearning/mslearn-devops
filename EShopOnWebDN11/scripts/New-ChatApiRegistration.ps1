#requires -Version 7.4
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]{1,80}$')][string] $DisplayName,
    [Parameter(Mandatory)][guid] $TenantId
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$activeTenant = (az account show --query tenantId -o tsv).Trim()
if ($activeTenant -ne $TenantId.ToString()) { throw 'Sign in to the subscription tenant before creating the API registration.' }
$app = (az ad app create --display-name $DisplayName --sign-in-audience AzureADMyOrg -o json |
    Out-String) | ConvertFrom-Json
Write-Host "Created registration $($app.appId). If a later step fails, finish configuring this registration rather than creating another."
$body = New-TemporaryFile
try {
    @{ identifierUris = @("api://$($app.appId)"); api = @{ requestedAccessTokenVersion = 2 } } |
        ConvertTo-Json -Depth 4 | Set-Content $body.FullName -Encoding utf8NoBOM
    az rest --method PATCH --url "https://graph.microsoft.com/v1.0/applications/$($app.id)" --body "@$($body.FullName)" -o none
    $principalId = (az ad sp create --id $app.appId --query id -o tsv).Trim()
    @{ appRoleAssignmentRequired = $false } | ConvertTo-Json | Set-Content $body.FullName -Encoding utf8NoBOM
    az rest --method PATCH --url "https://graph.microsoft.com/v1.0/servicePrincipals/$principalId" --body "@$($body.FullName)" -o none
} finally {
    Remove-Item $body.FullName -Force
}
Write-Host "CHAT_API_CLIENT_ID=$($app.appId)"
Write-Host "Tenant=$activeTenant; audience=$($app.appId); scope=api://$($app.appId)/.default"
return $app.appId
