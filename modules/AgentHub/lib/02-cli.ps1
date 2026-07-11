# AgentHub CLI — cockpit + install

function script:Show-AgentHelp {
    Write-VaiBanner -Title "AgentHub" -Subtitle "detect · install · launch" -Color Hot
    Write-VaiBox -Title "COMMANDS" -Color Magenta -Lines @(
        "ai                     Dashboard + help",
        "ai list [-Present]     Detect (PATH + bun + npm)",
        "ai which <name>        Resolve binary + source",
        "ai run <name> [...]    Launch agent",
        "ai <name> [...]        Shortcut = run",
        "ai install <name>      Install via bun/npm/uv/manual",
        "ai install <n> -Via bun",
        "ai default [name]      Get/set default agent",
        "ai go [...]            Run default agent",
        "ai doctor              Health + install hints",
        "ai context             Project + package managers",
        "ai history             Recent launches",
        "",
        "Google: antigravity (agy) — Gemini CLI successor (I/O 2026)",
        "API: Invoke-Vai Ai ai install claude"
    )
}

function script:Show-AgentDashboard {
    $prefs = Read-AgentPrefs
    $all = Get-AllAgents
    $on = @($all | Where-Object Present)
    $ctx = Get-AgentContext
    $def = Get-DefaultAgentKey

    Write-VaiBanner -Title "AgentHub" -Subtitle "cockpit online" -Color Hot
    $mgr = @()
    if ($ctx.HasBun) { $mgr += "bun" }
    if ($ctx.HasNpm) { $mgr += "npm" }
    if ($ctx.HasUv)  { $mgr += "uv" }
    Write-Host ("  " +
        (Write-VaiPill ("ready {0}/{1}" -f $on.Count, $all.Count) "ok") + " " +
        (Write-VaiPill ("default " + $(if ($def) { $def } else { "none" })) "hot") + " " +
        (Write-VaiPill ("pm " + $(if ($mgr.Count) { $mgr -join "+" } else { "none" })) "info"))
    Write-VaiRule -Label "present"

    foreach ($a in $all) {
        if (-not $a.Present) { continue }
        $star = if ($a.Key -eq $def) { Write-VaiPill "*" "hot" } else { "   " }
        $via = if ($a.Via) { Write-VaiPill $a.Via "dim" } else { "" }
        Write-Host ("  " + $star + " " + (Write-VaiPill "ON" "ok") + " " + $via + " " +
            $global:Vai.Cyan + $a.Key.PadRight(12) + $global:Vai.Reset +
            $a.Name.PadRight(18) + $global:Vai.Gray + $a.Path + $global:Vai.Reset)
    }

    $off = @($all | Where-Object { -not $_.Present })
    if ($off.Count -gt 0) {
        Write-VaiRule -Label "missing · ai install <name>"
        foreach ($a in $off) {
            Write-Host ("      " + (Write-VaiPill "off" "dim") + " " +
                $global:Vai.Gray + $a.Key.PadRight(12) + $a.Name + $global:Vai.Reset)
            if ($a.Hint) {
                Write-Host ("           " + $global:Vai.Gray + $a.Hint + $global:Vai.Reset)
            }
        }
    }

    Write-VaiRule -Label "context"
    Write-VaiKV "cwd" $ctx.Cwd
    if ($ctx.Root) { Write-VaiKV "root" $ctx.Root }
    if ($ctx.Branch) { Write-VaiKV -Key "branch" -Value $ctx.Branch -ValueColor "Yellow" }
    if ($ctx.Markers.Count -gt 0) {
        Write-VaiKV -Key "stack" -Value ($ctx.Markers -join ", ") -ValueColor "Cyan"
    }
    Write-Host ""
    Write-Host ("  " + $global:Vai.Gray + "ai go  ·  ai install claude  ·  ai install antigravity  ·  ai help" + $global:Vai.Reset)
    Write-Host ""
}

