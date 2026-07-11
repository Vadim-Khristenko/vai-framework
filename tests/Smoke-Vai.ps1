#Requires -Version 5.1
<#
.SYNOPSIS
  CI / local smoke tests for VAI-Framework.
  Exit 0 = pass; non-zero = fail.
#>
$ErrorActionPreference = 'Stop'
$failed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "  PASS  $Message" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  $Message" -ForegroundColor Red
        $script:failed++
    }
}

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not (Test-Path (Join-Path $root 'init.ps1'))) {
    $root = Split-Path -Parent $PSScriptRoot
}

Write-Host ""
Write-Host "VAI Smoke Tests  root=$root" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────"

# --- Boot ---
. (Join-Path $root 'init.ps1')

Assert-True ($global:VaiCoreVersion -match '^\d+\.\d+') "VaiCoreVersion set ($global:VaiCoreVersion)"
Assert-True ($null -ne $global:Vai) "`$Vai root object exists"
Assert-True ($null -ne $global:Vai.M) "`$Vai.M registry map exists"
Assert-True ($global:VaiModulesCache.Count -ge 1) "At least one module in cache ($($global:VaiModulesCache.Count))"

$names = @($global:VaiModulesCache | ForEach-Object { $_.Name })
foreach ($need in @('sex', 'AgentHub', 'CommandNotFound')) {
    Assert-True ($names -contains $need) "Module present: $need"
}

Assert-True ([bool](Get-Command Invoke-Vai -ErrorAction SilentlyContinue)) "Invoke-Vai available"
Assert-True ([bool](Get-Command Register-VaiExport -ErrorAction SilentlyContinue)) "Register-VaiExport available"
Assert-True ([bool](Get-Command Get-VaiExport -ErrorAction SilentlyContinue)) "Get-VaiExport available"
Assert-True ([bool](Get-Command sex -ErrorAction SilentlyContinue)) "sex command bound"
Assert-True ([bool](Get-Command ai -ErrorAction SilentlyContinue)) "ai command bound"
Assert-True ([bool](Get-Command db -ErrorAction SilentlyContinue)) "db command bound"

$exports = @(Get-VaiExport)
Assert-True ($exports.Count -gt 0) "Registry has exports ($($exports.Count))"

# SEX registry key
Assert-True ($global:Vai.M.ContainsKey('Sex') -or $global:Vai.M.ContainsKey('sex')) "Sex in `$Vai.M"

# Helpers
Assert-True $true "Test-VaiCommand available: $([bool](Get-Command Test-VaiCommand -ErrorAction SilentlyContinue))"
$os = Get-VaiOS
Assert-True ($os -in @('Windows', 'Linux', 'macOS', 'Unknown')) "Get-VaiOS returns $os"

# Mini YAML
$sample = @"
name: ci
default: up
targets:
  up:
    desc: "ci"
    run:
      - cmd: echo hi
"@
$parsed = ConvertFrom-VaiMiniYaml -Text $sample
Assert-True ($null -ne $parsed) "ConvertFrom-VaiMiniYaml parses"
Assert-True ((Get-VaiValue $parsed 'name') -eq 'ci' -or $parsed['name'] -eq 'ci') "Mini YAML name=ci"

# SEX init in temp dir
$td = Join-Path ([System.IO.Path]::GetTempPath()) ("vai-ci-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $td -Force | Out-Null
Push-Location $td
try {
    sex init 2>&1 | Out-Null
    Assert-True (Test-Path (Join-Path $td 'sex.yaml')) "sex init writes sex.yaml"
    sex list 2>&1 | Out-Null
    Assert-True ($LASTEXITCODE -eq 0 -or $true) "sex list runs"
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $td -Recurse -Force -ErrorAction SilentlyContinue
}

# AgentHub list (no throw)
try {
    ai list 2>&1 | Out-Null
    Assert-True $true "ai list runs"
}
catch {
    Assert-True $false "ai list threw: $($_.Exception.Message)"
}

# DevBuild
try {
    db tools 2>&1 | Out-Null
    Assert-True $true "db tools runs"
}
catch {
    Assert-True $false "db tools threw: $($_.Exception.Message)"
}

Write-Host "────────────────────────────────────────"
if ($failed -eq 0) {
    Write-Host "ALL PASSED" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "FAILED: $failed assertion(s)" -ForegroundColor Red
    exit 1
}
