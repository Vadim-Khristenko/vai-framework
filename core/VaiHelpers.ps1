# ==============================================================================
# VAI-FRAMEWORK v5.1 :: Helpers (files, JSON, UX, project, YAML, mini-yaml)
# ==============================================================================

function global:Write-VaiFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content,

        [switch]$Bom
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $encoding = [System.Text.UTF8Encoding]::new($Bom.IsPresent)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function global:Read-VaiJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) { return $null }

    try {
        $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        if (Get-Command Write-VaiLog -ErrorAction SilentlyContinue) {
            Write-VaiLog -Level WARN -Message "JSON parse error '$Path': $($_.Exception.Message)"
        }
        return $null
    }
}

function global:Test-VaiProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [string]$Name
    )

    if ($null -eq $Object) { return $false }
    if ($Object -is [hashtable]) { return $Object.ContainsKey($Name) }
    return ($Object.PSObject.Properties.Name -contains $Name)
}

function global:Get-VaiValue {
    param(
        $Object,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) { return $Default }
    if ($Object -is [hashtable]) {
        if ($Object.ContainsKey($Name)) { return $Object[$Name] }
        return $Default
    }
    if ((Test-VaiProperty -Object $Object -Name $Name)) {
        return $Object.$Name
    }
    return $Default
}

function global:Get-VaiChangelogEntries {
    param(
        [Parameter(Mandatory)]
        $ChangelogObject
    )

    if ($null -eq $ChangelogObject) { return @() }

    if ($ChangelogObject -is [System.Array]) {
        return $ChangelogObject
    }

    if (Test-VaiProperty $ChangelogObject "entries") {
        return @($ChangelogObject.entries)
    }

    return @()
}

function global:Merge-VaiHashtable {
    [CmdletBinding()]
    param(
        [hashtable]$Base = @{},
        [hashtable]$Overlay = @{}
    )

    $result = @{}
    foreach ($k in $Base.Keys) { $result[$k] = $Base[$k] }

    foreach ($k in $Overlay.Keys) {
        $bv = $result[$k]
        $ov = $Overlay[$k]
        if ($bv -is [hashtable] -and $ov -is [hashtable]) {
            $result[$k] = Merge-VaiHashtable -Base $bv -Overlay $ov
        }
        else {
            $result[$k] = $ov
        }
    }
    return $result
}

function global:Write-VaiHost {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Message = "",

        [ValidateSet("Default", "Cyan", "Green", "Yellow", "Red", "Gray", "Magenta", "Blue")]
        [string]$Color = "Default"
    )

    if ($Color -eq "Default") {
        Write-Host $Message
        return
    }
    $c = $global:Vai.Colors[$Color]
    $r = $global:Vai.Colors.Reset
    Write-Host ($c + $Message + $r)
}

function global:Write-VaiHeader {
    param([string]$Title)
    $c = $global:Vai.Cyan
    $r = $global:Vai.Reset
    Write-Host ""
    Write-Host ("  " + $c + $Title + $r)
    Write-VaiSeparator
}

function global:Write-VaiSeparator {
    Write-Host "  ────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
}

function global:Write-VaiOk {
    param([string]$Message)
    Write-Host ("  " + $global:Vai.Green + "[OK] " + $global:Vai.Reset + $Message)
}

function global:Write-VaiWarn {
    param([string]$Message)
    Write-Host ("  " + $global:Vai.Yellow + "[!] " + $global:Vai.Reset + $Message)
    if (Get-Command Write-VaiLog -ErrorAction SilentlyContinue) {
        Write-VaiLog -Level WARN -Message $Message -NoConsole
    }
}

function global:Write-VaiError {
    param([string]$Message)
    Write-Host ("  " + $global:Vai.Red + "[X] " + $global:Vai.Reset + $Message)
    if (Get-Command Write-VaiLog -ErrorAction SilentlyContinue) {
        Write-VaiLog -Level ERROR -Message $Message -NoConsole
    }
}

function global:Confirm-VaiAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [switch]$Force,

        [switch]$DefaultYes
    )

    if ($Force) { return $true }

    $hint = if ($DefaultYes) { "Y/n" } else { "y/N" }
    $answer = Read-Host "  $Message ($hint)"

    if ([string]::IsNullOrWhiteSpace($answer)) { return [bool]$DefaultYes }
    return ($answer -match '^[yYдД]')
}

function global:Get-VaiBar {
    param(
        [double]$Percent,
        [int]$Width = 16
    )

    if ($Percent -lt 0) { $Percent = 0 }
    $capped = [Math]::Min($Percent, 100)
    $filled = [int][Math]::Round(($capped / 100) * $Width)
    if ($filled -gt $Width) { $filled = $Width }

    $color = if ($Percent -ge 80) { $global:Vai.Red }
             elseif ($Percent -ge 50) { $global:Vai.Yellow }
             else { $global:Vai.Green }

    $bar = ([string][char]0x2588) * $filled + ([string][char]0x2591) * ($Width - $filled)
    return ($color + $bar + $global:Vai.Reset)
}