function script:Invoke-AiList {
    param([switch]$Present)
    $agents = Get-AllAgents
    if ($Present) { $agents = @($agents | Where-Object Present) }

    Write-VaiBanner -Title "AGENTS" -Subtitle "PATH · bun · npm" -Color Cyan
    foreach ($a in $agents) {
        if ($a.Present) {
            $via = if ($a.Via) { Write-VaiPill $a.Via "dim" } else { "" }
            Write-Host ("  " + (Write-VaiPill "ON" "ok") + " " + $via + " " +
                $global:Vai.Cyan + $a.Key.PadRight(12) + $global:Vai.Reset +
                $a.Name.PadRight(18) + $global:Vai.Gray + $a.Path + $global:Vai.Reset)
            if ($a.Sources.Count -gt 1) {
                Write-Host ("           " + $global:Vai.Gray + ($a.Sources -join " · ") + $global:Vai.Reset)
            }
        }
        else {
            Write-Host ("  " + (Write-VaiPill "off" "dim") + " " +
                $global:Vai.Gray + $a.Key.PadRight(12) + $a.Name + $global:Vai.Reset)
        }
    }
    $on = @($agents | Where-Object Present).Count
    Write-VaiRule
    Write-Host ("  " + (Write-VaiPill "ready $on / $(@($agents).Count)" "hot"))
    Write-Host ""
}

function script:Invoke-AiWhich {
    param([string]$Name)
    if (-not $Name) {
        Write-VaiWarn "Usage: ai which <claude|grok|antigravity|...>"
        return
    }
    $key = $Name.ToLower()
    if ($key -eq "gemini") { $key = "antigravity" }
    if (-not ($script:AgentCatalog.Keys -contains $key)) {
        Write-VaiError "Unknown agent '$Name'. Try: ai list"
        return
    }
    $a = Resolve-AgentBinary -Key $key
    if ($a.Present) {
        Write-VaiOk "$($a.Key) → $($a.Path)"
        Write-VaiKV "via" $a.Via
        if ($a.Sources.Count) { Write-VaiKV "sources" ($a.Sources -join ", ") }
    }
    else {
        Write-VaiWarn "$($a.Key) missing."
        Write-Host ("  " + $global:Vai.Gray + $a.Hint + $global:Vai.Reset)
        Write-Host ("  " + $global:Vai.Yellow + "ai install $($a.Key)" + $global:Vai.Reset)
    }
}

function script:Invoke-AiRun {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(ValueFromRemainingArguments = $true)]
        $AgentArgs
    )

    $key = $Name.ToLower()
    if ($key -eq "gemini") {
        Write-VaiWarn "Gemini CLI → Antigravity (agy). Redirecting..."
        $key = "antigravity"
    }
    if (-not ($script:AgentCatalog.Keys -contains $key)) {
        Write-VaiError "Unknown agent '$Name'"
        return
    }

    $a = Resolve-AgentBinary -Key $key
    if (-not $a.Present) {
        Write-VaiError "$($a.Name) not installed."
        Write-Host ("  " + $global:Vai.Gray + $a.Hint + $global:Vai.Reset)
        if (Confirm-VaiAction "Install now via ai install?") {
            Install-Agent -Key $key
            $a = Resolve-AgentBinary -Key $key
            if (-not $a.Present) { return }
        }
        else { return }
    }

    $argList = @()
    if ($AgentArgs) { $argList = @($AgentArgs) }
    $ctx = Get-AgentContext

    Write-VaiBanner -Title ("AI · " + $a.Key) -Subtitle $a.Name -Color Hot
    Write-VaiKV "binary" $a.Path
    Write-VaiKV "via" $(if ($a.Via) { $a.Via } else { "?" })
    if ($argList.Count -gt 0) { Write-VaiKV "args" ($argList -join " ") }
    if ($ctx.Root) { Write-VaiKV "project" $ctx.Root }
    if ($ctx.Branch) { Write-VaiKV -Key "branch" -Value $ctx.Branch -ValueColor "Yellow" }
    Write-VaiRule

    $prefs = Read-AgentPrefs
    $prefs.LastAgent = $a.Key
    $prefs.Launches = [int]$prefs.Launches + 1
    Save-AgentPrefs $prefs

    $script:AgentHistory.Add([PSCustomObject]@{
        Time = Get-Date
        Key  = $a.Key
        Args = ($argList -join " ")
        Cwd  = $ctx.Cwd
    }) | Out-Null

    Write-VaiLog -Level INFO -Message ("AgentHub: $($a.Key) via=$($a.Via) $($argList -join ' ')") -NoConsole
    & $a.Path @argList
}

