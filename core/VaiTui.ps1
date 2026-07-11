# ==============================================================================
# VAI-FRAMEWORK v5.1+ :: TUI chrome — denser, sharper, more fun
# ==============================================================================

function global:Get-VaiAnsi {
    param([int]$Code = 0)
    if (-not $global:Vai.IsModern) { return "" }
    return ([char]27 + "[" + $Code + "m")
}

function global:Get-VaiFg256 {
    param([int]$N)
    if (-not $global:Vai.IsModern) { return "" }
    return ([char]27 + "[38;5;" + $N + "m")
}

function global:Write-VaiPill {
    param(
        [string]$Text,
        [ValidateSet("ok", "lazy", "fail", "sleep", "info", "hot", "dim")]
        [string]$Kind = "info"
    )
    $r = $global:Vai.Reset
    $map = @{
        ok    = @{ fg = 16;  bg = 82  }
        lazy  = @{ fg = 16;  bg = 39  }
        fail  = @{ fg = 255; bg = 196 }
        sleep = @{ fg = 250; bg = 240 }
        info  = @{ fg = 16;  bg = 45  }
        hot   = @{ fg = 16;  bg = 201 }
        dim   = @{ fg = 250; bg = 236 }
    }
    $c = $map[$Kind]
    if ($global:Vai.IsModern) {
        $open = [char]27 + "[38;5;" + $c.fg + ";48;5;" + $c.bg + "m"
        return ($open + " " + $Text + " " + $r)
    }
    return ("[" + $Text + "]")
}

function global:Write-VaiBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [string]$Subtitle,

        [ValidateSet("Magenta", "Cyan", "Green", "Blue", "Yellow", "Hot")]
        [string]$Color = "Magenta",

        [int]$Width = 62
    )

    $r = $global:Vai.Reset
    $accent = switch ($Color) {
        "Hot"     { Get-VaiFg256 201 }
        "Magenta" { $global:Vai.Magenta }
        "Cyan"    { $global:Vai.Cyan }
        "Green"   { $global:Vai.Green }
        "Blue"    { $global:Vai.Blue }
        "Yellow"  { $global:Vai.Yellow }
        default   { $global:Vai.Magenta }
    }
    $dim = Get-VaiFg256 240
    $line = ([string][char]0x2501) * $Width

    Write-Host ""
    Write-Host ("  " + $accent + [char]0x256D + $line + [char]0x256E + $r)

    $padTitle = $Title
    if ($padTitle.Length -gt ($Width - 4)) { $padTitle = $padTitle.Substring(0, $Width - 7) + "..." }
    $inner = "  " + $padTitle
    $inner = $inner + (" " * [Math]::Max(0, $Width - $inner.Length))
    Write-Host ("  " + $accent + [char]0x2502 + $r + $accent + $inner + $r + $accent + [char]0x2502 + $r)

    if ($Subtitle) {
        $sub = "  " + $Subtitle
        if ($sub.Length -gt $Width) { $sub = $sub.Substring(0, $Width - 3) + "..." }
        $sub = $sub + (" " * [Math]::Max(0, $Width - $sub.Length))
        Write-Host ("  " + $accent + [char]0x2502 + $r + $dim + $sub + $r + $accent + [char]0x2502 + $r)
    }

    Write-Host ("  " + $accent + [char]0x2570 + $line + [char]0x256F + $r)
}

function global:Write-VaiBox {
    [CmdletBinding()]
    param(
        [string[]]$Lines,
        [string]$Title,
        [ValidateSet("Cyan", "Green", "Yellow", "Red", "Magenta", "Blue", "Gray", "Hot")]
        [string]$Color = "Cyan",
        [int]$Width = 62
    )

    $r = $global:Vai.Reset
    $c = switch ($Color) {
        "Hot" { Get-VaiFg256 201 }
        default {
            if ($global:Vai.Colors.ContainsKey($Color)) { $global:Vai.Colors[$Color] } else { $global:Vai.Cyan }
        }
    }
    $h = ([string][char]0x2500) * $Width

    Write-Host ""
    if ($Title) {
        $t = " " + $Title + " "
        $left = [Math]::Max(1, [int](($Width - $t.Length) / 2))
        $right = [Math]::Max(1, $Width - $left - $t.Length)
        Write-Host ("  " + $c + [char]0x256D + (([string][char]0x2500) * $left) + $t + (([string][char]0x2500) * $right) + [char]0x256E + $r)
    }
    else {
        Write-Host ("  " + $c + [char]0x256D + $h + [char]0x256E + $r)
    }

    foreach ($line in $Lines) {
        $text = " " + $line
        if ($text.Length -gt $Width) { $text = $text.Substring(0, $Width - 1) }
        $text = $text + (" " * [Math]::Max(0, $Width - $text.Length))
        Write-Host ("  " + $c + [char]0x2502 + $r + $text + $c + [char]0x2502 + $r)
    }

    Write-Host ("  " + $c + [char]0x2570 + $h + [char]0x256F + $r)
}

