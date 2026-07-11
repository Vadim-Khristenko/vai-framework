# SEX CLI dispatcher

function script:Show-SexHelp {
    Write-VaiBanner -Title "SEX" -Subtitle $script:SexSlogan -Color Magenta
    $lines = @(
        "sex                     Help (you are here)",
        "sex init                Drop sex.yaml in cwd",
        "sex which               Resolved config path",
        "sex list                Targets + descriptions",
        "sex <target>            Run target (default from yaml)",
        "sex <target> --dry      Plan only",
        "sex up --dry            Example dry-run",
        "sex down                Stop tracked bg jobs (session)",
        "",
        "Config: sex.yaml | sex.yml | sex.json",
        "API:    Invoke-Vai Sex sex up",
        "Keep it spicy. Keep it shippable."
    )
    Write-VaiBox -Title "COMMANDS" -Color Cyan -Lines $lines
}

function script:Invoke-SexInit {
    $path = Join-Path (Get-Location).Path "sex.yaml"
    if (Test-Path -LiteralPath $path) {
        Write-VaiWarn "sex.yaml already exists: $path"
        if (-not (Confirm-VaiAction "Overwrite?")) { return }
    }
    Write-VaiFile -Path $path -Content (Get-SexSampleYaml)
    Write-VaiOk "Wrote $path"
    Write-Host ("  " + $global:Vai.Magenta + $script:SexSlogan + $global:Vai.Reset)
    Write-Host ""
}

function script:Invoke-SexWhich {
    $found = Find-SexConfigPath
    if ($found) { Write-VaiOk "Config: $found" }
    else { Write-VaiWarn "No sex.yaml found. Run: sex init" }
}

function script:Invoke-SexList {
    $path = Find-SexConfigPath
    if (-not $path) {
        Write-VaiWarn "No sex.yaml. Run: sex init"
        return
    }

    $config = Read-SexConfig -Path $path
    if (-not $config) {
        Write-VaiError "Parse failed: $path"
        return
    }

    $default = Get-SexMapValue $config "default" ""
    $name = Get-SexMapValue $config "name" ""
    Write-VaiBanner -Title "SEX TARGETS" -Subtitle $(if ($name) { $name } else { $path }) -Color Cyan
    Write-VaiKV "Config" $path
    if ($default) { Write-VaiKV "Default" $default }
    Write-VaiSeparator

    $targets = Get-SexTargets $config
    $keys = if ($targets -is [hashtable]) { @($targets.Keys) } else { @($targets.PSObject.Properties.Name) }
    foreach ($k in ($keys | Sort-Object)) {
        $t = if ($targets -is [hashtable]) { $targets[$k] } else { $targets.$k }
        $desc = Get-SexMapValue $t "desc" ""
        $mark = if ($k -eq $default) { $global:Vai.Yellow + "*" + $global:Vai.Reset } else { " " }
        Write-Host ("  " + $mark + " " + $global:Vai.Green + $k.PadRight(16) + $global:Vai.Reset + " " + $global:Vai.Gray + $desc + $global:Vai.Reset)
    }
    Write-Host ""
}

function script:Invoke-SexDown {
    if ($script:SexBgJobs.Count -eq 0) {
        Write-VaiWarn "No tracked background jobs in this session."
        return
    }
    foreach ($j in @($script:SexBgJobs)) {
        try {
            $p = Get-Process -Id $j.Pid -ErrorAction Stop
            Stop-Process -Id $j.Pid -Force -ErrorAction Stop
            Write-VaiOk "Stopped pid $($j.Pid) ($($j.File))"
        }
        catch {
            Write-VaiWarn "pid $($j.Pid): $($_.Exception.Message)"
        }
    }
    $script:SexBgJobs.Clear()
}

function script:Invoke-Sex {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Action,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    $argsList = @()
    if ($RemainingArguments) { $argsList = @($RemainingArguments) }

    $dry = $false
    $filtered = [System.Collections.Generic.List[string]]::new()
    foreach ($a in $argsList) {
        if ($a -in @("--dry", "-Dry", "-dry")) { $dry = $true }
        else { $filtered.Add([string]$a) }
    }

    if (-not $Action -or $Action -in @("help", "-h", "--help")) {
        Show-SexHelp
        return
    }

    switch -Regex ($Action) {
        '^(init)$'    { Invoke-SexInit; return }
        '^(which)$'   { Invoke-SexWhich; return }
        '^(list|ls)$' { Invoke-SexList; return }
        '^(down|stop)$' { Invoke-SexDown; return }
        '^(run)$' {
            $t = if ($filtered.Count -gt 0) { $filtered[0] } else { $null }
            if (-not $t) {
                $path = Find-SexConfigPath
                $cfg = if ($path) { Read-SexConfig $path } else { $null }
                $t = Get-SexMapValue $cfg "default" "up"
            }
            Invoke-SexTarget -Name $t -Dry:$dry
            return
        }
        default {
            # treat as target name
            Invoke-SexTarget -Name $Action -Dry:$dry
        }
    }
}
