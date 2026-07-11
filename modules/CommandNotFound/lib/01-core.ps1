# CommandNotFound core — distance, candidates, packages

$script:CNF_Settings = $null
$cfgPath = if ($global:VaiModule -and $global:VaiModule.ConfigPath) {
    $global:VaiModule.ConfigPath
} else {
    Join-Path (Split-Path -Parent $PSScriptRoot) "config.json"
}
if (Test-Path $cfgPath) {
    try { $script:CNF_Settings = (Read-VaiJson $cfgPath).Settings } catch {}
}

$script:CNF_MaxDistance = 3
$script:CNF_MaxSuggestions = 5
if ($script:CNF_Settings) {
    if (Test-VaiProperty $script:CNF_Settings "MaxSuggestionDistance") {
        $script:CNF_MaxDistance = [int]$script:CNF_Settings.MaxSuggestionDistance
    }
    if (Test-VaiProperty $script:CNF_Settings "MaxSuggestions") {
        $script:CNF_MaxSuggestions = [int]$script:CNF_Settings.MaxSuggestions
    }
}

$script:CNF_CandidateCache = $null
$script:CNF_History = [System.Collections.Generic.List[object]]::new()
$script:CNF_Ignore = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

# noise from completion engines / internal probes
foreach ($x in @("Get-Yq", "get-yq", "Get-Codex", "get-codex", "Get-Cursor", "get-cursor",
        "Get-Aider", "get-aider", "Get-Ollama", "get-ollama", "Get-Gemini", "get-gemini")) {
    [void]$script:CNF_Ignore.Add($x)
}

$script:CNF_KnownPackages = @{
    "git"      = @{ winget = "Git.Git"; scoop = "git"; brew = "git"; apt = "git" }
    "docker"   = @{ winget = "Docker.DockerDesktop"; brew = "docker"; apt = "docker.io" }
    "node"     = @{ winget = "OpenJS.NodeJS"; scoop = "nodejs"; brew = "node"; apt = "nodejs" }
    "npm"      = @{ winget = "OpenJS.NodeJS"; scoop = "nodejs"; brew = "node" }
    "python"   = @{ winget = "Python.Python.3.12"; scoop = "python"; brew = "python"; apt = "python3" }
    "pip"      = @{ winget = "Python.Python.3.12"; brew = "python"; apt = "python3-pip" }
    "cargo"    = @{ winget = "Rustlang.Rustup"; brew = "rust"; apt = "cargo" }
    "rustc"    = @{ winget = "Rustlang.Rustup"; brew = "rust" }
    "code"     = @{ winget = "Microsoft.VisualStudioCode"; brew = "visual-studio-code" }
    "gh"       = @{ winget = "GitHub.cli"; brew = "gh"; apt = "gh" }
    "kubectl"  = @{ winget = "Kubernetes.kubectl"; brew = "kubernetes-cli" }
    "ffmpeg"   = @{ winget = "Gyan.FFmpeg"; brew = "ffmpeg"; apt = "ffmpeg" }
    "rg"       = @{ winget = "BurntSushi.ripgrep.MSVC"; brew = "ripgrep"; apt = "ripgrep" }
    "fzf"      = @{ winget = "junegunn.fzf"; brew = "fzf"; apt = "fzf" }
    "jq"       = @{ winget = "jqlang.jq"; brew = "jq"; apt = "jq" }
    "nvim"     = @{ winget = "Neovim.Neovim"; brew = "neovim"; apt = "neovim" }
    "bun"      = @{ scoop = "bun"; brew = "bun" }
    "uv"       = @{ scoop = "uv"; brew = "uv" }
    "claude"   = @{ npm = "@anthropic-ai/claude-code" }
    "grok"     = @{}
    "codex"    = @{ npm = "@openai/codex" }
    "opencode" = @{}
    "yq"       = @{ winget = "MikeFarah.yq"; scoop = "yq"; brew = "yq" }
    "make"     = @{ winget = "GnuWin32.Make"; scoop = "make"; brew = "make"; apt = "make" }
    "cmake"    = @{ winget = "Kitware.CMake"; brew = "cmake"; apt = "cmake" }
    "wget"     = @{ winget = "JernejSimoncic.Wget"; brew = "wget"; apt = "wget" }
    "curl"     = @{ winget = "cURL.cURL"; brew = "curl"; apt = "curl" }
}

