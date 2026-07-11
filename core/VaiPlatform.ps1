# ==============================================================================
# VAI-FRAMEWORK v5 :: Platform abstraction (Windows / Linux / macOS)
# ==============================================================================

function global:Get-VaiOS {
    if ($global:Vai.IsWindows) { return "Windows" }
    if ($global:Vai.IsMacOS)   { return "macOS" }
    if ($global:Vai.IsLinux)   { return "Linux" }
    return "Unknown"
}

function global:Get-VaiHomePath {
    if ($env:HOME) { return $env:HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    return [Environment]::GetFolderPath("UserProfile")
}

function global:Get-VaiConfigDir {
    $homePath = Get-VaiHomePath
    if ($global:Vai.IsWindows) {
        $base = $env:APPDATA
        if (-not $base) { $base = Join-Path $homePath "AppData\Roaming" }
        return (Join-Path $base "vai")
    }
    return (Join-Path $homePath ".config\vai")
}

function global:Test-VaiCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )
    # Avoid CommandNotFoundAction noise: query Application/Cmdlet only with silent
    $prev = $ExecutionContext.InvokeCommand.CommandNotFoundAction
    try {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $null
        return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
    }
    finally {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $prev
    }
}

function global:Get-VaiTool {
    <#
    .SYNOPSIS
        Resolve a tool binary: optional tools map, then PATH.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [hashtable]$Map
    )

    if ($Map -and $Map.ContainsKey($Name) -and $Map[$Name]) {
        $candidate = [string]$Map[$Name]
        if (Test-VaiCommand $candidate) { return $candidate }
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    $prev = $ExecutionContext.InvokeCommand.CommandNotFoundAction
    try {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $null
        $cmd = Get-Command -Name $Name -ErrorAction SilentlyContinue
        if ($cmd) {
            if ($cmd.Source) { return $cmd.Source }
            return $cmd.Name
        }
    }
    finally {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $prev
    }
    return $null
}

function global:Assert-VaiCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [string]$Hint
    )

    if (Test-VaiCommand $Name) { return $true }

    $msg = "Command not found: $Name"
    if ($Hint) { $msg += " — $Hint" }
    Write-VaiError $msg
    return $false
}

function global:Invoke-VaiNative {
    <#
    .SYNOPSIS
        Run an external process with argv array (no shell injection).
    .OUTPUTS
        PSCustomObject: ExitCode, StdOut, StdErr, DurationMs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$FilePath,

        [Parameter(Position = 1)]
        [string[]]$ArgumentList = @(),

        [string]$WorkingDirectory,

        [int]$TimeoutMs = 0,

        [hashtable]$Environment
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }

    # PS 5.1: Arguments as single string; PS Core: ArgumentList preferred
    if ($ArgumentList -and $ArgumentList.Count -gt 0) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            foreach ($a in $ArgumentList) { [void]$psi.ArgumentList.Add($a) }
        }
        else {
            $psi.Arguments = ($ArgumentList | ForEach-Object {
                if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
            }) -join ' '
        }
    }

    if ($Environment) {
        foreach ($key in $Environment.Keys) {
            $psi.Environment[$key] = [string]$Environment[$key]
        }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi

    try {
        [void]$proc.Start()
        if ($TimeoutMs -gt 0) {
            if (-not $proc.WaitForExit($TimeoutMs)) {
                try { $proc.Kill() } catch {}
                $sw.Stop()
                return [PSCustomObject]@{
                    ExitCode   = -1
                    StdOut     = ""
                    StdErr     = "Timeout after ${TimeoutMs}ms"
                    DurationMs = $sw.ElapsedMilliseconds
                    TimedOut   = $true
                }
            }
        }
        else {
            $proc.WaitForExit()
        }

        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $sw.Stop()

        return [PSCustomObject]@{
            ExitCode   = $proc.ExitCode
            StdOut     = $stdout
            StdErr     = $stderr
            DurationMs = $sw.ElapsedMilliseconds
            TimedOut   = $false
        }
    }
    finally {
        if ($proc) { $proc.Dispose() }
    }
}

function global:Open-VaiUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Url
    )

    try {
        if ($global:Vai.IsWindows) {
            Start-Process $Url
        }
        elseif ($global:Vai.IsMacOS) {
            Start-Process "open" -ArgumentList $Url
        }
        else {
            if (Test-VaiCommand "xdg-open") {
                Start-Process "xdg-open" -ArgumentList $Url
            }
            else {
                Write-VaiWarn "Cannot open URL (no xdg-open): $Url"
                return
            }
        }
    }
    catch {
        Write-VaiWarn ("Open URL failed: " + $_.Exception.Message)
    }
}

function global:Open-VaiPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-VaiWarn "Path not found: $Path"
        return
    }

    try {
        if ($global:Vai.IsWindows) {
            Start-Process explorer.exe -ArgumentList $Path
        }
        elseif ($global:Vai.IsMacOS) {
            Start-Process "open" -ArgumentList $Path
        }
        else {
            if (Test-VaiCommand "xdg-open") {
                Start-Process "xdg-open" -ArgumentList $Path
            }
        }
    }
    catch {
        Write-VaiWarn ("Open path failed: " + $_.Exception.Message)
    }
}

function global:Test-VaiAdmin {
    if ($global:Vai.IsWindows) {
        try {
            $p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch { return $false }
    }

    # Unix: root?
    try {
        if (Test-VaiCommand "id") {
            $r = Invoke-VaiNative -FilePath "id" -ArgumentList @("-u")
            if ($r.ExitCode -eq 0 -and ($r.StdOut.Trim() -eq "0")) { return $true }
        }
    }
    catch {}
    return $false
}
