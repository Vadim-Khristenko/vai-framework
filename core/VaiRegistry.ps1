# ==============================================================================
# VAI-FRAMEWORK v5 :: Export registry (short + prefix + API)
# ==============================================================================

# Internal bookkeeping for clean reload
$script:VaiRegistryMeta = @{
    # key: "Module/Name" → @{ Module; Name; Alias; Prefix; PrefixFn; AliasFn; ScriptBlock; Lazy }
    Exports = @{}
    Proxies = [System.Collections.Generic.List[string]]::new()  # function names to remove
}

function script:Get-VaiRegistryKey {
    param([string]$Module, [string]$Name)
    return ($Module + "/" + $Name)
}

function script:Test-VaiColonFunctions {
    # Probe whether function names with ':' work on this host
    $probe = "__vai_probe_colon_test__"
    $fn = "vai_probe:test"
    try {
        Set-Item -Path ("function:" + $fn) -Value { "ok" } -Force -ErrorAction Stop
        $cmd = Get-Command $fn -ErrorAction SilentlyContinue
        Remove-Item -Path ("function:" + $fn) -ErrorAction SilentlyContinue
        return [bool]$cmd
    }
    catch {
        Remove-Item -Path ("function:" + $fn) -ErrorAction SilentlyContinue
        return $false
    }
}

function global:Initialize-VaiRegistry {
    [CmdletBinding()]
    param()

    if (Test-VaiColonFunctions) {
        $global:Vai.PrefixStyle = "Colon"
    }
    else {
        $global:Vai.PrefixStyle = "Slash"
    }

    if (-not $global:Vai.M) { $global:Vai.M = @{} }
    Write-VaiLog -Level DEBUG -Message ("Registry PrefixStyle=" + $global:Vai.PrefixStyle) -NoConsole
}

function script:Get-VaiPrefixFunctionName {
    param([string]$Prefix, [string]$Name)

    if ($global:Vai.PrefixStyle -eq "Slash") {
        return ($Prefix + "/" + $Name)
    }
    return ($Prefix + ":" + $Name)
}

function script:New-VaiProxyScriptBlock {
    param(
        [string]$Module,
        [string]$Name
    )

    # Proxy captures module/name and dispatches through Invoke-Vai
    $sb = {
        param()
        $mod = $Module
        $cmd = $Name
        # $args from caller
        Invoke-Vai -Module $mod -Command $cmd @args
    }.GetNewClosure()

    return $sb
}

function script:New-VaiLazyStubScriptBlock {
    param(
        [string]$Module,
        [string]$Name,
        [string]$ScriptPath,
        [string]$RegistryKey
    )

    $sb = {
        param()
        $mod = $Module
        $cmd = $Name
        $path = $ScriptPath
        $rkey = $RegistryKey

        Write-VaiLog -Level INFO -Message ("Lazy-load module '" + $mod + "' via " + $cmd) -NoConsole

        # Remove stubs for this module before real load
        Clear-VaiModuleProxies -Module $rkey

        $global:VaiModule = $global:VaiModulesCache | Where-Object {
            $_.RegistryKey -eq $rkey -or $_.Name -eq $mod -or $_.Prefix -eq $mod
        } | Select-Object -First 1

        if (-not $global:VaiModule) {
            Write-VaiError ("Lazy module context missing for " + $mod)
            return
        }

        try {
            . $path
            $global:VaiModule.Status = "Loaded"
        }
        catch {
            $global:VaiModule.Status = "Failed"
            Write-VaiError ("Lazy load failed '" + $mod + "': " + $_.Exception.Message)
            Write-VaiLog -Level ERROR -Message $_.Exception.Message
            return
        }
        finally {
            $global:VaiModule = $null
        }

        Invoke-Vai -Module $rkey -Command $cmd @args
    }.GetNewClosure()

    return $sb
}

