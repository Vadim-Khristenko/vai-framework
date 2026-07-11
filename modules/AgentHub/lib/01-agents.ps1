# Agent catalog + multi-source detection (PATH / bun / npm) + install

$script:AgentCatalog = [ordered]@{
    claude = @{
        Name = "Claude Code"
        Binaries = @("claude")
        Desc = "Anthropic Claude Code"
        Tags = @("code", "chat", "default-candidate")
        Install = @{
            Preferred = "native"
            # official installer scripts preferred; npm/bun fallbacks
            NativeWin = 'irm https://claude.ai/install.ps1 | iex'
            NativeUnix = 'curl -fsSL https://claude.ai/install.sh | bash'
            Npm = "@anthropic-ai/claude-code"
            Bun = "@anthropic-ai/claude-code"
            Hint = "npm i -g @anthropic-ai/claude-code  |  bun add -g @anthropic-ai/claude-code"
        }
    }
    grok = @{
        Name = "Grok Build"
        Binaries = @("grok", "grok-build")
        Desc = "xAI Grok Build TUI"
        Tags = @("code", "tui", "default-candidate")
        Install = @{
            Preferred = "manual"
            Hint = "Install Grok Build from xAI / https://grok.x.ai"
        }
    }
    codex = @{
        Name = "OpenAI Codex"
        Binaries = @("codex")
        Desc = "OpenAI Codex CLI"
        Tags = @("code")
        Install = @{
            Preferred = "npm"
            Npm = "@openai/codex"
            Bun = "@openai/codex"
            Hint = "npm i -g @openai/codex  |  bun add -g @openai/codex"
        }
    }
    opencode = @{
        Name = "OpenCode"
        Binaries = @("opencode")
        Desc = "OpenCode agent CLI"
        Tags = @("code")
        Install = @{
            Preferred = "npm"
            Npm = "opencode-ai"
            Bun = "opencode-ai"
            Hint = "npm i -g opencode-ai  |  bun add -g opencode-ai  |  see opencode.ai"
        }
    }
    cursor = @{
        Name = "Cursor"
        Binaries = @("cursor", "cursor-agent")
        Desc = "Cursor editor / agent"
        Tags = @("ide")
        Install = @{
            Preferred = "manual"
            Hint = "Install Cursor IDE from https://cursor.com"
        }
    }
    aider = @{
        Name = "Aider"
        Binaries = @("aider")
        Desc = "Aider pair-programming"
        Tags = @("code", "git")
        Install = @{
            Preferred = "uv"
            Uv = "aider-chat"
            Pip = "aider-chat"
            Hint = "uv tool install aider-chat  |  pip install aider-chat"
        }
    }
    continue = @{
        Name = "Continue"
        Binaries = @("cn", "continue")
        Desc = "Continue.dev CLI"
        Tags = @("ide")
        Install = @{
            Preferred = "manual"
            Hint = "https://continue.dev"
        }
    }
    # Google: Gemini CLI → Antigravity CLI (agy) as of I/O 2026
    antigravity = @{
        Name = "Antigravity CLI"
        Binaries = @("agy", "antigravity", "antigravity-cli")
        Desc = "Google Antigravity CLI (successor to Gemini CLI)"
        Tags = @("code", "chat", "google")
        Install = @{
            Preferred = "manual"
            Hint = "https://antigravity.google/download  ·  migrates from Gemini CLI (deprecated Jun 2026)"
            Url = "https://antigravity.google/download"
        }
    }
    ollama = @{
        Name = "Ollama"
        Binaries = @("ollama")
        Desc = "Local models via Ollama"
        Tags = @("local")
        Install = @{
            Preferred = "manual"
            Hint = "https://ollama.com/download"
            Url = "https://ollama.com/download"
        }
    }
}

$script:AgentHistory = [System.Collections.Generic.List[object]]::new()
$script:AgentPrefsPath = Join-Path (Get-VaiConfigDir) "agenthub.json"
$script:BunGlobalCache = $null
$script:NpmGlobalCache = $null