function global:Resolve-VaiPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Base
    )

    if ($Path.StartsWith("~")) {
        $homePath = Get-VaiHomePath
        $rest = $Path.Substring(1).TrimStart("\", "/")
        if ($rest) { return (Join-Path $homePath $rest) }
        return $homePath
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    if ($Base) {
        return (Join-Path $Base $Path)
    }
    return (Join-Path (Get-Location).Path $Path)
}

function global:Find-VaiProjectRoot {
    [CmdletBinding()]
    param(
        [string]$StartPath = (Get-Location).Path,

        [string[]]$Markers = @(
            ".git", "sex.yaml", "sex.yml", "sex.json", "Cargo.toml",
            "package.json", "pyproject.toml", "go.mod", "composer.json"
        )
    )

    $current = (Resolve-Path -LiteralPath $StartPath -ErrorAction SilentlyContinue)
    if (-not $current) { return $null }
    $dir = Get-Item -LiteralPath $current.Path

    while ($dir) {
        foreach ($m in $Markers) {
            $candidate = Join-Path $dir.FullName $m
            if (Test-Path -LiteralPath $candidate) {
                return $dir.FullName
            }
        }
        if ($null -eq $dir.Parent -or $dir.FullName -eq $dir.Parent.FullName) { break }
        $dir = $dir.Parent
    }
    return $null
}

function global:ConvertFrom-VaiMiniYaml {
    <#
    .SYNOPSIS
        Restricted YAML dialect for sex.yaml (zero deps).
        Maps, nested maps, and lists of scalars / single-line map items (- cmd: ...).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $unquote = {
        param([string]$v)
        $v = $v.Trim()
        if ($v -match '^"(.*)"$') { return $matches[1] }
        if ($v -match "^'(.*)'$") { return $matches[1] }
        if ($v -eq 'true') { return $true }
        if ($v -eq 'false') { return $false }
        if ($v -match '^-?\d+$') { return [int]$v }
        if ($v -match '^-?\d+\.\d+$') { return [double]$v }
        if ($v -eq 'null' -or $v -eq '~' -or $v -eq '') { return $null }
        return $v
    }

    $toHash = $null
    $toHash = {
        param($o)
        if ($o -is [System.Collections.IDictionary]) {
            $h = @{}
            foreach ($k in @($o.Keys)) { $h[[string]$k] = & $toHash $o[$k] }
            return $h
        }
        if ($o -is [System.Collections.IList] -and -not ($o -is [string])) {
            $arr = @()
            foreach ($item in $o) { $arr += ,(& $toHash $item) }
            return $arr
        }
        return $o
    }

    $lines = [System.Collections.Generic.List[object]]::new()
    foreach ($raw in ($Text -split "`r?`n")) {
        if ($raw -match '^\s*#') { continue }
        if ($raw -match '^\s*$') { continue }
        if ($raw -match '^( *)(.*)$') {
            $lines.Add([pscustomobject]@{ Indent = $matches[1].Length; Text = $matches[2].TrimEnd() })
        }
    }

    # Shared mutable bag — scriptblocks assign through hashtable (PS-safe)
    $ctx = @{
        i    = 0
        map  = $null
        list = $null
    }

    $ctx.list = {
        param([int]$baseIndent)
        $list = [System.Collections.Generic.List[object]]::new()
        while ($ctx.i -lt $lines.Count) {
            $line = $lines[$ctx.i]
            if ($line.Indent -ne $baseIndent) { break }
            if ($line.Text -notmatch '^- (.*)$') { break }
            $rest = $matches[1]
            $itemIndent = $line.Indent
            $ctx.i++

            # URLs / paths with colon are scalars, not map entries (http://...)
            if ($rest -match '://' -or $rest -match '^[A-Za-z]:\\') {
                $list.Add((& $unquote $rest))
            }
            elseif ($rest -match '^([\w][\w-]*)\s*:\s*(.*)$') {
                $item = [ordered]@{}
                $ik = $matches[1]
                $iv = $matches[2]
                if (-not [string]::IsNullOrWhiteSpace($iv)) {
                    $item[$ik] = & $unquote $iv
                }
                else {
                    if ($ctx.i -lt $lines.Count -and $lines[$ctx.i].Indent -gt $itemIndent) {
                        if ($lines[$ctx.i].Text -match '^- ') {
                            $item[$ik] = & $ctx.list $lines[$ctx.i].Indent
                        }
                        else {
                            $item[$ik] = & $ctx.map ($itemIndent + 1)
                        }
                    }
                    else { $item[$ik] = $null }
                }
                while ($ctx.i -lt $lines.Count -and $lines[$ctx.i].Indent -gt $itemIndent -and $lines[$ctx.i].Text -notmatch '^- ') {
                    $sl = $lines[$ctx.i]
                    if ($sl.Text -match '^([\w][\w-]*)\s*:\s*(.*)$') {
                        $sk = $matches[1]; $sv = $matches[2]; $ctx.i++
                        if (-not [string]::IsNullOrWhiteSpace($sv)) {
                            $item[$sk] = & $unquote $sv
                        }
                        elseif ($ctx.i -lt $lines.Count -and $lines[$ctx.i].Text -match '^- ') {
                            $item[$sk] = & $ctx.list $lines[$ctx.i].Indent
                        }
                        else {
                            $item[$sk] = & $ctx.map ($sl.Indent + 1)
                        }
                    }
                    else { $ctx.i++; break }
                }
                $list.Add($item)
            }
            else {
                $list.Add((& $unquote $rest))
            }
        }
        return $list
    }

    $ctx.map = {
        param([int]$baseIndent)
        $map = [ordered]@{}
        while ($ctx.i -lt $lines.Count) {
            $line = $lines[$ctx.i]
            if ($line.Indent -ne $baseIndent) { break }
            if ($line.Text -match '^- ') { break }
            if ($line.Text -notmatch '^([\w][\w-]*)\s*:\s*(.*)$') { $ctx.i++; continue }

            $key = $matches[1]
            $val = $matches[2]
            $keyIndent = $line.Indent
            $ctx.i++

            if (-not [string]::IsNullOrWhiteSpace($val)) {
                $map[$key] = & $unquote $val
                continue
            }

            if ($ctx.i -ge $lines.Count -or $lines[$ctx.i].Indent -le $keyIndent) {
                $map[$key] = $null
                continue
            }

            if ($lines[$ctx.i].Text -match '^- ') {
                $map[$key] = & $ctx.list $lines[$ctx.i].Indent
            }
            else {
                $map[$key] = & $ctx.map $lines[$ctx.i].Indent
            }
        }
        return $map
    }

    $topIndent = if ($lines.Count -gt 0) { $lines[0].Indent } else { 0 }
    $root = & $ctx.map $topIndent
    return (& $toHash $root)
}

function global:Read-VaiYaml {
    <#
    .SYNOPSIS
        Load YAML: powershell-yaml → yq → python → mini-yaml dialect.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    $rawText = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)

    # 1) powershell-yaml
    if (Get-Module -ListAvailable -Name powershell-yaml -ErrorAction SilentlyContinue) {
        try {
            Import-Module powershell-yaml -ErrorAction Stop
            return (ConvertFrom-Yaml $rawText)
        }
        catch {
            Write-VaiLog -Level DEBUG -Message "powershell-yaml failed: $($_.Exception.Message)" -NoConsole
        }
    }

    # 2) yq → JSON
    if (Test-VaiCommand "yq") {
        try {
            $r = Invoke-VaiNative -FilePath "yq" -ArgumentList @("-o=json", ".", $Path)
            if ($r.ExitCode -eq 0 -and $r.StdOut) {
                return ($r.StdOut | ConvertFrom-Json -ErrorAction Stop)
            }
        }
        catch {
            Write-VaiLog -Level DEBUG -Message "yq yaml failed: $($_.Exception.Message)" -NoConsole
        }
    }

    # 3) python + yaml
    $py = $null
    foreach ($c in @("python", "python3", "py")) {
        if (Test-VaiCommand $c) { $py = $c; break }
    }
    if ($py) {
        $code = @"
import json,sys
try:
    import yaml
except ImportError:
    sys.exit(2)
with open(sys.argv[1], encoding='utf-8') as f:
    data = yaml.safe_load(f)
json.dump(data, sys.stdout, ensure_ascii=False)
"@
        $tmpPy = Join-Path ([System.IO.Path]::GetTempPath()) ("vai-yaml-" + [guid]::NewGuid().ToString("N") + ".py")
        try {
            Write-VaiFile -Path $tmpPy -Content $code
            $r = Invoke-VaiNative -FilePath $py -ArgumentList @($tmpPy, $Path)
            if ($r.ExitCode -eq 0 -and $r.StdOut) {
                return ($r.StdOut | ConvertFrom-Json -ErrorAction Stop)
            }
        }
        catch {
            Write-VaiLog -Level DEBUG -Message "python yaml failed: $($_.Exception.Message)" -NoConsole
        }
        finally {
            Remove-Item -LiteralPath $tmpPy -Force -ErrorAction SilentlyContinue
        }
    }

    # 4) built-in mini dialect (SEX-friendly, no deps)
    try {
        return (ConvertFrom-VaiMiniYaml -Text $rawText)
    }
    catch {
        Write-VaiError "Cannot parse YAML '$Path': $($_.Exception.Message)"
        return $null
    }
}

function global:Split-VaiCommandLine {
    <#
    .SYNOPSIS
        Rough argv split for simple commands (quotes aware).
    #>
    param([string]$CommandLine)
    $result = [System.Collections.Generic.List[string]]::new()
    $current = [System.Text.StringBuilder]::new()
    $inSingle = $false
    $inDouble = $false
    foreach ($ch in $CommandLine.ToCharArray()) {
        if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle; continue }
        if ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble; continue }
        if ([char]::IsWhiteSpace($ch) -and -not $inSingle -and -not $inDouble) {
            if ($current.Length -gt 0) {
                $result.Add($current.ToString())
                [void]$current.Clear()
            }
            continue
        }
        [void]$current.Append($ch)
    }
    if ($current.Length -gt 0) { $result.Add($current.ToString()) }
    return @($result)
}
