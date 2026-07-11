# ==============================================================================
# VAI-NET — Network module VAI-FRAMEWORK v5
# ==============================================================================

$script:NetConfig = $null

function script:Get-VaiNetConfig {
    if ($null -eq $script:NetConfig) {
        $moduleRoot = Split-Path -Parent $PSScriptRoot
        if ($global:VaiModule -and $global:VaiModule.ConfigPath) {
            $cfgPath = $global:VaiModule.ConfigPath
        }
        else {
            $cfgPath = Join-Path $moduleRoot "config.json"
        }
        $json = Read-VaiJson -Path $cfgPath
        if ($json -and (Test-VaiProperty $json "Settings")) {
            $script:NetConfig = $json.Settings
        }
        else {
            $script:NetConfig = [PSCustomObject]@{
                DefaultTimeout   = 3000
                DefaultPingCount = 4
                MaxParallelJobs  = 20
                MonitorInterval  = 5
            }
        }
    }
    return $script:NetConfig
}

$script:WellKnownPorts = @{
    21 = "FTP"; 22 = "SSH"; 23 = "Telnet"; 25 = "SMTP"; 53 = "DNS"
    80 = "HTTP"; 110 = "POP3"; 143 = "IMAP"; 443 = "HTTPS"; 445 = "SMB"
    993 = "IMAPS"; 995 = "POP3S"; 1433 = "MSSQL"; 3306 = "MySQL"; 3389 = "RDP"
    5432 = "PostgreSQL"; 5900 = "VNC"; 6379 = "Redis"; 8080 = "HTTP-Alt"; 8443 = "HTTPS-Alt"
}

function script:Invoke-NetPing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Hosts,
        [Parameter(Position = 1)]
        [int]$Count = 0,
        [int]$Timeout = 0
    )

    $cfg = Get-VaiNetConfig
    if ($Count -le 0)   { $Count   = [int](Get-VaiValue $cfg "DefaultPingCount" 4) }
    if ($Timeout -le 0) { $Timeout = [int](Get-VaiValue $cfg "DefaultTimeout" 3000) }

    Write-Host ""
    Write-Host ("  " + $global:Vai.Cyan + "PING " + ($Hosts -join ", ") + " (x$Count, ${Timeout}ms)" + $global:Vai.Reset)
    Write-VaiSeparator

    foreach ($target in $Hosts) {
        $results = @(); $success = 0; $totalMs = 0
        for ($i = 1; $i -le $Count; $i++) {
            try {
                $ping  = New-Object System.Net.NetworkInformation.Ping
                $reply = $ping.Send($target, $Timeout)
                if ($reply.Status -eq "Success") {
                    $ms = $reply.RoundtripTime
                    $results += $ms; $totalMs += $ms; $success++
                    $color = $global:Vai.Green
                    if ($ms -gt 100) { $color = $global:Vai.Yellow }
                    if ($ms -gt 300) { $color = $global:Vai.Red }
                    Write-Host ("  " + $color + "  [$i/$Count] $target — $ms ms" + $global:Vai.Reset)
                }
                else {
                    Write-Host ("  " + $global:Vai.Red + "  [$i/$Count] $target — $($reply.Status)" + $global:Vai.Reset)
                }
                $ping.Dispose()
            }
            catch {
                Write-Host ("  " + $global:Vai.Red + "  [$i/$Count] $target — ERROR: $($_.Exception.Message)" + $global:Vai.Reset)
            }
        }
        Write-VaiSeparator
        if ($results.Count -gt 0) {
            $loss = [Math]::Round((($Count - $success) / $Count) * 100, 1)
            $minMs = ($results | Measure-Object -Minimum).Minimum
            $maxMs = ($results | Measure-Object -Maximum).Maximum
            $avgMs = [Math]::Round($totalMs / $success, 1)
            Write-Host ("  " + $global:Vai.Blue + "  $target" + $global:Vai.Reset + ": min=$minMs avg=$avgMs max=$maxMs ms | loss: $loss%")
        }
        else {
            Write-Host ("  " + $global:Vai.Red + "  ${target}: 100% loss" + $global:Vai.Reset)
        }
        Write-Host ""
    }
}

