#requires -Version 7.4
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$runtimes = (az webapp list-runtimes --os linux -o json | Out-String) | ConvertFrom-Json
foreach ($runtime in $runtimes) {
    $config = if ($runtime -is [string]) { $runtime } else { $runtime.config }
    if ($config -in 'dotnet:11', 'DOTNETCORE:11.0') {
        return $config.Replace(':', '|')
    }
}
throw 'The .NET 11 Linux App Service runtime is unavailable.'