function script:Invoke-AiDefault {
    param([string]$Name)
    $prefs = Read-AgentPrefs
    if (-not $Name) {
        $def = Get-DefaultAgentKey
        if ($def) {
            Write-VaiOk "Default agent: $def"
            if ($prefs.DefaultAgent) { Write-VaiKV "pref" $prefs.DefaultAgent }
        }
        else {
            Write-VaiWarn "No default (no agents installed / no pref)."
        }
        return
    }
    $key = $Name.ToLower()
    if ($key -eq "gemini") { $key = "antigravity" }
    if (-not ($script:AgentCatalog.Keys -contains $key)) {
        Write-VaiError "Unknown agent '$Name'"
        return
    }
    $prefs.DefaultAgent = $key
    Save-AgentPrefs $prefs
    Write-VaiOk "Default agent set to '$key'"
}

function script:Invoke-AiGo {
    param([Parameter(ValueFromRemainingArguments = $true)] $AgentArgs)
    $def = Get-DefaultAgentKey
    if (-not $def) {
        Write-VaiError "No agent available. Try: ai install claude"
        return
    }
    Invoke-AiRun -Name $def -AgentArgs $AgentArgs
}

function script:Invoke-AiDoctor {
    Write-VaiBanner -Title "AI DOCTOR" -Subtitle "PATH · bun · npm · uv" -Color Yellow
    $ctx = Get-AgentContext
    Write-Host ("  " +
        (Write-VaiPill $(if ($ctx.HasBun) { "bun" } else { "no-bun" }) $(if ($ctx.HasBun) { "ok" } else { "dim" })) + " " +
        (Write-VaiPill $(if ($ctx.HasNpm) { "npm" } else { "no-npm" }) $(if ($ctx.HasNpm) { "ok" } else { "dim" })) + " " +
        (Write-VaiPill $(if ($ctx.HasUv) { "uv" } else { "no-uv" }) $(if ($ctx.HasUv) { "ok" } else { "dim" })))
    Write-VaiRule

    $agents = Get-AllAgents
    $on = @($agents | Where-Object Present)
    $off = @($agents | Where-Object { -not $_.Present })
    foreach ($a in $on) {
        Write-Host ("  " + (Write-VaiPill "+" "ok") + " " + (Write-VaiPill $a.Via "dim") + " $($a.Key)  $($a.Path)")
    }
    foreach ($a in $off) {
        Write-Host ("  " + (Write-VaiPill "-" "dim") + " $($a.Key)  " + $global:Vai.Gray + "ai install $($a.Key)" + $global:Vai.Reset)
    }
    Write-Host ""
    $def = Get-DefaultAgentKey
    if ($def) { Write-VaiOk "Default ready: ai go → $def" }
    else { Write-VaiWarn "Install at least one: ai install claude" }
}

function script:Invoke-AiContext {
    $ctx = Get-AgentContext
    Write-VaiBanner -Title "CONTEXT" -Subtitle "where agents land" -Color Cyan
    Write-VaiKV "cwd" $ctx.Cwd
    Write-VaiKV "root" $(if ($ctx.Root) { $ctx.Root } else { "(none)" })
    Write-VaiKV -Key "branch" -Value $(if ($ctx.Branch) { $ctx.Branch } else { "-" }) -ValueColor "Yellow"
    Write-VaiKV "markers" $(if ($ctx.Markers.Count) { $ctx.Markers -join ", " } else { "-" })
    Write-VaiKV "bun" $(if ($ctx.HasBun) { "yes" } else { "no" })
    Write-VaiKV "npm" $(if ($ctx.HasNpm) { "yes" } else { "no" })
    Write-VaiKV "uv"  $(if ($ctx.HasUv)  { "yes" } else { "no" })
    Write-Host ""
}

