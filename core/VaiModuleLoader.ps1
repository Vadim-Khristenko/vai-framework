# ==============================================================================
# VAI-FRAMEWORK v5 :: Manifest scan, topo sort, load, lazy stubs
# ==============================================================================

function script:Get-VaiRegistryKeyFromManifest {
    param($Meta, [string]$Prefix, [string]$Name)

    $explicit = Get-VaiValue $Meta "RegistryKey" $null
    if ($explicit) { return [string]$explicit }

    if ($Prefix) {
        # git → Git, net → Net, sex → Sex
        if ($Prefix.Length -eq 1) { return $Prefix.ToUpper() }
        return ($Prefix.Substring(0, 1).ToUpper() + $Prefix.Substring(1).ToLower())
    }

    return $Name
}

function Read-VaiModuleManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]$Directory
    )

    $configFile = Join-Path $Directory.FullName "config.json"
    $scriptFile = Join-Path $Directory.FullName "module.ps1"

    if (-not (Test-Path $configFile) -or -not (Test-Path $scriptFile)) {
        return $null
    }

    $json = Read-VaiJson -Path $configFile
    if ($null -eq $json) {
        Write-VaiLog -Level WARN -Message ("Empty/unreadable config.json: " + $Directory.Name)
        return $null
    }

    $meta     = Get-VaiValue $json "Meta"     ([PSCustomObject]@{})
    $settings = Get-VaiValue $json "Settings" ([PSCustomObject]@{})

    $name   = Get-VaiValue $meta "Name" $Directory.Name
    $prefix = Get-VaiValue $meta "Prefix" $null
    if (-not $prefix) {
        # heuristic fallback from name
        $prefix = ($name -replace 'Tweaks$', '' -replace '^vai-', '').ToLower()
        if (-not $prefix) { $prefix = $name.ToLower() }
    }

    $registryKey = Get-VaiRegistryKeyFromManifest -Meta $meta -Prefix $prefix -Name $name

    $exports = @()
    $exRaw = Get-VaiValue $settings "Exports" @()
    if ($exRaw) { $exports = @($exRaw | ForEach-Object { [string]$_ }) }

    $changelogFile = Join-Path $Directory.FullName "changelog.json"
    $latestEntry   = $null
    $clPath        = $null

    if (Test-Path $changelogFile) {
        $clPath = $changelogFile
        try {
            $clData  = Read-VaiJson -Path $changelogFile
            $entries = Get-VaiChangelogEntries $clData
            if ($entries.Count -gt 0) { $latestEntry = $entries[0] }
        }
        catch {
            Write-VaiLog -Level WARN -Message ("Bad changelog.json in '" + $Directory.Name + "': " + $_.Exception.Message)
        }
    }

    $shortAliases = Get-VaiValue $settings "ShortAliases" $true

    return [PSCustomObject]@{
        Name          = $name
        Prefix        = $prefix
        RegistryKey   = $registryKey
        Version       = Get-VaiValue $meta "Version" "0.0.0"
        Author        = Get-VaiValue $meta "Author" "unknown"
        Description   = Get-VaiValue $meta "Description" ""
        Enabled       = [bool](Get-VaiValue $settings "EnableModule" $false)
        LazyLoad      = [bool](Get-VaiValue $settings "LazyLoad" $false)
        DependsOn     = @(Get-VaiValue $settings "DependsOn" @())
        LoadPriority  = [int](Get-VaiValue $settings "LoadPriority" 100)
        LazyTriggers  = @(Get-VaiValue $settings "LazyTriggers" @())
        Exports       = $exports
        ShortAliases  = [bool]$shortAliases
        ConfigPath    = $configFile
        ScriptPath    = $scriptFile
        ChangelogPath = $clPath
        LatestChange  = $latestEntry
        LoadTimeMs    = 0
        Status        = "Pending"
    }
}

function Get-VaiLoadOrder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$ManifestMap
    )

    $names    = @($ManifestMap.Keys)
    $inDegree = @{}
    $adj      = @{}

    foreach ($n in $names) {
        $inDegree[$n] = 0
        $adj[$n]      = [System.Collections.Generic.List[string]]::new()
    }

    foreach ($n in $names) {
        foreach ($dep in $ManifestMap[$n].DependsOn) {
            if (-not $ManifestMap.ContainsKey($dep)) {
                Write-VaiLog -Level WARN -Message ("Module '" + $n + "' depends on missing '" + $dep + "' — ignored")
                continue
            }
            $adj[$dep].Add($n)
            $inDegree[$n]++
        }
    }

    $queue  = [System.Collections.Generic.Queue[string]]::new()
    $sorted = [System.Collections.Generic.List[string]]::new()

    $names |
        Where-Object  { $inDegree[$_] -eq 0 } |
        Sort-Object    { $ManifestMap[$_].LoadPriority }, { $_ } |
        ForEach-Object { $queue.Enqueue($_) }

    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        $sorted.Add($node)

        $neighbors = $adj[$node] | Sort-Object { $ManifestMap[$_].LoadPriority }, { $_ }
        foreach ($next in $neighbors) {
            $inDegree[$next]--
            if ($inDegree[$next] -eq 0) {
                $queue.Enqueue($next)
            }
        }
    }

    if ($sorted.Count -ne $names.Count) {
        $cyclic = $names | Where-Object { $sorted -notcontains $_ }
        Write-VaiLog -Level ERROR -Message ("Dependency cycle: " + ($cyclic -join ", ") + ". Fallback priority.")
        foreach ($n in ($cyclic | Sort-Object { $ManifestMap[$_].LoadPriority }, { $_ })) {
            $sorted.Add($n)
        }
    }

    return $sorted
}