function script:Invoke-NetPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Host_,
        [int[]]$Ports,
        [string]$Range,
        [switch]$Top20,
        [int]$Timeout = 0
    )

    $cfg = Get-VaiNetConfig
    if ($Timeout -le 0) { $Timeout = [int](Get-VaiValue $cfg "DefaultTimeout" 3000) }

    $portList = @()
    if ($Top20) {
        $portList = @(21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 993, 995, 1433, 3306, 3389, 5432, 5900, 6379, 8080, 8443)
    }
    elseif ($Ports -and $Ports.Count -gt 0) { $portList = $Ports }
    elseif ($Range) {
        $parts = $Range -split "-"
        if ($parts.Count -eq 2) { $portList = [int]$parts[0]..[int]$parts[1] }
    }

    if ($portList.Count -eq 0) {
        Write-VaiWarn "Specify ports: -Ports 80,443 | -Range 1-100 | -Top20"
        return
    }

    Write-Host ""
    Write-Host ("  " + $global:Vai.Cyan + "PORT SCAN: $Host_ ($($portList.Count) ports)" + $global:Vai.Reset)
    Write-VaiSeparator
    $openCount = 0; $closedCount = 0

    foreach ($port in $portList) {
        $serviceName = if ($script:WellKnownPorts.ContainsKey($port)) { $script:WellKnownPorts[$port] } else { "" }
        $portStr = $port.ToString().PadRight(9)
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $ar = $tcp.BeginConnect($Host_, $port, $null, $null)
            $ok = $ar.AsyncWaitHandle.WaitOne($Timeout, $false)
            if ($ok -and $tcp.Connected) {
                $tcp.EndConnect($ar); $openCount++
                Write-Host ("  " + $global:Vai.Green + "  $portStr OPEN        $serviceName" + $global:Vai.Reset)
            }
            else {
                $closedCount++
                Write-Host ("  " + $global:Vai.Gray + "  $portStr CLOSED      $serviceName" + $global:Vai.Reset)
            }
            $tcp.Close(); $tcp.Dispose()
        }
        catch {
            $closedCount++
            Write-Host ("  " + $global:Vai.Red + "  $portStr ERROR       $serviceName" + $global:Vai.Reset)
        }
    }
    Write-VaiSeparator
    Write-Host ("  Open: " + $global:Vai.Green + $openCount + $global:Vai.Reset + " | Closed: $closedCount")
    Write-Host ""
}

function script:Invoke-NetDns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Targets
    )

    Write-VaiHeader "DNS RESOLVE"
    foreach ($target in $Targets) {
        $isIP = $false
        try { [System.Net.IPAddress]::Parse($target) | Out-Null; $isIP = $true } catch {}

        if ($isIP) {
            Write-Host ("  " + $global:Vai.Blue + "  $target" + $global:Vai.Reset + " (reverse):")
            try {
                $hostEntry = [System.Net.Dns]::GetHostEntry($target)
                Write-Host ("    " + $global:Vai.Green + "Hostname: " + $hostEntry.HostName + $global:Vai.Reset)
            }
            catch { Write-Host ("    " + $global:Vai.Red + $_.Exception.Message + $global:Vai.Reset) }
        }
        else {
            Write-Host ("  " + $global:Vai.Blue + "  $target" + $global:Vai.Reset + " (forward):")
            try {
                $timer = [System.Diagnostics.Stopwatch]::StartNew()
                $addresses = [System.Net.Dns]::GetHostAddresses($target)
                $timer.Stop()
                foreach ($addr in $addresses) {
                    $family = if ($addr.AddressFamily -eq "InterNetworkV6") { "IPv6" } else { "IPv4" }
                    Write-Host ("    " + $global:Vai.Green + "$family`: " + $addr + $global:Vai.Reset)
                }
                Write-Host ("    " + $global:Vai.Gray + "Time: $($timer.ElapsedMilliseconds) ms" + $global:Vai.Reset)
            }
            catch { Write-Host ("    " + $global:Vai.Red + $_.Exception.Message + $global:Vai.Reset) }
        }
    }
    Write-Host ""
}

