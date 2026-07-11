# DockerTweaks v1.5 — multi-file
Get-VaiModulePartFiles -ModuleRoot $PSScriptRoot | ForEach-Object { . $_ }

$reg = if ($global:VaiModule) { $global:VaiModule.RegistryKey } else { "Docker" }
$pfx = if ($global:VaiModule) { $global:VaiModule.Prefix } else { "docker" }

$exports = @{
    dps      = ${function:Invoke-DockerDps}
    dsh      = ${function:Invoke-DockerDsh}
    dlogs    = ${function:Invoke-DockerDlogs}
    dstats   = ${function:Invoke-DockerDstats}
    dclean   = ${function:Invoke-DockerDclean}
    dnuke    = ${function:Invoke-DockerDnuke}
    dup      = ${function:Invoke-DockerDup}
    ddown    = ${function:Invoke-DockerDdown}
    drestart = ${function:Invoke-DockerDrestart}
    dimg     = ${function:Invoke-DockerDimg}
    dvol     = ${function:Invoke-DockerDvol}
    dnet     = ${function:Invoke-DockerDnet}
    dtop     = ${function:Invoke-DockerDtop}
    dexec    = ${function:Invoke-DockerDexec}
    dbuild   = ${function:Invoke-DockerDbuild}
    dcp      = ${function:Invoke-DockerDcp}
    dports   = ${function:Invoke-DockerDports}
    dhealth  = ${function:Invoke-DockerDhealth}
    dprune   = ${function:Invoke-DockerDprune}
    dcmp     = ${function:Invoke-DockerDpsCompose}
    dclogs   = ${function:Invoke-DockerDlogsCompose}
    help     = ${function:Invoke-DockerHelp}
}

foreach ($name in $exports.Keys) {
    $alias = if ($name -eq "help") { "docker-help" } else { $name }
    Register-VaiExport -Module $reg -Name $name -ScriptBlock $exports[$name] -Alias $alias -Prefix $pfx
}