function global:Write-VaiRule {
    param(
        [int]$Width = 62,
        [string]$Label
    )
    $dim = Get-VaiFg256 238
    $r = $global:Vai.Reset
    if ($Label) {
        $t = " " + $Label + " "
        $left = 4
        $right = [Math]::Max(1, $Width - $left - $t.Length)
        Write-Host ("  " + $dim + (([string][char]0x2500) * $left) + $global:Vai.Gray + $t + $dim + (([string][char]0x2500) * $right) + $r)
    }
    else {
        Write-Host ("  " + $dim + (([string][char]0x2500) * $Width) + $r)
    }
}

function global:Write-VaiStep {
    param(
        [int]$Index,
        [int]$Total,
        [string]$Message,
        [ValidateSet("run", "ok", "fail", "skip", "bg")]
        [string]$State = "run"
    )

    $icon = switch ($State) {
        "run"  { Write-VaiPill ">" "info" }
        "ok"   { Write-VaiPill "+" "ok" }
        "fail" { Write-VaiPill "x" "fail" }
        "skip" { Write-VaiPill "-" "dim" }
        "bg"   { Write-VaiPill "*" "hot" }
    }

    $idx = $global:Vai.Gray + ("{0}/{1}" -f $Index, $Total) + $global:Vai.Reset
    Write-Host ("  " + $icon + " " + $idx + "  " + $Message)
}

function global:Write-VaiKV {
    <#
    .SYNOPSIS
        Key/value line. 3rd positional arg may be KeyWidth (int) OR ValueColor (string).
    .EXAMPLE
        Write-VaiKV "branch" "main" "Yellow"
        Write-VaiKV "cwd" $pwd -KeyWidth 10 -ValueColor Cyan
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,

        [Parameter(Position = 1)]
        [string]$Value,

        [Parameter(Position = 2)]
        $KeyWidth = 14,

        [Parameter(Position = 3)]
        [string]$ValueColor = "Green"
    )

    # Smart 3rd arg: "Yellow"/"Cyan"/... → color; number → width
    $width = 14
    $colorName = $ValueColor
    if ($null -ne $KeyWidth) {
        if ($KeyWidth -is [int] -or ($KeyWidth -is [string] -and $KeyWidth -match '^\d+$')) {
            $width = [int]$KeyWidth
        }
        elseif ($KeyWidth -is [string] -and $KeyWidth -ne "") {
            $colorName = [string]$KeyWidth
        }
    }

    $vc = if ($global:Vai.Colors -and $global:Vai.Colors.ContainsKey($colorName)) {
        $global:Vai.Colors[$colorName]
    }
    else { $global:Vai.Green }

    $bullet = Get-VaiFg256 240
    Write-Host ("  " + $bullet + [char]0x2022 + $global:Vai.Reset + " " +
        $global:Vai.Gray + $Key.PadRight($width) + $global:Vai.Reset + " " + $vc + $Value + $global:Vai.Reset)
}

