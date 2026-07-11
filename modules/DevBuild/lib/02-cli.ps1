# DevBuild CLI

function script:Show-DevHelp {
    Write-VaiBanner -Title "DevBuild" -Subtitle "detect · preset · ship" -Color Hot
    Write-VaiBox -Title "COMMANDS" -Color Cyan -Lines @(
        "db                     Dashboard (stacks + tools)",
        "db detect              Show detected stacks in project",
        "db tools               Which build tools are on PATH",
        "db build [-Stack x]    Preset: build",
        "db test  [-Stack x]    Preset: test",
        "db run   [-Stack x]    Preset: run/dev",
        "db clean [-Stack x]    Preset: clean",
        "db fix   [-Stack x]    Preset: fmt/lint",
        "db install [-Stack x]  Preset: install deps",
        "db check [-Stack x]    Preset: typecheck/cargo check",
        "db do <action> [...]   Raw preset action",
        "db exec <tool> [...]   Run tool with args in project root",
        "",
        "Stacks: cargo bun npm pnpm yarn uv poetry go dotnet make cmake",
        "API: Invoke-Vai Db db build"
    )
}

function script:Show-DevDashboard {
    $root = Get-DevProjectRoot
    $stacks = Detect-DevStacks -Root $root

    Write-VaiBanner -Title "DevBuild" -Subtitle $root -Color Hot
    Write-VaiRule -Label "stacks"
    if ($stacks.Count -eq 0) {
        Write-VaiWarn "No known project markers. Try: db tools"
    }
    else {
        foreach ($s in $stacks) {
            $pill = if ($s.Present) { Write-VaiPill "ON" "ok" } else { Write-VaiPill "off" "dim" }
            Write-Host ("  " + $pill + " " + $global:Vai.Cyan + $s.Id.PadRight(10) + $global:Vai.Reset +
                $s.Name.PadRight(22) + $global:Vai.Gray + $s.Marker + $global:Vai.Reset)
        }
    }

    Write-VaiRule -Label "quick"
    Write-Host ("  " + $global:Vai.Gray + "db build · db test · db run · db install · db clean · db fix" + $global:Vai.Reset)
    Write-Host ""
}

function script:Show-DevTools {
    Write-VaiBanner -Title "BUILD TOOLS" -Subtitle "PATH probe" -Color Cyan
    $tools = @(
        "cargo", "rustc", "bun", "node", "npm", "pnpm", "yarn",
        "uv", "python", "poetry", "pip", "go", "dotnet", "make", "cmake",
        "gcc", "clang", "mvn", "gradle", "docker"
    )
    $on = 0
    foreach ($t in $tools) {
        $p = Get-VaiTool $t
        if ($p) {
            $on++
            Write-Host ("  " + (Write-VaiPill "ON" "ok") + " " + $global:Vai.Cyan + $t.PadRight(10) + $global:Vai.Reset + $global:Vai.Gray + $p + $global:Vai.Reset)
        }
        else {
            Write-Host ("  " + (Write-VaiPill "off" "dim") + " " + $global:Vai.Gray + $t + $global:Vai.Reset)
        }
    }
    Write-VaiRule
    Write-Host ("  " + (Write-VaiPill "ready $on / $($tools.Count)" "hot"))
    Write-Host ""
}

function script:Invoke-DevPreset {
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [string]$Stack,

        [Parameter(ValueFromRemainingArguments = $true)]
        $ExtraArgs
    )

    $root = Get-DevProjectRoot
    $stackObj = Resolve-DevStack -Root $root -Prefer $Stack
    if (-not $stackObj) {
        Write-VaiError "No stack detected in $root. Use: db build -Stack cargo"
        return
    }

    $map = Get-DevPresetMap
    if (-not $map.ContainsKey($Action)) {
        Write-VaiError "Unknown action '$Action'. Try: build test run clean fix install check"
        return
    }
    $actionMap = $map[$Action]
    if (-not $actionMap.ContainsKey($stackObj.Id)) {
        Write-VaiError "No '$Action' preset for stack '$($stackObj.Id)'."
        Write-Host ("  " + $global:Vai.Gray + "Known for ${Action}: $($actionMap.Keys -join ', ')" + $global:Vai.Reset)
        return
    }

    $argv = @($actionMap[$stackObj.Id])
    if ($ExtraArgs) { $argv += @($ExtraArgs) }

    $tool = $argv[0]
    $toolPath = Get-VaiTool $tool
    if (-not $toolPath) {
        Write-VaiError "Tool not on PATH: $tool  (stack: $($stackObj.Name))"
        return
    }

    $rest = @()
    if ($argv.Count -gt 1) { $rest = @($argv[1..($argv.Count - 1)]) }

    Write-VaiBanner -Title ("DB · " + $Action.ToUpper()) -Subtitle ("{0} @ {1}" -f $stackObj.Id, $root) -Color Green
    Write-VaiKV "stack" $stackObj.Name
    Write-VaiKV "cmd" ($toolPath + " " + ($rest -join " "))
    Write-VaiRule

    $old = Get-Location
    try {
        Set-Location -LiteralPath $root
        Write-VaiLog -Level INFO -Message ("DevBuild: $Action $($stackObj.Id) $($rest -join ' ')") -NoConsole
        & $toolPath @rest
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        if ($code -eq 0) {
            Write-VaiOk "$Action OK ($($stackObj.Id))"
        }
        else {
            Write-VaiError "$Action failed (exit $code)"
        }
    }
    finally {
        Set-Location $old
    }
}