function script:Read-AgentPrefs {
    $defaults = @{ DefaultAgent = ""; LastAgent = ""; Launches = 0 }
    if (-not (Test-Path -LiteralPath $script:AgentPrefsPath)) { return $defaults }
    $j = Read-VaiJson $script:AgentPrefsPath
    if (-not $j) { return $defaults }
    return @{
        DefaultAgent = [string](Get-VaiValue $j "DefaultAgent" "")
        LastAgent    = [string](Get-VaiValue $j "LastAgent" "")
        Launches     = [int](Get-VaiValue $j "Launches" 0)
    }
}

function script:Save-AgentPrefs {
    param([hashtable]$Prefs)
    $dir = Split-Path -Parent $script:AgentPrefsPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $obj = [ordered]@{
        DefaultAgent = $Prefs.DefaultAgent
        LastAgent    = $Prefs.LastAgent
        Launches     = $Prefs.Launches
        Updated      = (Get-Date).ToString("o")
    }
    Write-VaiFile -Path $script:AgentPrefsPath -Content ($obj | ConvertTo-Json) -Bom
}

function script:Get-BunGlobalBins {
    if ($null -ne $script:BunGlobalCache) { return $script:BunGlobalCache }
    $map = @{}
    if (-not (Test-VaiCommand bun)) {
        $script:BunGlobalCache = $map
        return $map
    }
    $prev = $ExecutionContext.InvokeCommand.CommandNotFoundAction
    try {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $null
        # bun pm ls -g --all  (versions vary)
        $out = & bun pm ls -g 2>$null
        if (-not $out) { $out = & bun pm ls --global 2>$null }
        foreach ($line in @($out)) {
            $s = [string]$line
            # package@version or tree lines
            if ($s -match '(@?[\w./-]+)@[\d.]+') {
                $pkg = $matches[1]
                $map[$pkg.ToLower()] = $s.Trim()
                $short = ($pkg -split '/')[-1]
                $map[$short.ToLower()] = $s.Trim()
            }
            elseif ($s -match '([\w@./-]+)\s+([\d.]+)') {
                $pkg = $matches[1]
                $map[$pkg.ToLower()] = $s.Trim()
            }
        }
        # also probe bun bin -g path
        $binDir = & bun pm bin -g 2>$null
        if ($binDir -and (Test-Path -LiteralPath $binDir.Trim())) {
            Get-ChildItem -LiteralPath $binDir.Trim() -File -ErrorAction SilentlyContinue | ForEach-Object {
                $n = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                if ($n) { $map["bin:$($n.ToLower())"] = $_.FullName }
            }
        }
    }
    catch { }
    finally {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $prev
    }
    $script:BunGlobalCache = $map
    return $map
}

function script:Get-NpmGlobalBins {
    if ($null -ne $script:NpmGlobalCache) { return $script:NpmGlobalCache }
    $map = @{}
    if (-not (Test-VaiCommand npm)) {
        $script:NpmGlobalCache = $map
        return $map
    }
    $prev = $ExecutionContext.InvokeCommand.CommandNotFoundAction
    try {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $null
        $root = & npm root -g 2>$null
        if ($root) {
            $root = $root.Trim()
            if (Test-Path $root) {
                Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    $map[$_.Name.ToLower()] = $_.FullName
                }
            }
        }
        $binDir = & npm bin -g 2>$null
        if ($binDir) {
            $binDir = $binDir.Trim()
            if (Test-Path $binDir) {
                Get-ChildItem -LiteralPath $binDir -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $n = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    if ($n) { $map["bin:$($n.ToLower())"] = $_.FullName }
                }
            }
        }
    }
    catch { }
    finally {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $prev
    }
    $script:NpmGlobalCache = $map
    return $map
}

