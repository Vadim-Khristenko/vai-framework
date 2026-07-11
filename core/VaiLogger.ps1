# ==============================================================================
# VAI-FRAMEWORK v5 :: File logging with levels
# ==============================================================================

function global:Write-VaiLog {
    [CmdletBinding()]
    param(
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",

        [Parameter(Mandatory)]
        [string]$Message,

        [switch]$NoConsole
    )

    $minLevel = $global:VaiMinLogLevel
    if ($global:Vai -and $global:Vai.LogLevel) { $minLevel = $global:Vai.LogLevel }

    $threshold = $global:VaiLogLevels[$minLevel]
    $current   = $global:VaiLogLevels[$Level]
    if ($null -eq $threshold) { $threshold = 1 }
    if ($null -eq $current) { $current = 1 }

    if ($current -lt $threshold) { return }

    try {
        $stamp = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
        $line  = "[$stamp] [$($Level.PadRight(5))] $Message"

        $logPath = $global:VaiLogPath
        if ($global:Vai -and $global:Vai.LogPath) { $logPath = $global:Vai.LogPath }

        $dir = Split-Path -Parent $logPath
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $sw = [System.IO.StreamWriter]::new($logPath, $true, [System.Text.Encoding]::UTF8)
        try {
            $sw.WriteLine($line)
        }
        finally {
            $sw.Dispose()
        }
    }
    catch {
        # locked / no permissions — soft degrade
    }

    if (-not $NoConsole -and $current -ge $global:VaiLogLevels["WARN"]) {
        $colors = if ($global:Vai -and $global:Vai.Colors) { $global:Vai.Colors } else { @{ Red = ""; Yellow = ""; Reset = "" } }
        $color = if ($Level -eq "ERROR") { $colors.Red } else { $colors.Yellow }
        Write-Host ("  " + $color + "[" + $Level + "]" + $colors.Reset + " " + $Message)
    }
}
