# DockerTweaks commands

function script:Invoke-DockerDps {
    param([switch]$All)
    $containers = Get-DockerContainers -All:$All
    if (-not $containers -or $containers.Count -eq 0) {
        Write-VaiWarn "No containers."
        return
    }
    Write-VaiBanner -Title "DOCKER" -Subtitle ("{0} container(s)" -f $containers.Count) -Color Cyan
    $up = 0; $down = 0
    foreach ($c in $containers) {
        if ($c.Up) {
            $up++
            $pill = Write-VaiPill "UP" "ok"
        }
        else {
            $down++
            $pill = Write-VaiPill "DN" "fail"
        }
        Write-Host ("  " + $pill + " " + $global:Vai.Cyan + $c.Name.PadRight(22) + $global:Vai.Reset +
            $global:Vai.Gray + $c.Image + $global:Vai.Reset)
        Write-Host ("       " + $global:Vai.Gray + $c.Status + $(if ($c.Ports) { "  |  $($c.Ports)" }) + $global:Vai.Reset)
    }
    Write-VaiRule
    Write-Host ("  " + (Write-VaiPill "up $up" "ok") + " " + (Write-VaiPill "down $down" "fail"))
    Write-Host ""
}

function script:Invoke-DockerDsh {
    param([string]$Name, [string]$Shell = "")
    $target = Select-DockerContainer -Name $Name
    if (-not $target) { return }
    if (-not $target.Up) { Write-VaiError "Container not running: $($target.Name)"; return }

    Write-Host ("  " + (Write-VaiPill "exec" "hot") + " " + $target.Name)
    Write-VaiLog -Level INFO -Message "Docker: shell $($target.Name)" -NoConsole
    if ($Shell) {
        docker exec -it $target.ID $Shell
    }
    else {
        docker exec -it $target.ID sh -c "command -v bash >/dev/null && exec bash || exec sh"
    }
}

function script:Invoke-DockerDlogs {
    param([string]$Name, [int]$Tail = 100, [switch]$Follow, [switch]$Raw)
    $target = Select-DockerContainer -Name $Name
    if (-not $target) { return }

    Write-VaiBanner -Title "LOGS" -Subtitle $target.Name -Color Blue
    $dockerArgs = @("logs", "--tail", "$Tail", "--timestamps", $target.ID)
    if ($Follow) { $dockerArgs += "-f" }

    if ($Raw) {
        & docker @dockerArgs
    }
    else {
        & docker @dockerArgs 2>&1 | ForEach-Object { Write-DockerLogLine -Line ([string]$_) }
    }
}

function script:Show-DockerStatsFrame {
    $fmt = "{{.Name}}`t{{.CPUPerc}}`t{{.MemPerc}}`t{{.MemUsage}}`t{{.NetIO}}`t{{.BlockIO}}"
    $raw = & docker stats --no-stream --format $fmt 2>$null
    if (-not $raw) {
        Write-VaiWarn "No running containers."
        return
    }

    $rows = @($raw | ForEach-Object {
        $p = $_ -split "`t"
        [PSCustomObject]@{
            Name    = $p[0]
            CpuPct  = ConvertFrom-DockerPercent $p[1]
            MemPct  = ConvertFrom-DockerPercent $p[2]
            MemUse  = $p[3]
            NetIO   = $p[4]
            BlockIO = $p[5]
        }
    })

    Write-VaiBanner -Title "STATS" -Subtitle (Get-Date -Format 'HH:mm:ss') -Color Magenta
    $totalCpu = 0.0
    foreach ($r in $rows) {
        $totalCpu += $r.CpuPct
        $cpuBar = Get-VaiBar -Percent $r.CpuPct
        $memBar = Get-VaiBar -Percent $r.MemPct
        Write-Host ("  " + $global:Vai.Green + $r.Name + $global:Vai.Reset)
        Write-Host ("    CPU " + $cpuBar + " " + $r.CpuPct.ToString('0.0').PadLeft(5) + "%")
        Write-Host ("    RAM " + $memBar + " " + $r.MemPct.ToString('0.0').PadLeft(5) + "%  " + $global:Vai.Gray + $r.MemUse + $global:Vai.Reset)
        Write-Host ("    " + $global:Vai.Gray + "NET " + $r.NetIO + "   BLK " + $r.BlockIO + $global:Vai.Reset)
    }
    Write-VaiRule
    Write-Host ("  " + (Write-VaiPill "n $($rows.Count)" "info") + " " + (Write-VaiPill ("cpu {0:0.0}%" -f $totalCpu) "hot"))
}

