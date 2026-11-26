#requires -Version 7.4
param(
    [Parameter(Mandatory)][uri] $WebUrl,
    [Parameter(Mandatory)][uri] $ChatUrl
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$web = $WebUrl.AbsoluteUri.TrimEnd('/')
$chat = $ChatUrl.AbsoluteUri.TrimEnd('/')
$health = Invoke-WebRequest "$chat/health" -SkipHttpErrorCheck -TimeoutSec 30
if ($health.StatusCode -ne 200) { throw "ChatApi health failed: $($health.StatusCode)." }
$anonymous = Invoke-WebRequest "$chat/chat" -Method Post -ContentType application/json -Body '{}' -SkipHttpErrorCheck
if ($anonymous.StatusCode -ne 401) { throw "ChatApi must reject anonymous inference; received $($anonymous.StatusCode)." }
for ($attempt = 1; $attempt -le 12; $attempt++) {
    try {
        $liveness = Invoke-WebRequest "$web/health/live" -SkipHttpErrorCheck -TimeoutSec 30
    } catch [System.OperationCanceledException] {
        if ($attempt -eq 12) { throw }
        Write-Host "Web liveness timed out during startup ($attempt/12)."
        Start-Sleep -Seconds 10
        continue
    }
    if ($liveness.StatusCode -ne 200) {
        if ($liveness.StatusCode -notin 404, 502, 503) { throw "Web liveness failed: $($liveness.StatusCode)." }
        if ($attempt -eq 12) { throw 'Web did not become ready within the retry budget.' }
        Write-Host "Waiting for Web startup: HTTP $($liveness.StatusCode) ($attempt/12)."
        Start-Sleep -Seconds 10
        continue
    }
    $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    $page = Invoke-WebRequest "$web/Chat" -WebSession $session -SkipHttpErrorCheck -TimeoutSec 30
    if ($page.StatusCode -eq 200) {
        $token = [regex]::Match($page.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
        if (-not $token.Success) { throw 'Chat page is missing the antiforgery token.' }
        $response = Invoke-WebRequest "$web/api/chat" -Method Post -WebSession $session -ContentType application/json `
            -Headers @{ RequestVerificationToken = [Net.WebUtility]::HtmlDecode($token.Groups[1].Value) } `
            -Body '{"messages":[{"role":"user","content":"Recommend a catalog mug costing less than 10 and give its price."}]}' `
            -TimeoutSec 100 -SkipHttpErrorCheck
        if ($response.StatusCode -eq 200) {
            $content = $response.Content
            if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
            $events = @($content -split '\r?\n' | Where-Object { $_.StartsWith('data: ') } |
                ForEach-Object { $_.Substring(6) | ConvertFrom-Json -AsHashtable })
            $completed = @($events | Where-Object { $_.type -eq 'completed' })
            if (@($events | Where-Object { $_.type -eq 'error' }).Count -gt 0 -or
                $completed.Count -ne 1 -or $completed[0].products.Count -eq 0) {
                throw 'The live model response did not complete with authoritative catalog references.'
            }
            foreach ($product in $completed[0].products) {
                if ($product.price -ge 10 -or $product.id -notin 1..12) {
                    throw 'The live answer did not satisfy the requested catalog/price constraint.'
                }
            }
            Write-Host 'Verified: anonymous API blocked; storefront-to-ChatApi identity and live Foundry catalog response succeeded.'
            return
        }
        if ($response.StatusCode -notin 502, 503) { throw "Chat inference failed: $($response.StatusCode) $($response.Content)" }
        Write-Host "Inference unavailable while identities/model warm up: HTTP $($response.StatusCode)."
    } elseif ($page.StatusCode -notin 502, 503) {
        throw "Chat page failed: $($page.StatusCode)."
    }
    if ($attempt -eq 12) { throw 'The deployed chat workload did not become usable within the retry budget.' }
    Write-Host "Retrying deployment smoke test ($attempt/12)."
    Start-Sleep -Seconds 10
}
