# SEX target runner

function script:Resolve-SexTool {
    param($Config, [string]$Name)
    $tools = Get-SexMapValue $Config "tools" $null
    $map = @{}
    if ($tools -is [hashtable]) { $map = $tools }
    elseif ($tools) {
        foreach ($p in $tools.PSObject.Properties) { $map[$p.Name] = $p.Value }
    }
    return (Get-VaiTool -Name $Name -Map $map)
}

function script:Expand-SexEnv {
    param($Config, $Target)

    $merged = @{}
    $baseEnv = Get-SexMapValue $Config "env" $null
    if ($baseEnv -is [hashtable]) {
        foreach ($k in $baseEnv.Keys) { $merged[$k] = [string]$baseEnv[$k] }
    }
    elseif ($baseEnv) {
        foreach ($p in $baseEnv.PSObject.Properties) { $merged[$p.Name] = [string]$p.Value }
    }

    $tEnv = Get-SexMapValue $Target "env" $null
    if ($tEnv -is [hashtable]) {
        foreach ($k in $tEnv.Keys) { $merged[$k] = [string]$tEnv[$k] }
    }
    elseif ($tEnv) {
        foreach ($p in $tEnv.PSObject.Properties) { $merged[$p.Name] = [string]$p.Value }
    }
    return $merged
}

function script:Get-SexRunSteps {
    param($Target)
    $run = Get-SexMapValue $Target "run" @()
    if ($null -eq $run) { return @() }

    # Single step object { cmd / argv } (mini-yaml edge or sex.json)
    if ($run -is [hashtable] -or ($run.PSObject -and (
            (Test-VaiProperty $run "cmd") -or (Test-VaiProperty $run "argv")))) {
        # Not a list of steps
        if ($run -isnot [System.Collections.IList] -or $run -is [hashtable] -or $run -is [string]) {
            return @($run)
        }
    }

    return @($run)
}

function script:Invoke-SexStep {
    param(
        $Step,
        $Config,
        [string]$WorkingDirectory,
        [hashtable]$Environment,
        [switch]$Dry
    )

    $argv = Get-SexMapValue $Step "argv" $null
    $cmd  = Get-SexMapValue $Step "cmd" $null
    $shell = [bool](Get-SexMapValue $Step "shell" $false)
    $bg = [bool](Get-SexMapValue $Step "bg" $false)
    $cwd = Get-SexMapValue $Step "cwd" $WorkingDirectory
    if ($cwd) { $cwd = Resolve-VaiPath -Path ([string]$cwd) -Base $WorkingDirectory }

    $file = $null
    $args = @()

    if ($argv) {
        $list = @($argv)
        $file = [string]$list[0]
        if ($list.Count -gt 1) { $args = @($list[1..($list.Count - 1)]) }
        # tool alias expand
        $resolved = Resolve-SexTool -Config $Config -Name $file
        if ($resolved) { $file = $resolved }
    }
    elseif ($cmd) {
        $cmdStr = [string]$cmd
        # expand $tools.xxx? keep simple
        if ($shell) {
            if ($global:Vai.IsWindows) {
                $file = "cmd.exe"
                $args = @("/c", $cmdStr)
            }
            else {
                $file = "bash"
                $args = @("-lc", $cmdStr)
            }
        }
        else {
            $parts = Split-VaiCommandLine $cmdStr
            if ($parts.Count -eq 0) { throw "Empty cmd" }
            $file = $parts[0]
            $resolved = Resolve-SexTool -Config $Config -Name $file
            if ($resolved) { $file = $resolved }
            if ($parts.Count -gt 1) { $args = @($parts[1..($parts.Count - 1)]) }
        }
    }
    else {
        throw "Step needs cmd or argv"
    }

    $display = $file + " " + ($args -join " ")
    if ($Dry) {
        return [PSCustomObject]@{
            Ok      = $true
            Dry     = $true
            Bg      = $bg
            Display = $display
            ExitCode = 0
        }
    }

    if ($bg) {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $file
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $false
        if ($cwd) { $psi.WorkingDirectory = $cwd }
        if ($args.Count -gt 0) {
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                foreach ($a in $args) { [void]$psi.ArgumentList.Add($a) }
            }
            else {
                $psi.Arguments = ($args | ForEach-Object {
                    if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
                }) -join ' '
            }
        }
        if ($Environment) {
            foreach ($k in $Environment.Keys) {
                try { $psi.Environment[$k] = $Environment[$k] } catch {}
            }
        }
        $proc = [System.Diagnostics.Process]::Start($psi)
        $script:SexBgJobs.Add([PSCustomObject]@{
            Pid     = $proc.Id
            File    = $file
            Started = Get-Date
        })
        return [PSCustomObject]@{
            Ok = $true
            Dry = $false
            Bg = $true
            Display = $display
            ExitCode = 0
            Pid = $proc.Id
        }
    }

    # foreground — use call operator for interactive friendliness
    $old = Get-Location
    try {
        if ($cwd) { Set-Location -LiteralPath $cwd }
        foreach ($k in $Environment.Keys) {
            Set-Item -Path "Env:$k" -Value $Environment[$k]
        }
        & $file @args
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        return [PSCustomObject]@{
            Ok = ($code -eq 0)
            Dry = $false
            Bg = $false
            Display = $display
            ExitCode = $code
        }
    }
    finally {
        Set-Location $old
    }
}