function script:Invoke-DockerDstats {
    param([switch]$Watch, [int]$Interval = 2)
    if (-not (Test-DockerReady)) { return }
    if (-not $Watch) {
        Show-DockerStatsFrame
        Write-Host ""
        return
    }
    Write-Host ("  " + $global:Vai.Gray + "Live mode (${Interval}s). Ctrl+C to stop." + $global:Vai.Reset)
    try {
        while ($true) {
            Clear-Host
            Show-DockerStatsFrame
            Start-Sleep -Seconds $Interval
        }
    }
    finally {
        Write-Host ""
        Write-VaiWarn "Monitoring stopped."
    }
}

function script:Invoke-DockerDclean {
    param([switch]$Force, [switch]$Volumes, [switch]$All)
    if (-not (Test-DockerReady)) { return }

    Write-VaiBanner -Title "DOCKER CLEAN" -Subtitle "system prune" -Color Yellow
    $danglingImages = (docker images -f "dangling=true" -q 2>$null | Measure-Object).Count
    $stoppedCount   = @((Get-DockerContainers -All | Where-Object { -not $_.Up })).Count
    Write-VaiKV "stopped" $stoppedCount
    Write-VaiKV "dangling" $danglingImages
    if ($Volumes) { Write-Host ("  " + (Write-VaiPill "+volumes" "fail")) }
    if ($All)     { Write-Host ("  " + (Write-VaiPill "+all-images" "fail")) }

    if (-not (Confirm-VaiAction "Continue prune?" -Force:$Force)) {
        Write-VaiWarn "Cancelled."; return
    }

    $pruneArgs = @("system", "prune", "-f")
    if ($Volumes) { $pruneArgs += "--volumes" }
    if ($All)     { $pruneArgs += "-a" }
    & docker @pruneArgs
    Write-VaiLog -Level INFO -Message "Docker: prune Volumes=$Volumes All=$All"
    Write-VaiOk "Clean finished."
}

function script:Invoke-DockerDnuke {
    if (-not (Test-DockerReady)) { return }
    $all = Get-DockerContainers -All
    if (-not $all -or $all.Count -eq 0) { Write-VaiWarn "No containers."; return }

    Write-VaiBanner -Title "NUKE" -Subtitle ("stop+rm ALL ({0})" -f $all.Count) -Color Hot
    foreach ($c in $all) {
        Write-Host ("    - " + $c.Name + " " + $global:Vai.Gray + "(" + $c.Image + ")" + $global:Vai.Reset)
    }
    $confirm = Read-Host "  Type 'NUKE' to confirm"
    if ($confirm -cne 'NUKE') { Write-VaiWarn "Cancelled."; return }

    $ids = @($all.ID)
    docker stop @ids 2>$null | Out-Null
    docker rm   @ids 2>$null | Out-Null
    Write-VaiLog -Level WARN -Message "Docker: dnuke removed $($all.Count)"
    Write-VaiOk "All containers removed."
}

function script:Invoke-DockerDup {
    param(
        [string]$File,
        [switch]$Build,
        [switch]$Detach
    )
    if (-not (Test-ComposeReady)) { return }
    Write-VaiBanner -Title "COMPOSE UP" -Color Green
    $args = @("up")
    if ($Detach -or -not $PSBoundParameters.ContainsKey('Detach')) { $args += "-d" }
    if ($Build) { $args += "--build" }
    if ($File) { $args = @("-f", $File) + $args }
    Invoke-Compose -ComposeArgs $args
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Stack up." } else { Write-VaiError "compose up failed." }
}

function script:Invoke-DockerDdown {
    param([string]$File, [switch]$Volumes)
    if (-not (Test-ComposeReady)) { return }
    Write-VaiBanner -Title "COMPOSE DOWN" -Color Yellow
    $args = @("down")
    if ($Volumes) { $args += "-v" }
    if ($File) { $args = @("-f", $File) + $args }
    Invoke-Compose -ComposeArgs $args
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Stack down." } else { Write-VaiError "compose down failed." }
}