function script:Invoke-AiHistory {
    Write-VaiBanner -Title "HISTORY" -Subtitle "this session" -Color Blue
    if ($script:AgentHistory.Count -eq 0) {
        Write-VaiWarn "No launches yet."
        return
    }
    $i = 0
    foreach ($h in $script:AgentHistory) {
        $i++
        Write-Host ("  " + (Write-VaiPill $i "info") + " " +
            $global:Vai.Cyan + $h.Key + $global:Vai.Reset + "  " +
            $global:Vai.Gray + $h.Time.ToString("HH:mm:ss") + $global:Vai.Reset + "  " +
            $h.Args)
    }
    Write-Host ""
}

function script:Invoke-AiInstall {
    param(
        [Parameter(Position = 0)]
        [string]$Name,
        [Parameter(ValueFromRemainingArguments = $true)]
        $Rest
    )
    if (-not $Name) {
        Write-VaiWarn "Usage: ai install <claude|codex|antigravity|aider|...> [-Via bun|npm|uv|manual]"
        Write-Host ("  " + $global:Vai.Gray + "Agents: " + ($script:AgentCatalog.Keys -join ", ") + $global:Vai.Reset)
        return
    }
    $via = "auto"
    for ($i = 0; $i -lt @($Rest).Count; $i++) {
        if ($Rest[$i] -in @("-Via", "-via", "--via") -and ($i + 1) -lt $Rest.Count) {
            $via = [string]$Rest[$i + 1]
        }
    }
    Install-Agent -Key $Name -Via $via
}

function script:Invoke-Ai {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Action,
        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    $rest = @()
    if ($RemainingArguments) { $rest = @($RemainingArguments) }

    if (-not $Action) {
        Show-AgentDashboard
        return
    }

    if ($Action -in @("help", "-h", "--help")) {
        Show-AgentHelp
        return
    }

    switch -Regex ($Action) {
        '^(list|ls)$' {
            $present = $rest -contains "-Present" -or $rest -contains "-present"
            Invoke-AiList -Present:$present
            return
        }
        '^(which)$' {
            Invoke-AiWhich -Name $(if ($rest.Count) { $rest[0] } else { $null })
            return
        }
        '^(run)$' {
            if ($rest.Count -lt 1) { Write-VaiWarn "Usage: ai run <agent> [args...]"; return }
            $name = $rest[0]
            $more = @()
            if ($rest.Count -gt 1) { $more = @($rest[1..($rest.Count - 1)]) }
            Invoke-AiRun -Name $name -AgentArgs $more
            return
        }
        '^(install|i|add)$' {
            $name = if ($rest.Count) { $rest[0] } else { $null }
            $more = @()
            if ($rest.Count -gt 1) { $more = @($rest[1..($rest.Count - 1)]) }
            Invoke-AiInstall -Name $name -Rest $more
            return
        }
        '^(default|def)$' {
            Invoke-AiDefault -Name $(if ($rest.Count) { $rest[0] } else { $null })
            return
        }
        '^(go|start)$' {
            Invoke-AiGo -AgentArgs $rest
            return
        }
        '^(doctor|doc)$' { Invoke-AiDoctor; return }
        '^(context|ctx)$' { Invoke-AiContext; return }
        '^(history|hist)$' { Invoke-AiHistory; return }
        default {
            $k = $Action.ToLower()
            if ($k -eq "gemini") { $k = "antigravity" }
            if ($script:AgentCatalog.Keys -contains $k) {
                Invoke-AiRun -Name $k -AgentArgs $rest
                return
            }
            Write-VaiWarn "Unknown: $Action"
            Show-AgentHelp
        }
    }
}