function script:Invoke-NetTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Target,
        [int]$MaxHops = 30,
        [int]$Timeout = 0
    )

    $cfg = Get-VaiNetConfig
    if ($Timeout -le 0) { $Timeout = [int](Get-VaiValue $cfg "DefaultTimeout" 3000) }

    Write-Host ""
    Write-Host ("  " + $global:Vai.Cyan + "TRACEROUTE: $Target (max $MaxHops)" + $global:Vai.Reset)
    Write-VaiSeparator

    $ping = New-Object System.Net.NetworkInformation.Ping
    $buffer = [byte[]]@(0) * 32
    $options = New-Object System.Net.NetworkInformation.PingOptions

    try {
        $targetIP = ([System.Net.Dns]::GetHostAddresses($Target) | Where-Object {
            $_.AddressFamily -eq "InterNetwork"
        } | Select-Object -First 1).ToString()
    }
    catch {
        Write-VaiError "Cannot resolve $Target"
        return
    }

    for ($ttl = 1; $ttl -le $MaxHops; $ttl++) {
        $options.Ttl = $ttl
        $options.DontFragment = $true
        try {
            $reply = $ping.Send($targetIP, $Timeout, $buffer, $options)
            $hopStr = $ttl.ToString().PadLeft(3)
            $address = $reply.Address.ToString()
            $hostName = ""
            try {
                $he = [System.Net.Dns]::GetHostEntry($address)
                if ($he.HostName -ne $address) { $hostName = $he.HostName }
            } catch {}

            if ($reply.Status -eq "Success") {
                $ms = $reply.RoundtripTime
                Write-Host ("  " + $global:Vai.Green + "  $hopStr   ${ms} ms   $address  $hostName" + $global:Vai.Reset)
                Write-VaiOk "Route complete in $ttl hops"
                break
            }
            elseif ($reply.Status -eq "TtlExpired") {
                Write-Host ("  " + $global:Vai.Yellow + "  $hopStr   $($reply.RoundtripTime) ms   $address  $hostName" + $global:Vai.Reset)
            }
            else {
                Write-Host ("  " + $global:Vai.Red + "  $hopStr   *  $($reply.Status)" + $global:Vai.Reset)
            }
        }
        catch {
            Write-Host ("  " + $global:Vai.Red + "  $($ttl.ToString().PadLeft(3))   *  Timeout" + $global:Vai.Reset)
        }
    }
    $ping.Dispose()
    Write-Host ""
}

function script:Invoke-NetIface {
    [CmdletBinding()]
    param([switch]$Active)

    Write-VaiHeader "NETWORK INTERFACES"
    $interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
    if ($Active) { $interfaces = $interfaces | Where-Object { $_.OperationalStatus -eq "Up" } }

    foreach ($iface in $interfaces) {
        $status = $iface.OperationalStatus.ToString()
        $statusColor = if ($status -eq "Up") { $global:Vai.Green } else { $global:Vai.Red }
        $mac = $iface.GetPhysicalAddress().ToString()
        if ($mac.Length -eq 12) { $mac = ($mac -replace '(.{2})', '$1:').TrimEnd(':') }

        Write-Host ""
        Write-Host ("  " + $global:Vai.Blue + "  " + $iface.Name + $global:Vai.Reset)
        Write-Host ("    Type    : " + $iface.NetworkInterfaceType)
        Write-Host ("    Status  : " + $statusColor + $status + $global:Vai.Reset)
        Write-Host ("    MAC     : " + $mac)
        Write-Host ("    Speed   : " + [Math]::Round($iface.Speed / 1MB, 0) + " Mbps")

        $ipProps = $iface.GetIPProperties()
        foreach ($uni in $ipProps.UnicastAddresses) {
            $family = if ($uni.Address.AddressFamily -eq "InterNetworkV6") { "IPv6" } else { "IPv4" }
            $maskStr = ""
            if ($family -eq "IPv4" -and $uni.IPv4Mask) { $maskStr = " / " + $uni.IPv4Mask }
            Write-Host ("    $family    : " + $global:Vai.Green + $uni.Address + $maskStr + $global:Vai.Reset)
        }
        foreach ($gw in $ipProps.GatewayAddresses) {
            Write-Host ("    Gateway : " + $global:Vai.Yellow + $gw.Address + $global:Vai.Reset)
        }
    }
    Write-Host ""
}