function script:Invoke-SexTarget {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$Dry
    )

    $path = Find-SexConfigPath
    if (-not $path) {
        Write-VaiError "No sex.yaml / sex.json found. Run: sex init"
        return
    }

    $config = Read-SexConfig -Path $path
    if (-not $config) {
        Write-VaiError "Failed to parse config: $path"
        return
    }

    $targets = Get-SexTargets $config
    if (-not $targets.ContainsKey($Name) -and -not (Test-VaiProperty $targets $Name)) {
        # hashtable vs PSCustomObject
        $keys = @()
        if ($targets -is [hashtable]) { $keys = @($targets.Keys) }
        else { $keys = @($targets.PSObject.Properties.Name) }
        Write-VaiError "Unknown target '$Name'. Known: $($keys -join ', ')"
        return
    }

    $target = if ($targets -is [hashtable]) { $targets[$Name] } else { $targets.$Name }
    $desc = Get-SexMapValue $target "desc" ""
    $cwdRel = Get-SexMapValue $target "cwd" "."
    $baseDir = Split-Path -Parent $path
    $cwd = Resolve-VaiPath -Path ([string]$cwdRel) -Base $baseDir

    Write-VaiBanner -Title "SEX · $Name" -Subtitle $script:SexSlogan -Color Magenta
    Write-VaiKV "Config" $path
    Write-VaiKV "Cwd" $cwd
    if ($desc) { Write-VaiKV "Desc" $desc }
    if ($Dry) { Write-Host ("  " + $global:Vai.Yellow + "DRY RUN — no side effects" + $global:Vai.Reset) }
    Write-VaiSeparator

    $envMap = Expand-SexEnv -Config $config -Target $target
    $steps = Get-SexRunSteps -Target $target
    if ($steps.Count -eq 0) {
        Write-VaiWarn "Target has no run steps."
    }

    $i = 0
    $failed = $false
    foreach ($step in $steps) {
        $i++
        try {
            $result = Invoke-SexStep -Step $step -Config $config -WorkingDirectory $cwd -Environment $envMap -Dry:$Dry
            $state = if ($result.Bg) { "bg" } elseif ($result.Dry) { "skip" } elseif ($result.Ok) { "ok" } else { "fail" }
            Write-VaiStep -Index $i -Total $steps.Count -Message $result.Display -State $state
            if ($result.Bg -and $result.Pid) {
                Write-Host ("      " + $global:Vai.Gray + "pid $($result.Pid)" + $global:Vai.Reset)
            }
            if (-not $result.Ok -and -not $result.Dry) {
                $failed = $true
                $cont = Get-SexMapValue $step "continueOnError" $false
                if (-not $cont) { break }
            }
        }
        catch {
            Write-VaiStep -Index $i -Total $steps.Count -Message $_.Exception.Message -State "fail"
            $failed = $true
            break
        }
    }

    # open URLs
    $opens = Get-SexMapValue $target "open" @()
    if ($opens -and -not $failed) {
        foreach ($u in @($opens)) {
            $url = [string]$u
            if ($Dry) {
                Write-VaiStep -Index 0 -Total 0 -Message ("open $url") -State "skip"
            }
            else {
                Write-Host ("  " + $global:Vai.Cyan + "open " + $url + $global:Vai.Reset)
                Open-VaiUrl $url
            }
        }
    }

    $after = Get-SexMapValue $target "after" $null
    if ($after) {
        Write-Host ""
        Write-Host ("  " + $global:Vai.Magenta + $after + $global:Vai.Reset)
    }

    Write-Host ""
    if ($failed) {
        Write-VaiError "Target '$Name' finished with errors."
    }
    elseif ($Dry) {
        Write-VaiOk "Dry plan for '$Name' complete. $($script:SexSlogan)"
    }
    else {
        Write-VaiOk "Target '$Name' done. $($script:SexSlogan)"
    }
}