function global:Initialize-VaiModules {
    [CmdletBinding()]
    param(
        [string[]]$OnlyModules
    )

    $cMagenta = $global:Vai.Magenta
    $cReset   = $global:Vai.Reset
    $cGreen   = $global:Vai.Green
    $cBlue    = $global:Vai.Blue
    $cRed     = $global:Vai.Red
    $cGray    = $global:Vai.Gray

    if (Get-Command Write-VaiBanner -ErrorAction SilentlyContinue) {
        Write-VaiBanner -Title ("vai-core v" + $global:VaiCoreVersion) -Subtitle "Hybrid Registry · modules/ · Ship it" -Color Magenta
    }
    else {
        Write-Host ""
        Write-Host ("  vai-core v" + $global:VaiCoreVersion + " — HYBRID REGISTRY") -ForegroundColor Magenta
    }

    $psVer = $PSVersionTable.PSVersion.ToString()
    $psEd  = $PSVersionTable.PSEdition
    $os    = Get-VaiOS
    Write-VaiLog -Level INFO -Message ("=== Start vai-core v" + $global:VaiCoreVersion + " (PS " + $psVer + ", " + $psEd + ", " + $os + ") ===") -NoConsole

    if (-not (Test-Path $global:VaiFrameworkRoot)) {
        Write-Host ("  [FATAL] Framework root missing: " + $global:VaiFrameworkRoot) -ForegroundColor Red
        Write-VaiLog -Level ERROR -Message ("Framework root missing: " + $global:VaiFrameworkRoot)
        return
    }

    Initialize-VaiRegistry

    # --- Phase 1: scan modules/ only (primary layout v5.1) ---
    $manifests = @{}
    $moduleDirs = @()

    $modulesSub = Join-Path $global:VaiFrameworkRoot "modules"
    if (Test-Path $modulesSub) {
        $moduleDirs = @(Get-ChildItem -Path $modulesSub -Directory -ErrorAction SilentlyContinue)
    }

    # Legacy: sibling module folders at root (warn once if found)
    $excludeDirs = @(
        "core", "logs", "docs", ".git", ".vscode", "7", "node_modules",
        "contrib", ".github", "tests", "tmp", "temp", "modules"
    )
    $legacy = Get-ChildItem -Path $global:VaiFrameworkRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $excludeDirs -notcontains $_.Name -and
            (Test-Path (Join-Path $_.FullName "config.json")) -and
            (Test-Path (Join-Path $_.FullName "module.ps1"))
        }
    if ($legacy) {
        Write-VaiLog -Level WARN -Message ("Legacy root modules detected — move to modules/: " + (($legacy | ForEach-Object Name) -join ", "))
        $moduleDirs = @($moduleDirs) + @($legacy)
    }

    foreach ($dir in $moduleDirs) {
        try {
            $manifest = Read-VaiModuleManifest -Directory $dir
            if ($null -eq $manifest) { continue }

            if ($manifests.ContainsKey($manifest.Name)) {
                Write-VaiLog -Level WARN -Message ("Duplicate module '" + $manifest.Name + "' in '" + $dir.Name + "' — skip")
                continue
            }

            $manifests[$manifest.Name] = $manifest
        }
        catch {
            $errMsg = "Manifest parse failed '" + $dir.Name + "': " + $_.Exception.Message
            Write-Host ("  [CRASH] " + $errMsg) -ForegroundColor Red
            Write-VaiLog -Level ERROR -Message $errMsg
        }
    }

    # Filter OnlyModules + DependsOn closure
    if ($OnlyModules -and $OnlyModules.Count -gt 0) {
        $wanted = [System.Collections.Generic.HashSet[string]]::new([string[]]$OnlyModules)
        $changed = $true
        while ($changed) {
            $changed = $false
            foreach ($n in @($wanted)) {
                if (-not $manifests.ContainsKey($n)) {
                    # try by prefix/registry
                    $hit = $manifests.Values | Where-Object {
                        $_.Prefix -eq $n -or $_.RegistryKey -eq $n
                    } | Select-Object -First 1
                    if ($hit) {
                        [void]$wanted.Remove($n)
                        [void]$wanted.Add($hit.Name)
                        $n = $hit.Name
                        $changed = $true
                    }
                    continue
                }
                foreach ($d in $manifests[$n].DependsOn) {
                    if ($wanted.Add($d)) { $changed = $true }
                }
            }
        }
        $filtered = @{}
        foreach ($n in $manifests.Keys) {
            if ($wanted.Contains($n)) { $filtered[$n] = $manifests[$n] }
        }
        $manifests = $filtered
    }

    # --- Phase 2: topo ---
    $loadOrder = Get-VaiLoadOrder -ManifestMap $manifests

    # --- Phase 3: load ---
    $global:VaiModulesCache.Clear()
    if ($global:Vai.Modules -ne $global:VaiModulesCache) {
        $global:Vai.Modules = $global:VaiModulesCache
    }

    $stats = @{ Loaded = 0; Skipped = 0; Lazy = 0; Failed = 0 }

    foreach ($name in $loadOrder) {
        $m = $manifests[$name]

        if (-not $m.Enabled) {
            $m.Status = "Sleeping"
            $stats.Skipped++
            $global:VaiModulesCache.Add($m)
            continue
        }

        if ($m.LazyLoad) {
            $m.Status = "Lazy"
            $stats.Lazy++
            try {
                Register-VaiLazyExports -Manifest $m
            }
            catch {
                Write-VaiLog -Level ERROR -Message ("Lazy stubs failed for '" + $m.Name + "': " + $_.Exception.Message)
            }
            $global:VaiModulesCache.Add($m)
            continue
        }

        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $global:VaiModule = $m
        try {
            . $m.ScriptPath
            $timer.Stop()

            $m.LoadTimeMs = [Math]::Round($timer.Elapsed.TotalMilliseconds, 2)
            $m.Status     = "Loaded"
            $stats.Loaded++

            Write-VaiLog -Level DEBUG -Message ("Loaded '" + $m.Name + "' v" + $m.Version + " in " + $m.LoadTimeMs + " ms")
        }
        catch {
            $timer.Stop()
            $m.Status = "Failed"
            $stats.Failed++

            $errMsg = "Load failed '" + $m.Name + "': " + $_.Exception.Message
            Write-Host ("  [CRASH] " + $errMsg) -ForegroundColor Red
            Write-VaiLog -Level ERROR -Message $errMsg
        }
        finally {
            $global:VaiModule = $null
        }

        $global:VaiModulesCache.Add($m)
    }

    $global:_VaiBootStats = $stats
}