function script:Invoke-NetHttp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Urls,
        [switch]$Headers,
        [int]$Timeout = 0
    )

    $cfg = Get-VaiNetConfig
    if ($Timeout -le 0) { $Timeout = [int](Get-VaiValue $cfg "DefaultTimeout" 3000) }
    $timeoutSec = [Math]::Max(1, [Math]::Round($Timeout / 1000))

    Write-VaiHeader "HTTP CHECK"
    foreach ($url in $Urls) {
        if ($url -notmatch '^https?://') { $url = "https://" + $url }
        Write-Host ("  " + $global:Vai.Blue + "  $url" + $global:Vai.Reset)
        try {
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri $url -Method HEAD -UseBasicParsing -TimeoutSec $timeoutSec -ErrorAction Stop
            $timer.Stop()
            $code = [int]$response.StatusCode
            $color = if ($code -ge 400) { $global:Vai.Red } elseif ($code -ge 300) { $global:Vai.Yellow } else { $global:Vai.Green }
            Write-Host ("    Status : " + $color + $code + " " + $response.StatusDescription + $global:Vai.Reset)
            Write-Host ("    Time   : " + $timer.ElapsedMilliseconds + " ms")
            if ($Headers) {
                foreach ($key in $response.Headers.Keys) {
                    Write-Host ("    " + $global:Vai.Gray + "$key`: $($response.Headers[$key])" + $global:Vai.Reset)
                }
            }
        }
        catch {
            Write-Host ("    " + $global:Vai.Red + "ERROR: $($_.Exception.Message)" + $global:Vai.Reset)
        }
        Write-VaiSeparator
    }
    Write-Host ""
}

function script:Invoke-NetScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Subnet,
        [int]$From = 1,
        [int]$To = 254,
        [int]$Timeout = 500
    )

    $Subnet = $Subnet.TrimEnd(".")
    $total = $To - $From + 1
    Write-Host ""
    Write-Host ("  " + $global:Vai.Cyan + "SUBNET SCAN: $Subnet.x ($From-$To)" + $global:Vai.Reset)
    Write-VaiSeparator

    $alive = @()
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $tasks = @()
    for ($i = $From; $i -le $To; $i++) {
        $ip = "$Subnet.$i"
        $ping = New-Object System.Net.NetworkInformation.Ping
        $tasks += [PSCustomObject]@{ IP = $ip; Task = $ping.SendPingAsync($ip, $Timeout); Ping = $ping }
    }

    foreach ($item in $tasks) {
        try {
            $item.Task.Wait()
            $reply = $item.Task.Result
            if ($reply.Status -eq "Success") {
                $hostName = ""
                try {
                    $entry = [System.Net.Dns]::GetHostEntry($item.IP)
                    if ($entry.HostName -ne $item.IP) { $hostName = $entry.HostName }
                } catch {}
                Write-Host ("  " + $global:Vai.Green + "  [ALIVE] $($item.IP.PadRight(16)) $($reply.RoundtripTime) ms  $hostName" + $global:Vai.Reset)
                $alive += $item.IP
            }
        }
        catch {}
        finally { $item.Ping.Dispose() }
    }

    $timer.Stop()
    Write-VaiSeparator
    Write-Host ("  Found: " + $global:Vai.Green + $alive.Count + $global:Vai.Reset + " / $total in $([Math]::Round($timer.Elapsed.TotalSeconds,1))s")
    Write-Host ""
}