function global:Clear-VaiModuleProxies {
    [CmdletBinding()]
    param([string]$Module)

    $toRemove = @($script:VaiRegistryMeta.Exports.Keys | Where-Object {
        $script:VaiRegistryMeta.Exports[$_].Module -eq $Module
    })

    foreach ($k in $toRemove) {
        $meta = $script:VaiRegistryMeta.Exports[$k]
        if ($meta.PrefixFn) {
            Remove-Item -Path ("function:" + $meta.PrefixFn) -ErrorAction SilentlyContinue
        }
        if ($meta.AliasFn) {
            Remove-Item -Path ("function:global:" + $meta.AliasFn) -ErrorAction SilentlyContinue
            Remove-Item -Path ("function:" + $meta.AliasFn) -ErrorAction SilentlyContinue
        }
        [void]$script:VaiRegistryMeta.Exports.Remove($k)
    }

    if ($global:Vai.M.ContainsKey($Module)) {
        $global:Vai.M.Remove($Module)
    }
}

function global:Clear-VaiRegistry {
    [CmdletBinding()]
    param()

    foreach ($k in @($script:VaiRegistryMeta.Exports.Keys)) {
        $meta = $script:VaiRegistryMeta.Exports[$k]
        if ($meta.PrefixFn) {
            Remove-Item -Path ("function:" + $meta.PrefixFn) -ErrorAction SilentlyContinue
        }
        if ($meta.AliasFn) {
            Remove-Item -Path ("function:global:" + $meta.AliasFn) -ErrorAction SilentlyContinue
            Remove-Item -Path ("function:" + $meta.AliasFn) -ErrorAction SilentlyContinue
        }
    }

    $script:VaiRegistryMeta.Exports = @{}
    $script:VaiRegistryMeta.Proxies = [System.Collections.Generic.List[string]]::new()
    $global:Vai.M = @{}
}

function global:Register-VaiExport {
    <#
    .SYNOPSIS
        Register a module export into $Vai.M, prefix:cmd, and optional short alias.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [string]$Alias,

        [string]$Prefix,

        [switch]$Lazy,

        [string]$ScriptPath
    )

    if (-not $Alias) { $Alias = $Name }

    # Resolve prefix from loaded module manifest if missing
    if (-not $Prefix) {
        $m = $global:VaiModulesCache | Where-Object {
            $_.RegistryKey -eq $Module -or $_.Name -eq $Module -or $_.Prefix -eq $Module
        } | Select-Object -First 1
        if ($m) { $Prefix = $m.Prefix; if ($m.RegistryKey) { $Module = $m.RegistryKey } }
        else { $Prefix = $Module.ToLower() }
    }

    $shortAliases = $true
    $m2 = $global:VaiModulesCache | Where-Object { $_.RegistryKey -eq $Module -or $_.Name -eq $Module } | Select-Object -First 1
    if ($m2 -and ($null -ne $m2.ShortAliases)) { $shortAliases = [bool]$m2.ShortAliases }

    $rkey = Get-VaiRegistryKey -Module $Module -Name $Name
    $prefixFn = Get-VaiPrefixFunctionName -Prefix $Prefix -Name $Name

    $effectiveSb = $ScriptBlock
    if ($Lazy -and $ScriptPath) {
        $effectiveSb = New-VaiLazyStubScriptBlock -Module $Module -Name $Name -ScriptPath $ScriptPath -RegistryKey $Module
    }

    # $Vai.M.Module.Name
    if (-not $global:Vai.M.ContainsKey($Module)) {
        $global:Vai.M[$Module] = @{}
    }
    $global:Vai.M[$Module][$Name] = $effectiveSb

    # Prefix function
    try {
        Set-Item -Path ("function:" + $prefixFn) -Value $effectiveSb -Force -ErrorAction Stop
    }
    catch {
        Write-VaiLog -Level WARN -Message ("Cannot bind prefix fn '" + $prefixFn + "': " + $_.Exception.Message)
        $prefixFn = $null
    }

    # Short alias
    $aliasFn = $null
    if ($shortAliases -and $Alias) {
        try {
            Set-Item -Path ("function:global:" + $Alias) -Value $effectiveSb -Force -ErrorAction Stop
            $aliasFn = $Alias
        }
        catch {
            try {
                Set-Item -Path ("function:" + $Alias) -Value $effectiveSb -Force -ErrorAction Stop
                $aliasFn = $Alias
            }
            catch {
                Write-VaiLog -Level WARN -Message ("Cannot bind alias '" + $Alias + "': " + $_.Exception.Message)
            }
        }
    }

    $script:VaiRegistryMeta.Exports[$rkey] = @{
        Module      = $Module
        Name        = $Name
        Alias       = $Alias
        Prefix      = $Prefix
        PrefixFn    = $prefixFn
        AliasFn     = $aliasFn
        ScriptBlock = $effectiveSb
        Lazy        = [bool]$Lazy
    }

    Write-VaiLog -Level DEBUG -Message ("Export " + $Module + "." + $Name + " prefix=" + $prefixFn + " alias=" + $aliasFn) -NoConsole
}