function global:Show-VaiBootSummary {
    param([double]$ElapsedMs)

    $totalMs = [Math]::Round($ElapsedMs, 2)
    $s = $global:_VaiBootStats
    if (-not $s) { $s = @{ Loaded = 0; Skipped = 0; Lazy = 0; Failed = 0 } }

    $exportCount = @(Get-VaiExport).Count
    $totalMods = @($global:VaiModulesCache).Count

    # Full roster — every module counts (Loaded + Lazy + Sleep + Failed)
    if (Get-Command Show-VaiModuleGrid -ErrorAction SilentlyContinue) {
        Show-VaiModuleGrid -Title "VAI MODULE ROSTER" -Modules $global:VaiModulesCache
    }
    else {
        Write-Host ("  Modules: $totalMods | Loaded=$($s.Loaded) Lazy=$($s.Lazy) Fail=$($s.Failed)")
    }

    Write-VaiRule -Label "boot"
    Write-Host ("  " +
        (Write-VaiPill "modules $totalMods" "hot") + " " +
        (Write-VaiPill "exports $exportCount" "info") + " " +
        (Write-VaiPill ("{0:N0} ms" -f $totalMs) "dim"))
    Write-VaiKV "OS" ((Get-VaiOS) + " · PS " + $PSVersionTable.PSVersion + " · " + $global:Vai.PrefixStyle)
    Write-VaiKV "Root" $global:VaiFrameworkRoot
    if ($global:Vai.Slogan -and $global:Vai.Slogan.Sex) {
        Write-Host ("  " + $global:Vai.Magenta + "  " + $global:Vai.Slogan.Sex + $global:Vai.Reset)
    }
    Write-Host ""

    Write-VaiLog -Level INFO -Message ("Boot done in " + $totalMs + " ms. modules=" + $totalMods + " L=" + $s.Loaded + " S=" + $s.Skipped + " Z=" + $s.Lazy + " F=" + $s.Failed + " E=" + $exportCount) -NoConsole
}
