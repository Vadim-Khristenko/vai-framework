# CommandNotFound handler + public commands

function script:Invoke-CNFHandler {
    param([string]$CommandName)

    if ([string]::IsNullOrWhiteSpace($CommandName)) { return }
    if ($CommandName -match '[\\/]') { return }
    if ($script:CNF_Ignore.Contains($CommandName)) { return }
    # PowerShell often probes Get-Foo for unknown Foo
    if ($CommandName -match '^(Get|Set|New|Remove|Test|Invoke|Start|Stop)-[A-Z]') {
        # still allow if user typed it intentionally with capital G — but skip bulk noise
        if ($CommandName -match '^(Get)-(Yq|Codex|Cursor|Aider|Ollama|Gemini|Bun|Uv|Claude|Grok|Opencode)$') {
            return
        }
    }

    $script:CNF_History.Add([PSCustomObject]@{
        Time = Get-Date
        Name = $CommandName
    }) | Out-Null

    Write-VaiLog -Level DEBUG -Message "CNF: $CommandName" -NoConsole

    Write-Host ""
    Write-Host ("  " + (Write-VaiPill "miss" "fail") + "  " +
        $global:Vai.Yellow + $CommandName + $global:Vai.Reset +
        $global:Vai.Gray + "  not found" + $global:Vai.Reset)

    $suggestions = Find-CNFSuggestions -Query $CommandName -Max $script:CNF_MaxSuggestions
    if ($suggestions -and $suggestions.Count -gt 0) {
        Write-Host ("  " + $global:Vai.Cyan + "Did you mean" + $global:Vai.Reset)
        foreach ($s in $suggestions) {
            $kind = if ($s.Distance -le 1) { "ok" } else { "info" }
            Write-Host ("    " + (Write-VaiPill ("d$($s.Distance)") $kind) + "  " +
                $global:Vai.Green + $s.Name + $global:Vai.Reset)
        }
    }

    $hint = Get-CNFInstallHint -CommandName $CommandName
    if ($hint) {
        Write-Host ("  " + (Write-VaiPill "pkg" "hot") + "  " +
            $global:Vai.Gray + "install → " + $global:Vai.Reset + $global:Vai.Yellow + $hint + $global:Vai.Reset)
    }
    elseif ((Test-VaiCommand winget)) {
        Write-Host ("  " + $global:Vai.Gray + "try: winget search " + $CommandName + $global:Vai.Reset)
    }

    $key = $CommandName.ToLower()
    if ($key -like "vai*" -or $key -like "*vai-*") {
        $vaiCommands = @(Get-Command "vai-*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        $vaiSugg = @()
        foreach ($vc in $vaiCommands) {
            $d = Get-CNFLevenshtein -A $CommandName -B $vc
            if ($d -le 5) { $vaiSugg += [PSCustomObject]@{ Name = $vc; Distance = $d } }
        }
        $vaiSugg = $vaiSugg | Sort-Object Distance | Select-Object -First 3
        if ($vaiSugg) {
            Write-Host ("  " + $global:Vai.Magenta + "VAI commands" + $global:Vai.Reset)
            foreach ($v in $vaiSugg) {
                Write-Host ("    → " + $global:Vai.Magenta + $v.Name + $global:Vai.Reset)
            }
        }
    }

    # registry exports tip
    if ($global:Vai -and $global:Vai.M) {
        $mods = @($global:Vai.M.Keys)
        if ($mods.Count -gt 0 -and $key -notlike "vai*") {
            Write-Host ("  " + $global:Vai.Gray + "modules: vai-module list  ·  sex  ·  ai  ·  git:help" + $global:Vai.Reset)
        }
    }
    Write-Host ""
}

function script:Enable-CNF {
    $ExecutionContext.InvokeCommand.CommandNotFoundAction = {
        param($CommandName, $CommandLookupEventArgs)
        if ($CommandName -match '[\\/]') { return }
        Invoke-CNFHandler -CommandName $CommandName
    }
    Write-VaiLog -Level INFO -Message "CommandNotFound: enabled" -NoConsole
}

function script:Disable-CNF {
    $ExecutionContext.InvokeCommand.CommandNotFoundAction = $null
    Write-VaiLog -Level INFO -Message "CommandNotFound: disabled" -NoConsole
}

function script:Invoke-CNFSuggest {
    param([Parameter(Mandatory, Position = 0)] [string]$Command)
    Write-VaiBanner -Title "SUGGEST" -Subtitle $Command -Color Cyan
    $s = Find-CNFSuggestions -Query $Command -Max 10
    if (-not $s) {
        Write-VaiWarn "No close matches."
        return
    }
    foreach ($item in $s) {
        Write-Host ("  " + (Write-VaiPill ("d$($item.Distance)") "info") + "  " +
            $global:Vai.Green + $item.Name + $global:Vai.Reset)
    }
    $hint = Get-CNFInstallHint $Command
    if ($hint) {
        Write-VaiRule
        Write-Host ("  " + (Write-VaiPill "pkg" "hot") + "  " + $hint)
    }
    Write-Host ""
}

function script:Invoke-CNFHistory {
    param([int]$Count = 15)
    Write-VaiBanner -Title "MISS HISTORY" -Subtitle "this session" -Color Yellow
    if ($script:CNF_History.Count -eq 0) {
        Write-VaiWarn "No misses yet. Lucky you."
        return
    }
    $items = @($script:CNF_History | Select-Object -Last $Count)
    foreach ($h in $items) {
        Write-Host ("  " + $global:Vai.Gray + $h.Time.ToString("HH:mm:ss") + $global:Vai.Reset +
            "  " + $global:Vai.Yellow + $h.Name + $global:Vai.Reset)
    }
    Write-Host ("  " + (Write-VaiPill "total $($script:CNF_History.Count)" "dim"))
    Write-Host ""
}

function script:Invoke-CNFMiss {
    # alias for history
    Invoke-CNFHistory @args
}
