# ==============================================================================
# VAI-FRAMEWORK v5 — Entry point
# Author: Vadim Khristenko <vadim@vai-rice.space>
# Version: 5.1.0
# ==============================================================================

function global:Import-Vai {
    <#
    .SYNOPSIS
        Portable bootstrap: load core + optional module subset.
    .EXAMPLE
        Import-Vai -Root D:\PowerShell -Modules Git,sex
    #>
    [CmdletBinding()]
    param(
        [string]$Root,

        [string[]]$Modules,

        [switch]$Quiet
    )

    if ($Root) {
        $script:VaiImportRoot = $Root
    }
    else {
        $script:VaiImportRoot = $null
    }

    $script:VaiImportOnly = $Modules
    $script:VaiImportQuiet = [bool]$Quiet

    $init = if ($Root) {
        Join-Path $Root "init.ps1"
    }
    else {
        $MyInvocation.MyCommand.Path
    }

    # Prefer caller's root init
    if ($Root) {
        $path = Join-Path $Root "init.ps1"
        if (Test-Path $path) {
            $global:_VaiInitGuard = $false
            . $path
            return
        }
    }

    Write-Error "Import-Vai: init.ps1 not found for Root=$Root"
}

# Guard against re-entry within one reload
if ($global:_VaiInitGuard) { return }
$global:_VaiInitGuard = $true

try {
    if ($script:VaiImportRoot) {
        $global:VaiFrameworkRoot = $script:VaiImportRoot
    }
    else {
        $global:VaiFrameworkRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    }

    $global:_VaiBootTimer = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $currentEncoding = [System.Console]::OutputEncoding
        if ($currentEncoding.CodePage -ne 65001) {
            [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        }
    }
    catch { }

    $coreDir = Join-Path $global:VaiFrameworkRoot "core"
    $coreFiles = @(
        "VaiState.ps1"
        "VaiHelpers.ps1"
        "VaiPlatform.ps1"
        "VaiTui.ps1"
        "VaiLogger.ps1"
        "VaiRegistry.ps1"
        "VaiUpdate.ps1"
        "VaiModuleLoader.ps1"
        "VaiCli.ps1"
    )

    foreach ($file in $coreFiles) {
        $path = Join-Path $coreDir $file
        if (-not (Test-Path $path)) {
            Write-Host "  [FATAL] Missing core component: $file" -ForegroundColor Red
            return
        }
        . $path
    }

    # Ensure Root on $Vai matches
    $global:Vai.Root = $global:VaiFrameworkRoot
    $global:Vai.LogPath = $global:VaiLogPath
    $global:Vai.Version = $global:VaiCoreVersion

    $only = $null
    if ($script:VaiImportOnly) { $only = $script:VaiImportOnly }

    if ($only) {
        Initialize-VaiModules -OnlyModules $only
    }
    else {
        Initialize-VaiModules
    }

    $global:_VaiBootTimer.Stop()
    if (-not $script:VaiImportQuiet) {
        Show-VaiBootSummary -ElapsedMs $global:_VaiBootTimer.Elapsed.TotalMilliseconds
    }
}
finally {
    $global:_VaiInitGuard = $false
    $script:VaiImportRoot = $null
    $script:VaiImportOnly = $null
    $script:VaiImportQuiet = $false
}
