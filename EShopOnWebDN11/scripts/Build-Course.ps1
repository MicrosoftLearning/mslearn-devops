#requires -Version 7.4
param(
    [Parameter(Mandatory)][string] $ArtifactRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $SourceVersion,
    [switch] $BuildChatImage
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$sampleRoot = Split-Path $PSScriptRoot -Parent
$ArtifactRoot = [IO.Path]::GetFullPath($ArtifactRoot)
if (Test-Path $ArtifactRoot) { throw "Artifact directory already exists: $ArtifactRoot. Use a fresh directory." }
New-Item $ArtifactRoot -ItemType Directory | Out-Null
Push-Location $sampleRoot
try {
    $env:Configuration = 'Release'
    dotnet restore eShopOnWeb.sln -p:Configuration=Release -p:NuGetAudit=true -p:NuGetAuditMode=all -warnaserror
    dotnet build eShopOnWeb.sln -c Release --no-restore -warnaserror
    dotnet test eShopOnWeb.sln -c Release --no-build
    node --test (Join-Path $sampleRoot 'tests/JavaScript/catalog-chat.test.cjs')
    foreach ($project in Get-ChildItem src, tests -Recurse -Filter *.csproj |
        Where-Object FullName -NotMatch '[/\\](bin|obj)[/\\]') {
        $report = (dotnet package list --project $project.FullName --include-transitive --vulnerable --no-restore --format json |
            Out-String) | ConvertFrom-Json -AsHashtable
        if (($report.ContainsKey('problems') -and $report.problems.Count -gt 0) -or
            $report.projects.Count -ne 1) {
            throw "Dependency audit did not complete for $($project.Name)."
        }
        foreach ($framework in $report.projects[0]['frameworks']) {
            foreach ($kind in 'topLevelPackages', 'transitivePackages') {
                foreach ($package in $framework[$kind]) {
                    if ($package.ContainsKey('vulnerabilities') -and $package.vulnerabilities.Count -gt 0) {
                        throw "Known vulnerability: $($project.Name): $($package.id) $($package.resolvedVersion)."
                    }
                }
            }
        }
    }
    foreach ($template in Get-ChildItem infra -Recurse -Filter *.bicep) {
        $compiled = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName() + '.json')
        try { az bicep build --file $template.FullName --outfile $compiled }
        finally { if (Test-Path $compiled) { Remove-Item $compiled } }
    }
    $webPublish = Join-Path $ArtifactRoot 'WebPublish'
    $website = Join-Path $ArtifactRoot 'Website'
    $chatPublish = Join-Path $ArtifactRoot 'ChatApi'
    dotnet publish src/Web/Web.csproj -c Release --no-build --no-restore -p:UseAppHost=false -o $webPublish
    dotnet publish src/ChatApi/ChatApi.csproj -c Release --no-build --no-restore -p:UseAppHost=false -o $chatPublish
    New-Item $website -ItemType Directory | Out-Null
    $webZip = Join-Path $website 'Web.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($webPublish, $webZip)
    Copy-Item infra (Join-Path $ArtifactRoot 'Bicep') -Recurse
    Copy-Item scripts (Join-Path $ArtifactRoot 'Scripts') -Recurse
    $manifest = @{
        sourceVersion = $SourceVersion
        webZipSha256 = (Get-FileHash $webZip -Algorithm SHA256).Hash.ToLowerInvariant()
        imageTag = "eshoponweb/chat:$SourceVersion"
        hasChatImage = [bool] $BuildChatImage
    }
    if ($BuildChatImage) {
        docker build --pull --platform linux/amd64 --label "org.opencontainers.image.revision=$SourceVersion" `
            -f src/ChatApi/Dockerfile -t $manifest.imageTag $chatPublish
        $manifest.imageId = (docker image inspect $manifest.imageTag --format '{{.Id}}').Trim()
        $container = docker run --detach --platform linux/amd64 --publish 127.0.0.1::8080 `
            --env ASPNETCORE_ENVIRONMENT=Production --env AllowedHosts=* `
            --env Authentication__Enabled=true `
            --env Authentication__TenantId=11111111-1111-1111-1111-111111111111 `
            --env Authentication__ClientId=22222222-2222-2222-2222-222222222222 `
            --env Authentication__AllowedClientId=33333333-3333-3333-3333-333333333333 `
            --env Foundry__Endpoint=https://test.openai.azure.com/openai/v1 `
            --env Foundry__DeploymentName=test --env Foundry__Credential=ManagedIdentity $manifest.imageTag
        try {
            $port = (docker port $container 8080/tcp).Trim()
            $ready = $false
            for ($attempt = 1; $attempt -le 40; $attempt++) {
                if ((docker inspect $container --format '{{.State.Running}}') -ne 'true') {
                    docker logs $container
                    throw 'ChatApi container exited during startup.'
                }
                try {
                    $health = Invoke-WebRequest "http://$port/health" -TimeoutSec 2 -SkipHttpErrorCheck -NoProxy
                    if ($health.StatusCode -ne 200) { throw "Container health failed: $($health.StatusCode)." }
                    $ready = $true
                    break
                } catch [Net.Http.HttpRequestException] { Start-Sleep -Seconds 1 }
            }
            if (-not $ready) { throw 'ChatApi container did not become ready.' }
            $anonymous = Invoke-WebRequest "http://$port/chat" -Method Post -Body '{}' `
                -ContentType application/json -SkipHttpErrorCheck -NoProxy
            if ($anonymous.StatusCode -ne 401 -or (docker exec $container id -u) -eq '0') {
                throw 'Hosted ChatApi must run non-root and reject anonymous inference.'
            }
            Write-Host 'Verified non-root Linux container health and anonymous inference rejection.'
        } finally { docker rm -f $container | Out-Null }
        docker save --output (Join-Path $ArtifactRoot 'ChatApi.tar') $manifest.imageTag
    }
    $manifest | ConvertTo-Json | Set-Content (Join-Path $ArtifactRoot 'manifest.json') -Encoding utf8NoBOM
} finally { Pop-Location }