function script:Invoke-DockerDrestart {
    param([string]$Name)
    $target = Select-DockerContainer -Name $Name -All
    if (-not $target) { return }
    Write-Host ("  " + (Write-VaiPill "restart" "info") + " " + $target.Name)
    docker restart $target.ID
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Restarted $($target.Name)" } else { Write-VaiError "Restart failed." }
}

function script:Invoke-DockerDimg {
    if (-not (Test-DockerReady)) { return }
    Write-VaiBanner -Title "IMAGES" -Color Cyan
    $fmt = "{{.Repository}}`t{{.Tag}}`t{{.ID}}`t{{.Size}}`t{{.CreatedSince}}"
    $raw = docker images --format $fmt 2>$null
    if (-not $raw) { Write-VaiWarn "No images."; return }
    foreach ($line in $raw) {
        $p = $line -split "`t"
        Write-Host ("  " + (Write-VaiPill "img" "info") + " " +
            $global:Vai.Cyan + ("{0}:{1}" -f $p[0], $p[1]).PadRight(36) + $global:Vai.Reset +
            $global:Vai.Gray + $p[3].PadLeft(10) + "  " + $p[4] + $global:Vai.Reset)
    }
    Write-Host ""
}

function script:Invoke-DockerDvol {
    if (-not (Test-DockerReady)) { return }
    Write-VaiBanner -Title "VOLUMES" -Color Blue
    $fmt = "{{.Name}}`t{{.Driver}}`t{{.Scope}}"
    $raw = docker volume ls --format $fmt 2>$null
    if (-not $raw) { Write-VaiWarn "No volumes."; return }
    foreach ($line in $raw) {
        $p = $line -split "`t"
        Write-Host ("  " + (Write-VaiPill "vol" "dim") + " " + $global:Vai.Green + $p[0] + $global:Vai.Reset +
            "  " + $global:Vai.Gray + $p[1] + $global:Vai.Reset)
    }
    Write-Host ""
}

function script:Invoke-DockerDnet {
    if (-not (Test-DockerReady)) { return }
    Write-VaiBanner -Title "NETWORKS" -Color Magenta
    $fmt = "{{.Name}}`t{{.Driver}}`t{{.Scope}}"
    $raw = docker network ls --format $fmt 2>$null
    if (-not $raw) { Write-VaiWarn "No networks."; return }
    foreach ($line in $raw) {
        $p = $line -split "`t"
        Write-Host ("  " + (Write-VaiPill "net" "hot") + " " + $global:Vai.Cyan + $p[0].PadRight(24) + $global:Vai.Reset +
            $global:Vai.Gray + $p[1] + $global:Vai.Reset)
    }
    Write-Host ""
}

function script:Invoke-DockerDtop {
    param([string]$Name)
    $target = Select-DockerContainer -Name $Name
    if (-not $target) { return }
    if (-not $target.Up) { Write-VaiError "Not running."; return }
    Write-VaiBanner -Title "TOP" -Subtitle $target.Name -Color Yellow
    docker top $target.ID
}

function script:Invoke-DockerDexec {
    param(
        [string]$Name,
        [Parameter(ValueFromRemainingArguments = $true)]
        $CmdArgs
    )
    $target = Select-DockerContainer -Name $Name
    if (-not $target) { return }
    if (-not $target.Up) { Write-VaiError "Not running."; return }
    $argv = @()
    if ($CmdArgs) { $argv = @($CmdArgs) }
    if ($argv.Count -eq 0) {
        Write-VaiWarn "Usage: dexec [name] -- <cmd> [args...]"
        return
    }
    # drop leading -- if present
    if ($argv[0] -eq '--') { $argv = @($argv[1..($argv.Count - 1)]) }
    docker exec -it $target.ID @argv
}

function script:Invoke-DockerDbuild {
    param(
        [Parameter(Position = 0)][string]$Tag,
        [string]$File = "Dockerfile",
        [string]$Context = ".",
        [switch]$NoCache
    )
    if (-not (Test-DockerReady)) { return }
    if (-not $Tag) {
        $base = Split-Path -Leaf (Get-Location).Path
        $Tag = ($base -replace '[^a-zA-Z0-9_.-]', '-').ToLower() + ":dev"
    }
    Write-VaiBanner -Title "BUILD" -Subtitle $Tag -Color Green
    $args = @("build", "-t", $Tag, "-f", $File)
    if ($NoCache) { $args += "--no-cache" }
    $args += $Context
    Write-VaiKV "cmd" ("docker " + ($args -join " "))
    Write-VaiRule
    & docker @args
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Built $Tag" } else { Write-VaiError "Build failed." }
}