function global:Register-VaiLazyExports {
    <#
    .SYNOPSIS
        Install lazy stubs for all declared Exports of a module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest
    )

    $exports = @($Manifest.Exports)
    if ($exports.Count -eq 0 -and $Manifest.LazyTriggers) {
        $exports = @($Manifest.LazyTriggers)
    }

    foreach ($ex in $exports) {
        $name = [string]$ex
        if (-not $name) { continue }

        # Avoid collisions on generic names while stubbed (real module rebinds aliases)
        $alias = $name
        if ($name -eq 'help') {
            $alias = $Manifest.Prefix + '-help'
        }

        # Placeholder; real load replaces
        Register-VaiExport `
            -Module $Manifest.RegistryKey `
            -Name $name `
            -ScriptBlock { } `
            -Alias $alias `
            -Prefix $Manifest.Prefix `
            -Lazy `
            -ScriptPath $Manifest.ScriptPath
    }
}

function global:Invoke-Vai {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Module,

        [Parameter(Mandatory, Position = 1)]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments = $true)]
        $RemainingArguments
    )

    # Normalize module key
    $modKey = $Module
    if (-not $global:Vai.M.ContainsKey($modKey)) {
        # try match by prefix or name in cache
        $found = $global:VaiModulesCache | Where-Object {
            $_.RegistryKey -eq $Module -or $_.Name -eq $Module -or $_.Prefix -eq $Module
        } | Select-Object -First 1
        if ($found) { $modKey = $found.RegistryKey }
    }

    if (-not $global:Vai.M.ContainsKey($modKey)) {
        Write-VaiError ("Module not in registry: " + $Module)
        return
    }

    $bucket = $global:Vai.M[$modKey]
    if (-not $bucket.ContainsKey($Command)) {
        Write-VaiError ("Export not found: " + $modKey + "." + $Command)
        return
    }

    $sb = $bucket[$Command]
    if ($null -eq $RemainingArguments) {
        & $sb
    }
    else {
        # splat remaining
        $argArray = @($RemainingArguments)
        & $sb @argArray
    }
}

function global:Get-VaiExport {
    [CmdletBinding()]
    param(
        [string]$Module,
        [string]$Name
    )

    if ($Module -and $Name) {
        $k = Get-VaiRegistryKey -Module $Module -Name $Name
        if ($script:VaiRegistryMeta.Exports.ContainsKey($k)) {
            return [PSCustomObject]$script:VaiRegistryMeta.Exports[$k]
        }
        # try resolve registry key
        $found = $global:VaiModulesCache | Where-Object {
            $_.Name -eq $Module -or $_.Prefix -eq $Module -or $_.RegistryKey -eq $Module
        } | Select-Object -First 1
        if ($found) {
            $k2 = Get-VaiRegistryKey -Module $found.RegistryKey -Name $Name
            if ($script:VaiRegistryMeta.Exports.ContainsKey($k2)) {
                return [PSCustomObject]$script:VaiRegistryMeta.Exports[$k2]
            }
        }
        return $null
    }

    $list = foreach ($k in ($script:VaiRegistryMeta.Exports.Keys | Sort-Object)) {
        [PSCustomObject]$script:VaiRegistryMeta.Exports[$k]
    }
    if ($Module) {
        return $list | Where-Object {
            $_.Module -eq $Module -or $_.Prefix -eq $Module
        }
    }
    return $list
}

function global:Get-VaiModule {
    [CmdletBinding()]
    param([string]$Name)

    if ($Name) {
        return $global:VaiModulesCache | Where-Object {
            $_.Name -like "*$Name*" -or $_.Prefix -eq $Name -or $_.RegistryKey -eq $Name
        }
    }
    return @($global:VaiModulesCache)
}

function global:Test-VaiModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$Loaded
    )

    $m = Get-VaiModule -Name $Name | Select-Object -First 1
    if (-not $m) { return $false }
    if ($Loaded) { return ($m.Status -eq "Loaded") }
    return $true
}