function script:Invoke-DevExec {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Tool,
        [Parameter(ValueFromRemainingArguments = $true)]
        $ToolArgs
    )
    $root = Get-DevProjectRoot
    $path = Get-VaiTool $Tool
    if (-not $path) { Write-VaiError "Not found: $Tool"; return }
    $argv = @()
    if ($ToolArgs) { $argv = @($ToolArgs) }
    Write-VaiBanner -Title "DB EXEC" -Subtitle $Tool -Color Cyan
    Write-VaiKV "cwd" $root
    Write-VaiKV "cmd" ($path + " " + ($argv -join " "))
    Write-VaiRule
    $old = Get-Location
    try {
        Set-Location -LiteralPath $root
        & $path @argv
    }
    finally { Set-Location $old }
}

function script:Invoke-Db {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Action,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    $rest = @()
    if ($RemainingArguments) { $rest = @($RemainingArguments) }

    # parse -Stack X from remaining
    $stack = $null
    $filtered = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $rest.Count; $i++) {
        if ($rest[$i] -in @("-Stack", "-stack", "--stack") -and ($i + 1) -lt $rest.Count) {
            $stack = [string]$rest[$i + 1]
            $i++
            continue
        }
        $filtered.Add([string]$rest[$i])
    }
    $rest = @($filtered)

    if (-not $Action -or $Action -in @("help", "-h", "--help")) {
        if (-not $Action) { Show-DevDashboard; return }
        Show-DevHelp
        return
    }

    switch -Regex ($Action) {
        '^(detect|stacks)$' {
            $root = Get-DevProjectRoot
            Write-VaiBanner -Title "DETECT" -Subtitle $root -Color Cyan
            $stacks = Detect-DevStacks -Root $root
            if ($stacks.Count -eq 0) { Write-VaiWarn "Nothing detected." }
            foreach ($s in $stacks) {
                $pill = if ($s.Present) { Write-VaiPill "ON" "ok" } else { Write-VaiPill "off" "fail" }
                Write-Host ("  " + $pill + " " + $s.Id.PadRight(10) + $s.Name + "  " + $global:Vai.Gray + $s.Marker + $global:Vai.Reset)
            }
            Write-Host ""
            return
        }
        '^(tools|which)$' { Show-DevTools; return }
        '^(build|test|run|clean|fix|install|check)$' {
            Invoke-DevPreset -Action $Action -Stack $stack -ExtraArgs $rest
            return
        }
        '^(do)$' {
            if ($rest.Count -lt 1) { Write-VaiWarn "Usage: db do <action> [-Stack x]"; return }
            $act = $rest[0]
            $more = @()
            if ($rest.Count -gt 1) { $more = @($rest[1..($rest.Count - 1)]) }
            Invoke-DevPreset -Action $act -Stack $stack -ExtraArgs $more
            return
        }
        '^(exec|x)$' {
            if ($rest.Count -lt 1) { Write-VaiWarn "Usage: db exec <tool> [args...]"; return }
            $tool = $rest[0]
            $more = @()
            if ($rest.Count -gt 1) { $more = @($rest[1..($rest.Count - 1)]) }
            Invoke-DevExec -Tool $tool -ToolArgs $more
            return
        }
        default {
            Write-VaiWarn "Unknown: $Action"
            Show-DevHelp
        }
    }
}