function script:Resolve-AgentBinary {
    param([string]$Key)

    $entry = $script:AgentCatalog[$Key]
    if (-not $entry) { return $null }

    $sources = [System.Collections.Generic.List[string]]::new()
    $path = $null
    $binary = $entry.Binaries[0]
    $via = $null

    # 1) PATH
    foreach ($b in $entry.Binaries) {
        $tool = Get-VaiTool -Name $b
        if ($tool) {
            $path = $tool
            $binary = $b
            $via = "path"
            $sources.Add("path:$tool")
            break
        }
    }

    # 2) bun global bins
    $bun = Get-BunGlobalBins
    foreach ($b in $entry.Binaries) {
        $bk = "bin:$($b.ToLower())"
        if ($bun.ContainsKey($bk)) {
            $sources.Add("bun:$($bun[$bk])")
            if (-not $path) {
                $path = $bun[$bk]
                $binary = $b
                $via = "bun"
            }
        }
    }
    if ($entry.Install -and $entry.Install.Bun) {
        $pkg = [string]$entry.Install.Bun
        if ($bun.ContainsKey($pkg.ToLower()) -or $bun.ContainsKey(($pkg -split '/')[-1].ToLower())) {
            $sources.Add("bun-pkg:$pkg")
            if (-not $path -and $bun.ContainsKey("bin:$($entry.Binaries[0].ToLower())")) {
                $path = $bun["bin:$($entry.Binaries[0].ToLower())"]
                $via = "bun"
            }
        }
    }

    # 3) npm global bins
    $npm = Get-NpmGlobalBins
    foreach ($b in $entry.Binaries) {
        $bk = "bin:$($b.ToLower())"
        if ($npm.ContainsKey($bk)) {
            $sources.Add("npm:$($npm[$bk])")
            if (-not $path) {
                $path = $npm[$bk]
                $binary = $b
                $via = "npm"
            }
        }
    }

    $hint = if ($entry.Install -and $entry.Install.Hint) { $entry.Install.Hint } else { "" }

    return [PSCustomObject]@{
        Key     = $Key
        Name    = $entry.Name
        Binary  = $binary
        Path    = $path
        Desc    = $entry.Desc
        Present = [bool]$path
        Via     = $via
        Sources = @($sources)
        Tags    = @($entry.Tags)
        Hint    = $hint
        Install = $entry.Install
    }
}

function script:Get-AllAgents {
    # refresh package caches each full scan
    $script:BunGlobalCache = $null
    $script:NpmGlobalCache = $null
    $list = @()
    foreach ($k in $script:AgentCatalog.Keys) {
        $list += ,(Resolve-AgentBinary -Key $k)
    }
    return $list
}

function script:Get-AgentContext {
    $cwd = (Get-Location).Path
    $root = Find-VaiProjectRoot -StartPath $cwd
    $branch = $null
    if ($root -and (Test-Path (Join-Path $root ".git"))) {
        if (Test-VaiCommand git) {
            $branch = (& git -C $root rev-parse --abbrev-ref HEAD 2>$null)
        }
    }
    $markers = @()
    if ($root) {
        foreach ($m in @("package.json", "Cargo.toml", "pyproject.toml", "go.mod", "sex.yaml", "bun.lockb", "bun.lock")) {
            if (Test-Path (Join-Path $root $m)) { $markers += $m }
        }
    }
    return [PSCustomObject]@{
        Cwd     = $cwd
        Root    = $root
        Branch  = $branch
        Markers = $markers
        HasBun  = (Test-VaiCommand bun)
        HasNpm  = (Test-VaiCommand npm)
        HasUv   = (Test-VaiCommand uv)
    }
}

function script:Get-DefaultAgentKey {
    $prefs = Read-AgentPrefs
    if ($prefs.DefaultAgent -and ($script:AgentCatalog.Keys -contains $prefs.DefaultAgent.ToLower())) {
        $a = Resolve-AgentBinary $prefs.DefaultAgent.ToLower()
        if ($a.Present) { return $a.Key }
    }
    $all = Get-AllAgents
    $cand = $all | Where-Object { $_.Present -and ($_.Tags -contains "default-candidate") } | Select-Object -First 1
    if ($cand) { return $cand.Key }
    $any = $all | Where-Object Present | Select-Object -First 1
    if ($any) { return $any.Key }
    return $null
}

