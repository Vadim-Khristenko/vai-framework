# ==============================================================================
# VAI-FRAMEWORK v5 :: Global state, colors, OS flags
# ==============================================================================

$global:VaiCoreVersion = "5.2.0"

if (-not $global:VaiFrameworkRoot) {
    $global:VaiFrameworkRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

$global:VaiLogPath = Join-Path $global:VaiFrameworkRoot "logs\vai-core.log"

# ------------------------------------------------------------------
# Engine / OS capabilities (do not clobber PS7 automatic $IsWindows)
# ------------------------------------------------------------------
$global:VaiPSMajor  = if ($PSVersionTable.PSVersion) { $PSVersionTable.PSVersion.Major } else { 5 }
$global:VaiIsCore   = ($PSVersionTable.PSEdition -eq "Core")
$global:VaiIsModern = ($global:VaiIsCore -or $global:VaiPSMajor -ge 5)

$script:DetectedWindows = $false
$script:DetectedLinux   = $false
$script:DetectedMacOS   = $false

if ($global:VaiIsCore) {
    if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) { $script:DetectedWindows = [bool]$IsWindows }
    if (Get-Variable -Name IsLinux   -ErrorAction SilentlyContinue) { $script:DetectedLinux   = [bool]$IsLinux }
    if (Get-Variable -Name IsMacOS   -ErrorAction SilentlyContinue) { $script:DetectedMacOS   = [bool]$IsMacOS }
}
else {
    $script:DetectedWindows = ($env:OS -eq "Windows_NT")
}

$global:VaiIsWindows = $script:DetectedWindows
$global:VaiIsLinux   = $script:DetectedLinux
$global:VaiIsMacOS   = $script:DetectedMacOS

# ------------------------------------------------------------------
# ANSI palette
# ------------------------------------------------------------------
if ($global:VaiIsModern) {
    $e = [char]27
    $script:VaiColorMap = @{
        Magenta = "$e[38;5;201m"
        Cyan    = "$e[38;5;45m"
        Green   = "$e[38;5;82m"
        Yellow  = "$e[38;5;220m"
        Red     = "$e[38;5;196m"
        Gray    = "$e[38;5;244m"
        Blue    = "$e[38;5;39m"
        Reset   = "$e[0m"
    }
}
else {
    $script:VaiColorMap = @{
        Magenta = ""; Cyan = ""; Green = ""; Yellow = ""
        Red = ""; Gray = ""; Blue = ""; Reset = ""
    }
}

# ------------------------------------------------------------------
# Root object $Vai — single entry for modules & scripts
# ------------------------------------------------------------------
$global:Vai = @{
    Version     = $global:VaiCoreVersion
    Root        = $global:VaiFrameworkRoot
    LogPath     = $global:VaiLogPath
    LogLevel    = "INFO"
    PrefixStyle = "Colon"   # Colon | Slash — refined at registry init
    IsWindows   = $global:VaiIsWindows
    IsLinux     = $global:VaiIsLinux
    IsMacOS     = $global:VaiIsMacOS
    IsCore      = $global:VaiIsCore
    IsModern    = $global:VaiIsModern
    PSMajor     = $global:VaiPSMajor
    Colors      = $script:VaiColorMap
    M           = @{}       # $Vai.M.Git.gs → scriptblock
    Modules     = [System.Collections.Generic.List[PSCustomObject]]::new()
    Slogan      = @{
        Sex = "Ship. Execute. eXcite."
    }
    # Convenience color keys (same refs as Colors)
    Magenta = $script:VaiColorMap.Magenta
    Cyan    = $script:VaiColorMap.Cyan
    Green   = $script:VaiColorMap.Green
    Yellow  = $script:VaiColorMap.Yellow
    Red     = $script:VaiColorMap.Red
    Gray    = $script:VaiColorMap.Gray
    Blue    = $script:VaiColorMap.Blue
    Reset   = $script:VaiColorMap.Reset
}

# Bridge: old code used $global:Vai["Cyan"]
# Hashtable already supports that.

# Legacy color aliases (soft-deprecated)
$global:VAI_Magenta = $script:VaiColorMap.Magenta
$global:VAI_Cyan    = $script:VaiColorMap.Cyan
$global:VAI_Green   = $script:VaiColorMap.Green
$global:VAI_Yellow  = $script:VaiColorMap.Yellow
$global:VAI_Red     = $script:VaiColorMap.Red
$global:VAI_Gray    = $script:VaiColorMap.Gray
$global:VAI_Blue    = $script:VaiColorMap.Blue
$global:VAI_Reset   = $script:VaiColorMap.Reset

# Module cache list (CLI / summary) — also mirrored on $Vai.Modules
$global:VaiModulesCache = $global:Vai.Modules

$global:VaiLogLevels   = @{ DEBUG = 0; INFO = 1; WARN = 2; ERROR = 3 }
$global:VaiMinLogLevel = "INFO"
$global:Vai.LogLevel   = $global:VaiMinLogLevel
