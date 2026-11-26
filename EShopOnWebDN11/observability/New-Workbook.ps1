#requires -Version 7.4
param(
    [Parameter(Mandatory)][ValidatePattern('^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.OperationalInsights/workspaces/[^/]+$')][string] $WorkspaceResourceId,
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9-]{0,63}$')][string] $EnvironmentName,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $SourceVersion,
    [string] $OutputPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts/observability-workbook.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Test-Path $OutputPath) { throw "Workbook already exists: $OutputPath. Choose a new OutputPath." }
$items = @(
    @{
        type = 1
        content = @{ json = "# eShop Web and Chat`nSmall lab sample only. Unknown means missing, stale, sampled or invalid evidence. HTTP success does not prove an answer completed." }
        name = 'context'
    }
)
foreach ($query in @(
    @{ file = 'evidence-health.kql'; title = 'Evidence completeness and chat outcomes' },
    @{ file = 'requests.kql'; title = 'HTTP requests and latency (not answer success)' },
    @{ file = 'chat-outcomes.kql'; title = 'Chat operations and trace IDs' }
)) {
    $text = (Get-Content (Join-Path $PSScriptRoot $query.file) -Raw).
        Replace('YOUR-ENVIRONMENT', $EnvironmentName).Replace('YOUR-SOURCE-VERSION', $SourceVersion)
    $items += @{
        type = 3
        name = $query.file
        content = @{
            version = 'KqlItem/1.0'
            title = $query.title
            query = $text
            queryType = 0
            resourceType = 'microsoft.operationalinsights/workspaces'
            crossComponentResources = @($WorkspaceResourceId)
            visualization = 'table'
            size = 0
            timeContext = @{ durationMs = 1800000 }
        }
    }
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
New-Item (Split-Path $OutputPath -Parent) -ItemType Directory -Force | Out-Null
@{
    version = 'Notebook/1.0'
    items = $items
    isLocked = $false
    fallbackResourceIds = @($WorkspaceResourceId)
} | ConvertTo-Json -Depth 20 | Set-Content $OutputPath -Encoding utf8NoBOM
Write-Host "Workbook JSON created: $OutputPath"
