# ==============================================================================
# VAI-FRAMEWORK v5 :: CLI utilities
# ==============================================================================

$script:VaiAuthor = "Vadim Khristenko <vadim+pwsh@vai-rice.space>"

function global:Show-VaiModuleList {
    Show-VaiModuleGrid -Title "VAI MODULES" -Modules $global:VaiModulesCache
    Write-Host ("  " + $global:Vai.Gray + "Author: " + $script:VaiAuthor + $global:Vai.Reset)
    Write-Host ("  " + $global:Vai.Gray + "Tip: Lazy = still a full module (loads on first command)." + $global:Vai.Reset)
    Write-Host ""
}

function global:Show-VaiModuleInfo {
    param([string]$Name)

    $cCyan   = $global:Vai.Cyan
    $cYellow = $global:Vai.Yellow
    $cReset  = $global:Vai.Reset

    if (-not $Name) {
        Write-Host "Usage: vai-module info <Name>" -ForegroundColor Red
        return
    }

    $m = Get-VaiModule -Name $Name | Select-Object -First 1
    if (-not $m) {
        Write-Host ("Module '" + $Name + "' not found.") -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host ("  " + $cCyan + "SPEC: " + $m.Name + $cReset)
    Write-Host ("  Version      : v" + $m.Version + " | Author: " + $m.Author)
    Write-Host ("  Status      : " + $m.Status)
    Write-Host ("  Prefix      : " + $m.Prefix + " | RegistryKey: " + $m.RegistryKey)
    Write-Host ("  Description : " + $m.Description)
    Write-Host ("  Config      : " + $m.ConfigPath)
    Write-Host ("  ShortAliases: " + $m.ShortAliases)

    if ($m.DependsOn.Count -gt 0) {
        Write-Host ("  DependsOn   : " + ($m.DependsOn -join ", "))
    }

    $exports = @(Get-VaiExport -Module $m.RegistryKey)
    if ($exports.Count -eq 0 -and $m.Exports) {
        Write-Host ("  " + $cYellow + "Declared Exports:" + $cReset + " " + ($m.Exports -join ", "))
    }
    else {
        Write-Host ("  " + $cYellow + "Registered Exports:" + $cReset)
        foreach ($e in $exports) {
            $lazyTag = if ($e.Lazy) { " [lazy]" } else { "" }
            Write-Host ("    " + $e.Prefix + ":" + $e.Name + "  alias=" + $e.AliasFn + $lazyTag)
        }
    }

    if ($m.LatestChange) {
        $ver  = Get-VaiValue $m.LatestChange "version" "?"
        $date = Get-VaiValue $m.LatestChange "date" "?"
        Write-Host ("  " + $cYellow + "Latest:" + $cReset + " v" + $ver + " (" + $date + ")")
    }

    Write-Host ("  " + $cYellow + "Settings:" + $cReset)
    $cfg = Read-VaiJson $m.ConfigPath
    if ($cfg -and (Test-VaiProperty $cfg "Settings")) {
        $cfg.Settings.PSObject.Properties | ForEach-Object {
            Write-Host ("    " + $_.Name + " = " + $_.Value) -ForegroundColor Gray
        }
    }
}

function global:Show-VaiModuleDeps {
    $cCyan   = $global:Vai.Cyan
    $cYellow = $global:Vai.Yellow
    $cReset  = $global:Vai.Reset

    Write-Host ""
    Write-Host ("  " + $cCyan + "LOAD GRAPH:" + $cReset)
    Write-VaiSeparator

    $i = 1
    foreach ($m in $global:VaiModulesCache) {
        $deps = ""
        if ($m.DependsOn.Count -gt 0) {
            $deps = " " + $cYellow + [char]0x2192 + $cReset + " " + ($m.DependsOn -join ", ")
        }
        Write-Host ("  " + $i.ToString().PadLeft(2) + ". " + $m.Name + " [" + $m.RegistryKey + "]" + $deps) -ForegroundColor Gray
        $i++
    }
}

function global:Show-VaiLogTail {
    param([string]$CountOrName)

    $cCyan   = $global:Vai.Cyan
    $cRed    = $global:Vai.Red
    $cYellow = $global:Vai.Yellow
    $cGray   = $global:Vai.Gray
    $cReset  = $global:Vai.Reset

    if (-not (Test-Path $global:VaiLogPath)) {
        Write-Host "Log empty or missing." -ForegroundColor Yellow
        return
    }

    $count = if ($CountOrName -match '^\d+$') { [int]$CountOrName } else { 20 }

    Write-Host ""
    Write-Host ("  " + $cCyan + "LAST " + $count + " LOG LINES:" + $cReset)
    Write-VaiSeparator

    Get-Content $global:VaiLogPath -Tail $count | ForEach-Object {
        $color = $cGray
        if ($_ -match '\[ERROR') { $color = $cRed }
        elseif ($_ -match '\[WARN') { $color = $cYellow }
        Write-Host ("  " + $color + $_ + $cReset)
    }
}

function global:Set-VaiModuleSetting {
    param(
        [string]$Name,
        [string]$Key,
        $Value
    )

    if (-not $Name -or -not $Key -or $null -eq $Value) {
        Write-Host "Usage: vai-module set <Module> <Key> <Value>" -ForegroundColor Red
        return
    }

    $m = Get-VaiModule -Name $Name | Select-Object -First 1
    if (-not $m) {
        Write-Host ("Module '" + $Name + "' not found.") -ForegroundColor Red
        return
    }

    $cfg = Read-VaiJson $m.ConfigPath
    if (-not (Test-VaiProperty $cfg.Settings $Key)) {
        Write-Host ("Setting '" + $Key + "' missing in module '" + $m.Name + "'.") -ForegroundColor Red
        return
    }

    $typedValue = switch -regex ($Value) {
        '^true$'      { $true }
        '^false$'     { $false }
        '^\d+$'       { [int]$Value }
        '^\d+\.\d+$'  { [double]$Value }
        default       { $Value }
    }

    $cfg.Settings.$Key = $typedValue
    $jsonText = $cfg | ConvertTo-Json -Depth 10
    Write-VaiFile -Path $m.ConfigPath -Content $jsonText -Bom

    Write-VaiLog -Level INFO -Message ("Set '" + $Key + "'='" + $typedValue + "' on '" + $m.Name + "'")
    Write-Host "[OK] Saved. Run: vai-reload" -ForegroundColor Green
}

function global:Show-VaiModuleHelp {
    Write-Host ""
    Write-Host ("  VAI-FRAMEWORK module manager v" + $global:VaiCoreVersion) -ForegroundColor Cyan
    Write-Host ("  Author: " + $script:VaiAuthor) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  vai-module list                          List modules"
    Write-Host "  vai-module info <Name>                   Manifest + exports"
    Write-Host "  vai-module deps                          Load graph"
    Write-Host "  vai-module log [N]                       Tail log"
    Write-Host "  vai-module set <Name> <Key> <Value>      Change setting"
    Write-Host "  vai-module help                          This help"
    Write-Host "  vai-call <Module> <cmd> [args...]        Invoke-Vai sugar"
    Write-Host "  Invoke-Vai <Module> <cmd> [args...]      Script API"
    Write-Host "  Get-VaiExport / Get-VaiModule            Introspection"
    Write-Host ""
}

function global:vai-changelog {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$TargetName,

        [Parameter(Position = 1)]
        [int]$Limit = 5
    )

    $cCyan    = $global:Vai.Cyan
    $cMagenta = $global:Vai.Magenta
    $cGreen   = $global:Vai.Green
    $cYellow  = $global:Vai.Yellow
    $cRed     = $global:Vai.Red
    $cGray    = $global:Vai.Gray
    $cReset   = $global:Vai.Reset

    if (-not $TargetName) {
        Write-Host "Usage: vai-changelog <Module> [count]" -ForegroundColor Yellow
        return
    }

    $m = Get-VaiModule -Name $TargetName | Select-Object -First 1
    if (-not $m) {
        Write-Host "Module not found." -ForegroundColor Red
        return
    }
    if (-not $m.ChangelogPath) {
        Write-Host ("No changelog.json for '" + $m.Name + "'.") -ForegroundColor Yellow
        return
    }

    $clData  = Read-VaiJson $m.ChangelogPath
    $entries = Get-VaiChangelogEntries $clData

    Write-Host ""
    Write-Host ("  " + $cCyan + "CHANGELOG: " + $m.Name + $cReset)
    Write-VaiSeparator

    $shown = 0
    foreach ($e in $entries) {
        if ($shown -ge $Limit) { break }

        $ver  = Get-VaiValue $e "version" "?"
        $date = Get-VaiValue $e "date" ""
        $type = Get-VaiValue $e "type" ""

        $typeColor = switch ($type) {
            "feat"     { $cGreen }
            "fix"      { $cYellow }
            "breaking" { $cRed }
            default    { $cGray }
        }

        Write-Host ("  " + $cMagenta + "v" + $ver + $cReset + "  " + $cGray + $date + $cReset + "  " + $typeColor + $type + $cReset)

        $changes = @(Get-VaiValue $e "changes" @())
        foreach ($c in $changes) {
            Write-Host ("    " + [char]0x2022 + " " + $c) -ForegroundColor Gray
        }
        $shown++
    }

    if ($shown -eq 0) { Write-Host "  (no entries)" -ForegroundColor DarkGray }
}