function global:Write-VaiModuleRow {
    param($Manifest)

    $kind = switch ($Manifest.Status) {
        "Loaded" { "ok" }
        "Lazy"   { "lazy" }
        "Failed" { "fail" }
        default  { "sleep" }
    }
    $label = switch ($Manifest.Status) {
        "Loaded" { "ON  " }
        "Lazy"   { "LAZY" }
        "Failed" { "FAIL" }
        default  { "OFF " }
    }
    $pill = Write-VaiPill $label $kind

    $exCount = @($Manifest.Exports).Count
    if ($exCount -eq 0) { $exCount = @($Manifest.LazyTriggers).Count }
    $time = if ($Manifest.Status -eq "Loaded" -and $Manifest.LoadTimeMs) {
        $global:Vai.Gray + ("{0,7:N0}ms" -f $Manifest.LoadTimeMs) + $global:Vai.Reset
    } else {
        $global:Vai.Gray + "       " + $global:Vai.Reset
    }

    $name = $Manifest.Name
    if ($name.Length -gt 16) { $name = $name.Substring(0, 14) + ".." }
    $name = $name.PadRight(16)

    $pfx = if ($Manifest.Prefix) { $Manifest.Prefix } else { "-" }
    $key = if ($Manifest.RegistryKey) { $Manifest.RegistryKey } else { "-" }

    Write-Host ("  " + $pill + " " +
        $global:Vai.Cyan + $name + $global:Vai.Reset +
        $global:Vai.Gray + " v" + $Manifest.Version.PadRight(7) + $global:Vai.Reset +
        $global:Vai.Magenta + (" {0,-8}" -f $pfx) + $global:Vai.Reset +
        $global:Vai.Blue + (" ->{0,-8}" -f $key) + $global:Vai.Reset +
        $global:Vai.Gray + (" exp:{0,-3}" -f $exCount) + $global:Vai.Reset +
        " " + $time)
}

function global:Show-VaiModuleGrid {
    param(
        [string]$Title = "MODULES",
        $Modules
    )

    if (-not $Modules) { $Modules = $global:VaiModulesCache }

    Write-VaiBanner -Title $Title -Subtitle ("vai-core v" + $global:VaiCoreVersion + "  ·  " + @($Modules).Count + " modules") -Color Hot
    Write-Host ("  " + $global:Vai.Gray + "      name             ver      prefix   key      exports" + $global:Vai.Reset)
    Write-VaiRule -Label "roster"

    foreach ($m in $Modules) {
        Write-VaiModuleRow -Manifest $m
    }

    $on   = @($Modules | Where-Object { $_.Status -eq "Loaded" }).Count
    $lazy = @($Modules | Where-Object { $_.Status -eq "Lazy" }).Count
    $fail = @($Modules | Where-Object { $_.Status -eq "Failed" }).Count
    $off  = @($Modules | Where-Object { $_.Status -eq "Sleeping" -or $_.Status -eq "Pending" }).Count

    Write-VaiRule
    Write-Host ("  " +
        (Write-VaiPill "total $(@($Modules).Count)" "hot") + " " +
        (Write-VaiPill "on $on" "ok") + " " +
        (Write-VaiPill "lazy $lazy" "lazy") + " " +
        (Write-VaiPill "fail $fail" "fail") + " " +
        (Write-VaiPill "off $off" "sleep"))
    Write-Host ""
}

function global:Show-VaiMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string[]]$Items
    )

    Write-VaiBanner -Title $Title -Color Cyan
    for ($i = 0; $i -lt $Items.Count; $i++) {
        Write-Host ("    " + (Write-VaiPill ($i + 1) "info") + "  " + $Items[$i])
    }
    Write-Host ("    " + (Write-VaiPill "0" "dim") + "  Cancel")
    $sel = Read-Host "  Choose"
    if ($sel -match '^\d+$') {
        $n = [int]$sel
        if ($n -eq 0) { return 0 }
        if ($n -ge 1 -and $n -le $Items.Count) { return $n }
    }
    return 0
}

function global:Get-VaiModulePartFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleRoot
    )

    $lib = Join-Path $ModuleRoot "lib"
    if (-not (Test-Path -LiteralPath $lib)) { return @() }

    return @(
        Get-ChildItem -LiteralPath $lib -Filter "*.ps1" -File -ErrorAction SilentlyContinue |
            Sort-Object Name |
            ForEach-Object { $_.FullName }
    )
}

function global:Import-VaiModuleParts {
    [CmdletBinding()]
    param(
        [string]$ModuleRoot = $PSScriptRoot
    )

    foreach ($p in (Get-VaiModulePartFiles -ModuleRoot $ModuleRoot)) {
        . $p
    }
}