function script:Invoke-NetMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]]$Hosts,
        [int]$Interval = 0,
        [int]$Timeout = 0
    )

    $cfg = Get-VaiNetConfig
    if ($Interval -le 0) { $Interval = [int](Get-VaiValue $cfg "MonitorInterval" 5) }
    if ($Timeout -le 0)  { $Timeout  = [int](Get-VaiValue $cfg "DefaultTimeout" 3000) }

    Write-Host ""
    Write-Host ("  " + $global:Vai.Cyan + "MONITOR: $($Hosts -join ', ') every ${Interval}s" + $global:Vai.Reset)
    Write-Host ("  " + $global:Vai.Gray + "Ctrl+C to stop" + $global:Vai.Reset)
    Write-VaiSeparator

    $iteration = 0
    try {
        while ($true) {
            $iteration++
            $timestamp = (Get-Date).ToString("HH:mm:ss")
            $line = "  " + $global:Vai.Gray + $timestamp + $global:Vai.Reset + " "
            foreach ($target in $Hosts) {
                try {
                    $ping = New-Object System.Net.NetworkInformation.Ping
                    $reply = $ping.Send($target, $Timeout)
                    if ($reply.Status -eq "Success") {
                        $ms = $reply.RoundtripTime
                        $color = $global:Vai.Green
                        if ($ms -gt 100) { $color = $global:Vai.Yellow }
                        if ($ms -gt 300) { $color = $global:Vai.Red }
                        $line += $color + "${target}:${ms}ms" + $global:Vai.Reset + "  "
                    }
                    else {
                        $line += $global:Vai.Red + "${target}:DOWN" + $global:Vai.Reset + "  "
                    }
                    $ping.Dispose()
                }
                catch {
                    $line += $global:Vai.Red + "${target}:ERR" + $global:Vai.Reset + "  "
                }
            }
            Write-Host $line
            Start-Sleep -Seconds $Interval
        }
    }
    catch {}
    Write-Host ""
    Write-VaiWarn "Monitor stopped after $iteration iterations."
}

function script:Invoke-NetSpeed {
    [CmdletBinding()]
    param(
        [string]$Url = "https://speed.hetzner.de/10MB.bin",
        [double]$SizeMB = 10
    )

    Write-VaiHeader "DOWNLOAD SPEED TEST"
    Write-Host "  URL: $Url"
    Write-Host ("  " + $global:Vai.Yellow + "  Downloading..." + $global:Vai.Reset)

    try {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ("vai-speed-" + [guid]::NewGuid().ToString("N") + ".tmp")
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($Url, $tempFile)
        $timer.Stop()
        $elapsed = $timer.Elapsed.TotalSeconds
        $realMB = [Math]::Round((Get-Item $tempFile).Length / 1MB, 2)
        $speedMBps = if ($elapsed -gt 0) { [Math]::Round($realMB / $elapsed, 2) } else { 0 }
        $speedMbits = [Math]::Round($speedMBps * 8, 2)
        $color = if ($speedMbits -gt 50) { $global:Vai.Green } elseif ($speedMbits -gt 10) { $global:Vai.Yellow } else { $global:Vai.Red }
        Write-Host ("  " + $global:Vai.Green + "  Downloaded: $realMB MB in $([Math]::Round($elapsed,1))s" + $global:Vai.Reset)
        Write-Host ("  " + $color + "  Speed: $speedMBps MB/s ($speedMbits Mbit/s)" + $global:Vai.Reset)
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        $wc.Dispose()
    }
    catch {
        Write-VaiError $_.Exception.Message
    }
    Write-Host ""
}

function script:Invoke-NetHelp {
    Write-Host ""
    Write-Host ("  " + $global:Vai.Cyan + "VAI-NET — network toolkit" + $global:Vai.Reset)
    Write-Host "  vai-ping / net:ping <hosts>       Ping"
    Write-Host "  vai-port / net:port <host> ...    Ports"
    Write-Host "  vai-dns / net:dns <targets>       DNS"
    Write-Host "  vai-trace / net:trace <host>      Traceroute"
    Write-Host "  vai-iface / net:iface             Interfaces"
    Write-Host "  vai-http / net:http <urls>        HTTP check"
    Write-Host "  vai-scan / net:scan <subnet>      Subnet sweep"
    Write-Host "  vai-monitor / net:monitor <hosts> Live monitor"
    Write-Host "  vai-speed / net:speed             Speed test"
    Write-Host "  Invoke-Vai Net ping 1.1.1.1       Script API"
    Write-Host ""
}