function global:vai-reload {
    $cYellow = $global:Vai.Yellow
    $cReset  = $global:Vai.Reset

    Write-Host ""
    Write-Host ($cYellow + "[~] Hot reload..." + $cReset)
    Write-VaiLog -Level INFO -Message "Hot reload requested" -NoConsole

    if (Get-Command Clear-VaiRegistry -ErrorAction SilentlyContinue) {
        Clear-VaiRegistry
    }

    $initPath = Join-Path $global:VaiFrameworkRoot "init.ps1"
    if (Test-Path $initPath) {
        $global:_VaiInitGuard = $false
        . $initPath
    }
    else {
        Write-Host ("  [FATAL] init.ps1 missing: " + $initPath) -ForegroundColor Red
    }
}

function global:vai-doctor {
    $cCyan   = $global:Vai.Cyan
    $cGreen  = $global:Vai.Green
    $cYellow = $global:Vai.Yellow
    $cRed    = $global:Vai.Red
    $cGray   = $global:Vai.Gray
    $cReset  = $global:Vai.Reset

    Write-Host ""
    Write-Host ($cCyan + "VAI-FRAMEWORK DIAGNOSTICS" + $cReset)
    Write-Host ("  Author: " + $script:VaiAuthor) -ForegroundColor DarkGray
    Write-VaiSeparator

    $adminText = if (Test-VaiAdmin) {
        $cGreen + "elevated" + $cReset
    }
    else {
        $cYellow + "user" + $cReset
    }

    $ansiText = if ($global:Vai.IsModern) {
        $cGreen + "on" + $cReset
    }
    else {
        $cGray + "off" + $cReset
    }

    $total  = $global:VaiModulesCache.Count
    $active = @($global:VaiModulesCache | Where-Object { $_.Status -eq "Loaded" }).Count
    $failed = @($global:VaiModulesCache | Where-Object { $_.Status -eq "Failed" }).Count
    $exports = @(Get-VaiExport).Count

    $failedText = if ($failed -gt 0) { $cRed + $failed + $cReset } else { "0" }

    Write-Host ("  [+] Version     : v" + $global:VaiCoreVersion)
    Write-Host ("  [+] Root        : " + $global:VaiFrameworkRoot)
    Write-Host ("  [+] OS          : " + (Get-VaiOS))
    Write-Host ("  [+] Rights      : " + $adminText)
    Write-Host ("  [+] Engine      : " + $PSVersionTable.PSEdition + " (" + $PSVersionTable.PSVersion + ")")
    Write-Host ("  [+] ANSI        : " + $ansiText)
    Write-Host ("  [+] PrefixStyle : " + $global:Vai.PrefixStyle)
    Write-Host ("  [+] Log file    : " + $global:VaiLogPath)
    Write-Host ("  [+] Log level   : " + $global:VaiMinLogLevel)
    Write-Host ("  [+] Modules     : total " + $total + " | active " + $active + " | failed " + $failedText)
    Write-Host ("  [+] Exports     : " + $exports)
    Write-Host ("  [+] Modules dir : " + (Join-Path $global:VaiFrameworkRoot "modules"))
    Write-Host ("  [+] SEX slogan  : " + $global:Vai.Slogan.Sex)

    $upd = if ($global:Vai.Update) { $global:Vai.Update.Status } else { "n/a" }
    Write-Host ("  [+] Update      : " + $upd + " (vai-update)")

    if ($failed -gt 0) {
        Write-Host ("  " + $cRed + "Failed modules:" + $cReset)
        $global:VaiModulesCache | Where-Object { $_.Status -eq "Failed" } | ForEach-Object {
            Write-Host ("    - " + $_.Name) -ForegroundColor Red
        }
    }

    Write-Host ""
}