function script:Get-CNFLevenshtein {
    param([string]$A, [string]$B)
    $A = $A.ToLower(); $B = $B.ToLower()
    $la = $A.Length; $lb = $B.Length
    if ($la -eq 0) { return $lb }
    if ($lb -eq 0) { return $la }
    if ([Math]::Abs($la - $lb) -gt $script:CNF_MaxDistance) { return 99 }

    $prev = New-Object int[] ($lb + 1)
    $curr = New-Object int[] ($lb + 1)
    for ($j = 0; $j -le $lb; $j++) { $prev[$j] = $j }

    for ($i = 1; $i -le $la; $i++) {
        $curr[0] = $i
        for ($j = 1; $j -le $lb; $j++) {
            $cost = if ($A[$i - 1] -eq $B[$j - 1]) { 0 } else { 1 }
            $curr[$j] = [Math]::Min([Math]::Min($prev[$j] + 1, $curr[$j - 1] + 1), $prev[$j - 1] + $cost)
        }
        $tmp = $prev; $prev = $curr; $curr = $tmp
    }
    return $prev[$lb]
}

function script:Get-CNFCandidates {
    if ($script:CNF_CandidateCache) { return $script:CNF_CandidateCache }
    $prev = $ExecutionContext.InvokeCommand.CommandNotFoundAction
    try {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $null
        $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        Get-Command -CommandType Cmdlet, Function, Alias, Application -ErrorAction SilentlyContinue |
            ForEach-Object { [void]$names.Add($_.Name) }
        # also short names without extension on Windows
        Get-Command -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object {
            $bn = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            if ($bn) { [void]$names.Add($bn) }
        }
        $script:CNF_CandidateCache = @($names)
    }
    finally {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $prev
    }
    return $script:CNF_CandidateCache
}

function script:Find-CNFSuggestions {
    param([string]$Query, [int]$Max = 5)
    $results = [System.Collections.Generic.List[object]]::new()
    $q = $Query.ToLower()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    # Seed with known package names + registry exports (high value)
    $seeds = [System.Collections.Generic.List[string]]::new()
    foreach ($k in $script:CNF_KnownPackages.Keys) { $seeds.Add($k) }
    if ($global:Vai -and $global:Vai.M) {
        foreach ($mod in $global:Vai.M.Keys) {
            foreach ($ex in @($global:Vai.M[$mod].Keys)) {
                $seeds.Add([string]$ex)
                $seeds.Add(("{0}:{1}" -f $mod.ToLower(), $ex))
            }
        }
    }
    foreach ($c in (Get-CNFCandidates)) { $seeds.Add($c) }

    foreach ($cand in $seeds) {
        if (-not $cand -or -not $seen.Add($cand)) { continue }
        if ([Math]::Abs($cand.Length - $Query.Length) -gt ($script:CNF_MaxDistance + 1)) { continue }
        $d = Get-CNFLevenshtein -A $Query -B $cand
        if ($d -gt $script:CNF_MaxDistance) { continue }

        $bonus = 0.0
        $cl = $cand.ToLower()
        if ($cl -eq $q) { $bonus = -10 }
        elseif ($script:CNF_KnownPackages.ContainsKey($cl)) { $bonus -= 3.0 }
        elseif ($cl.StartsWith($q) -or $q.StartsWith($cl)) { $bonus -= 1.0 }
        elseif ($q.Length -ge 2 -and $cl.StartsWith($q.Substring(0, 2))) { $bonus -= 0.5 }
        # demote cryptic 2–3 letter aliases that aren't known tools
        if ($cand.Length -le 3 -and -not $script:CNF_KnownPackages.ContainsKey($cl) -and $cand -notmatch '^(gs|gd|gb|gco)$') {
            $bonus += 1.2
        }

        $results.Add([PSCustomObject]@{ Name = $cand; Distance = $d; Score = $d + $bonus })
    }
    return @($results | Sort-Object Score, Distance, { $_.Name.Length } | Select-Object -First $Max)
}

function script:Get-CNFInstallHint {
    param([string]$CommandName)
    $key = $CommandName.ToLower()
    if (-not $script:CNF_KnownPackages.ContainsKey($key)) { return $null }
    $pkg = $script:CNF_KnownPackages[$key]

    if ($pkg.npm -and (Test-VaiCommand npm)) {
        return "npm i -g $($pkg.npm)"
    }
    if ($global:Vai.IsWindows) {
        if ((Test-VaiCommand winget) -and $pkg.winget) { return "winget install --id $($pkg.winget)" }
        if ((Test-VaiCommand scoop) -and $pkg.scoop) { return "scoop install $($pkg.scoop)" }
        if (Test-VaiCommand choco) { return "choco install $key" }
    }
    elseif ($global:Vai.IsMacOS) {
        if ((Test-VaiCommand brew) -and $pkg.brew) { return "brew install $($pkg.brew)" }
    }
    else {
        if ((Test-VaiCommand brew) -and $pkg.brew) { return "brew install $($pkg.brew)" }
        if ((Test-VaiCommand apt) -and $pkg.apt) { return "sudo apt install $($pkg.apt)" }
        if (Test-VaiCommand pacman) { return "sudo pacman -S $key" }
    }
    return $null
}