function script:Install-Agent {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [ValidateSet("auto", "bun", "npm", "uv", "pip", "manual")]
        [string]$Via = "auto"
    )

    $key = $Key.ToLower()
    if ($key -eq "gemini") {
        Write-VaiWarn "Gemini CLI is deprecated → use Antigravity CLI (agy)."
        $key = "antigravity"
    }
    if (-not ($script:AgentCatalog.Keys -contains $key)) {
        Write-VaiError "Unknown agent '$Key'. Try: ai list"
        return
    }

    $entry = $script:AgentCatalog[$key]
    $inst = $entry.Install
    if (-not $inst) {
        Write-VaiError "No install recipe for $key"
        return
    }

    Write-VaiBanner -Title "AI INSTALL" -Subtitle $entry.Name -Color Hot
    Write-VaiKV "agent" $key
    Write-VaiKV "hint" $(if ($inst.Hint) { $inst.Hint } else { "-" })

    # already present?
    $resolved = Resolve-AgentBinary $key
    if ($resolved.Present) {
        Write-VaiOk "Already installed via $($resolved.Via): $($resolved.Path)"
        return
    }

    $method = $Via
    if ($method -eq "auto") {
        $method = if ($inst.Preferred) { $inst.Preferred } else { "npm" }
        # smart auto: prefer bun if available and Bun package exists
        if ($method -eq "npm" -and $inst.Bun -and (Test-VaiCommand bun)) { $method = "bun" }
        if ($method -eq "npm" -and -not (Test-VaiCommand npm) -and $inst.Bun -and (Test-VaiCommand bun)) { $method = "bun" }
        if ($method -eq "uv" -and -not (Test-VaiCommand uv) -and $inst.Pip -and (Test-VaiCommand pip)) { $method = "pip" }
    }

    Write-VaiKV "method" $method
    Write-VaiRule

    switch ($method) {
        "bun" {
            if (-not $inst.Bun) { Write-VaiError "No bun package for $key"; return }
            if (-not (Test-VaiCommand bun)) { Write-VaiError "bun not on PATH"; return }
            Write-Host ("  " + (Write-VaiPill "bun" "hot") + " bun add -g $($inst.Bun)")
            & bun add -g $inst.Bun
        }
        "npm" {
            if (-not $inst.Npm) { Write-VaiError "No npm package for $key"; return }
            if (-not (Test-VaiCommand npm)) { Write-VaiError "npm not on PATH"; return }
            Write-Host ("  " + (Write-VaiPill "npm" "info") + " npm i -g $($inst.Npm)")
            & npm install -g $inst.Npm
        }
        "uv" {
            if (-not $inst.Uv) { Write-VaiError "No uv package for $key"; return }
            if (-not (Test-VaiCommand uv)) { Write-VaiError "uv not on PATH"; return }
            Write-Host ("  " + (Write-VaiPill "uv" "ok") + " uv tool install $($inst.Uv)")
            & uv tool install $inst.Uv
        }
        "pip" {
            if (-not $inst.Pip) { Write-VaiError "No pip package for $key"; return }
            $py = if (Test-VaiCommand pip) { "pip" } elseif (Test-VaiCommand pip3) { "pip3" } else { $null }
            if (-not $py) { Write-VaiError "pip not on PATH"; return }
            & $py install $inst.Pip
        }
        "native" {
            if ($global:Vai.IsWindows -and $inst.NativeWin) {
                Write-VaiWarn "Running native Windows installer (review URL first)."
                if (-not (Confirm-VaiAction "Run native install for $key?")) { return }
                Invoke-Expression $inst.NativeWin
            }
            elseif (-not $global:Vai.IsWindows -and $inst.NativeUnix) {
                Write-VaiWarn "Running native Unix installer."
                if (-not (Confirm-VaiAction "Run native install for $key?")) { return }
                bash -lc $inst.NativeUnix
            }
            else {
                Write-VaiWarn "No native installer script; open manual page."
                if ($inst.Url) { Open-VaiUrl $inst.Url }
                else { Write-Host ("  " + $inst.Hint) }
            }
        }
        default {
            Write-VaiWarn "Manual install required."
            if ($inst.Url) {
                Write-VaiKV "url" $inst.Url
                if (Confirm-VaiAction "Open download page?" -DefaultYes) { Open-VaiUrl $inst.Url }
            }
            Write-Host ("  " + $global:Vai.Yellow + $inst.Hint + $global:Vai.Reset)
        }
    }

    # invalidate caches and re-check
    $script:BunGlobalCache = $null
    $script:NpmGlobalCache = $null
    $again = Resolve-AgentBinary $key
    if ($again.Present) {
        Write-VaiOk "Installed: $($again.Path) (via $($again.Via))"
    }
    else {
        Write-VaiWarn "Install finished but binary not on PATH yet — restart shell or check PATH."
        if ($inst.Hint) { Write-Host ("  " + $global:Vai.Gray + $inst.Hint + $global:Vai.Reset) }
    }
}