function global:vai-call {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Module,

        [Parameter(Mandatory, Position = 1)]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    Invoke-Vai -Module $Module -Command $Command @RemainingArguments
}

function global:vai-new-module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[a-zA-Z0-9_-]+$')]
        [string]$Name,

        [string]$Prefix
    )

    if (-not $Prefix) {
        $Prefix = ($Name -replace 'Tweaks$', '' -replace '^vai-', '').ToLower()
        if (-not $Prefix) { $Prefix = $Name.ToLower() }
    }

    $regKey = $Prefix.Substring(0, 1).ToUpper() + $Prefix.Substring(1).ToLower()
    if ($Prefix.Length -eq 1) { $regKey = $Prefix.ToUpper() }

    $modulesRoot = Join-Path $global:VaiFrameworkRoot "modules"
    if (-not (Test-Path $modulesRoot)) {
        New-Item -ItemType Directory -Path $modulesRoot -Force | Out-Null
    }

    $dir = Join-Path $modulesRoot $Name
    if (Test-Path $dir) {
        Write-Host ("Folder '" + $Name + "' already exists under modules/.") -ForegroundColor Red
        return
    }

    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "lib") -Force | Out-Null
    $today = (Get-Date).ToString("yyyy-MM-dd")

    $config = [ordered]@{
        Meta = [ordered]@{
            Name        = $Name
            Prefix      = $Prefix
            Version     = "1.0.0"
            Author      = $script:VaiAuthor
            Description = "Module $Name"
        }
        Settings = [ordered]@{
            EnableModule = $true
            LoadPriority = 100
            LazyLoad     = $false
            DependsOn    = @()
            ShortAliases = $true
            Exports      = @("hello")
        }
    }

    $changelog = [ordered]@{
        entries = @(
            [ordered]@{
                version = "1.0.0"
                date    = $today
                type    = "feat"
                changes = @("Initial module scaffold (v5.1 modules/ + lib/)")
            }
        )
    }

    $libScript = @"
