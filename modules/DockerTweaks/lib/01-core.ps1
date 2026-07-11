# DockerTweaks core helpers

function script:Test-DockerReady {
    if (-not (Test-VaiCommand docker)) {
        Write-VaiError "docker not found in PATH. Install Docker Desktop / engine."
        return $false
    }
    docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-VaiWarn "Docker installed but daemon not responding."
        return $false
    }
    return $true
}

function script:Test-ComposeReady {
    if (-not (Test-DockerReady)) { return $false }
    docker compose version 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }
    if (Test-VaiCommand docker-compose) { return $true }
    Write-VaiWarn "docker compose not available."
    return $false
}

function script:Invoke-Compose {
    param([string[]]$ComposeArgs)
    docker compose version 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $all = @("compose") + @($ComposeArgs)
        & docker @all
    }
    else {
        & docker-compose @ComposeArgs
    }
}

function script:Get-DockerContainers {
    param([switch]$All)
    if (-not (Test-DockerReady)) { return @() }
    $fmt = "{{.ID}}`t{{.Names}}`t{{.Image}}`t{{.Status}}`t{{.Ports}}"
    $psArgs = @("ps")
    if ($All) { $psArgs += "-a" }
    $psArgs += @("--format", $fmt)
    $raw = & docker @psArgs 2>$null
    if (-not $raw) { return @() }
    return @($raw | ForEach-Object {
        $p = $_ -split "`t"
        [PSCustomObject]@{
            ID     = $p[0]
            Name   = $p[1]
            Image  = $p[2]
            Status = $p[3]
            Ports  = $p[4]
            Up     = ($p[3] -like "Up*")
        }
    })
}

function script:Select-DockerContainer {
    param([string]$Name, [switch]$All)
    $list = Get-DockerContainers -All:$All
    if (-not $list -or $list.Count -eq 0) {
        Write-Host ("  " + $global:Vai.Gray + "No containers." + $global:Vai.Reset)
        return $null
    }
    if ($Name) {
        $hit = $list | Where-Object { $_.Name -like "*$Name*" -or $_.ID -like "$Name*" } | Select-Object -First 1
        if ($hit) { return $hit }
    }
    if ($list.Count -eq 1) { return $list[0] }

    $items = @($list | ForEach-Object {
        $st = if ($_.Up) { "up" } else { "down" }
        "{0}  [{1}]  {2}" -f $_.Name, $st, $_.Image
    })
    $idx = Show-VaiMenu -Title "Pick container" -Items $items
    if ($idx -le 0) { return $null }
    return $list[$idx - 1]
}

function script:ConvertFrom-DockerPercent {
    param([string]$Text)
    $clean = ($Text -replace '%', '').Trim() -replace ',', '.'
    $val = 0.0
    [void][double]::TryParse($clean, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val)
    return $val
}

function script:Write-DockerLogLine {
    param([string]$Line)
    $ts = ""; $msg = $Line
    if ($Line -match '^(\S+T\S+Z?)\s+(.*)$') { $ts = $matches[1]; $msg = $matches[2] }

    $color = $global:Vai.Gray
    if     ($msg -match '(?i)\b(error|err|fatal|panic|exception|failed)\b') { $color = $global:Vai.Red }
    elseif ($msg -match '(?i)\b(warn|warning|deprecated)\b')               { $color = $global:Vai.Yellow }
    elseif ($msg -match '(?i)\b(info|notice)\b')                           { $color = $global:Vai.Cyan }
    elseif ($msg -match '(?i)\b(debug|trace)\b')                           { $color = $global:Vai.Gray }

    if ($ts) {
        $shortTs = if ($ts -match 'T(\d{2}:\d{2}:\d{2})') { $matches[1] } else { $ts }
        Write-Host ("  " + $global:Vai.Gray + $shortTs + $global:Vai.Reset + " " + $color + $msg + $global:Vai.Reset)
    }
    else {
        Write-Host ("  " + $color + $msg + $global:Vai.Reset)
    }
}