function script:Invoke-DockerDcp {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Src,
        [Parameter(Mandatory, Position = 1)][string]$Dst
    )
    if (-not (Test-DockerReady)) { return }
    # container:path or local
    Write-VaiBanner -Title "CP" -Subtitle "$Src → $Dst" -Color Cyan
    docker cp $Src $Dst
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Copy done." } else { Write-VaiError "Copy failed." }
}

function script:Invoke-DockerDports {
    param([string]$Name)
    $target = Select-DockerContainer -Name $Name
    if (-not $target) { return }
    Write-VaiBanner -Title "PORTS" -Subtitle $target.Name -Color Blue
    docker port $target.ID 2>$null
    if ($target.Ports) {
        Write-VaiKV "ps" $target.Ports
    }
    Write-Host ""
}

function script:Invoke-DockerDhealth {
    if (-not (Test-DockerReady)) { return }
    Write-VaiBanner -Title "DOCKER HEALTH" -Color Yellow
    $ver = docker version --format '{{.Server.Version}}' 2>$null
    $info = docker info --format '{{.ContainersRunning}}/{{.Containers}} running · images {{.Images}} · mem {{.MemTotal}}' 2>$null
    Write-VaiKV "server" $(if ($ver) { $ver } else { "?" })
    Write-VaiKV "info" $(if ($info) { $info } else { "n/a" })
    $df = docker system df 2>$null
    if ($df) {
        Write-VaiRule -Label "disk"
        $df | ForEach-Object { Write-Host ("  " + $global:Vai.Gray + $_ + $global:Vai.Reset) }
    }
    Write-Host ""
}

function script:Invoke-DockerDprune {
    param([switch]$Force, [switch]$Volumes, [switch]$All)
    if (-not (Test-DockerReady)) { return }
    Write-VaiBanner -Title "PRUNE" -Subtitle "images + build cache" -Color Yellow
    if (-not (Confirm-VaiAction "Prune unused docker data?" -Force:$Force)) { return }
    $imgArgs = @("image", "prune", "-f")
    if ($All) { $imgArgs += "-a" }
    & docker @imgArgs 2>$null
    docker builder prune -f 2>$null
    if ($Volumes) { docker volume prune -f 2>$null }
    docker network prune -f 2>$null
    Write-VaiOk "Prune complete."
    Invoke-DockerDhealth
}

function script:Invoke-DockerDpsCompose {
    if (-not (Test-ComposeReady)) { return }
    Write-VaiBanner -Title "COMPOSE PS" -Color Magenta
    Invoke-Compose -ComposeArgs @("ps")
}

function script:Invoke-DockerDlogsCompose {
    param([switch]$Follow, [int]$Tail = 100)
    if (-not (Test-ComposeReady)) { return }
    $args = @("logs", "--tail", "$Tail")
    if ($Follow) { $args += "-f" }
    Invoke-Compose -ComposeArgs $args
}

function script:Invoke-DockerHelp {
    Write-VaiBanner -Title "DOCKER TWEAKS" -Subtitle "v1.5" -Color Cyan
    Write-VaiBox -Title "COMMANDS" -Color Blue -Lines @(
        "dps [-All]                 Container status TUI",
        "dsh [name]                 Shell into container",
        "dlogs [name] [-Follow]     Highlighted logs",
        "dstats [-Watch]            CPU/RAM bars",
        "dup / ddown / dcmp         compose up/down/ps",
        "dclogs [-Follow]           compose logs",
        "drestart [name]            Restart container",
        "dbuild [tag]               docker build -t",
        "dcp src dst                docker cp",
        "dports [name]              Published ports",
        "dhealth / dprune           Disk + prune",
        "dimg / dvol / dnet         Images, volumes, networks",
        "dtop / dexec               top / exec",
        "dclean / dnuke             system prune / destroy all",
        "Invoke-Vai Docker dps      Script API"
    )
}