function script:Invoke-${regKey}Hello {
    Write-VaiBanner -Title '$Name' -Subtitle 'hello from lib/' -Color Cyan
    Write-VaiHost ("Registry: Invoke-Vai $regKey hello  |  ${Prefix}:hello") -Color Gray
}
"@

    $moduleScript = @"
# ==============================================================================
# Module $Name — VAI-FRAMEWORK v5.1
# Author: $($script:VaiAuthor)
# ==============================================================================

Get-VaiModulePartFiles -ModuleRoot `$PSScriptRoot | ForEach-Object { . `$_ }

`$reg = if (`$global:VaiModule) { `$global:VaiModule.RegistryKey } else { '$regKey' }
`$pfx = if (`$global:VaiModule) { `$global:VaiModule.Prefix } else { '$Prefix' }

Register-VaiExport -Module `$reg -Name hello -ScriptBlock `${function:Invoke-${regKey}Hello} -Alias '${Name}-hello' -Prefix `$pfx
"@

    Write-VaiFile -Path (Join-Path $dir "config.json")    -Content ($config    | ConvertTo-Json -Depth 10) -Bom
    Write-VaiFile -Path (Join-Path $dir "changelog.json") -Content ($changelog | ConvertTo-Json -Depth 10) -Bom
    Write-VaiFile -Path (Join-Path $dir "lib\01-main.ps1") -Content $libScript
    Write-VaiFile -Path (Join-Path $dir "module.ps1")     -Content $moduleScript

    Write-Host ("[OK] Module '" + $Name + "' created at " + $dir) -ForegroundColor Green
    Write-Host "    Prefix: $Prefix | RegistryKey: $regKey | Export: hello" -ForegroundColor Gray
    Write-Host "    Layout: modules/$Name/{module.ps1,lib/,config.json}" -ForegroundColor Gray
    Write-Host "    Run: vai-reload" -ForegroundColor Gray
    Write-VaiLog -Level INFO -Message ("Created module '" + $Name + "'")
    Write-Host ""
}

function global:vai-module {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet("list", "info", "set", "deps", "log", "help")]
        [string]$Action = "list",

        [Parameter(Position = 1)]
        [string]$TargetName,

        [Parameter(Position = 2)]
        [string]$SettingName,

        [Parameter(Position = 3)]
        $SettingValue
    )

    switch ($Action) {
        "list" { Show-VaiModuleList }
        "info" { Show-VaiModuleInfo -Name $TargetName }
        "deps" { Show-VaiModuleDeps }
        "log"  { Show-VaiLogTail -CountOrName $TargetName }
        "set"  { Set-VaiModuleSetting -Name $TargetName -Key $SettingName -Value $SettingValue }
        "help" { Show-VaiModuleHelp }
    }
}
