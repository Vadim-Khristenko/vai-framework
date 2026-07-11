# ==============================================================================
# KubeTweaks v1.0 — VAI-FRAMEWORK
# ==============================================================================

Get-VaiModulePartFiles -ModuleRoot $PSScriptRoot | ForEach-Object { . $_ }

$reg = if ($global:VaiModule) { $global:VaiModule.RegistryKey } else { "K" }
$pfx = if ($global:VaiModule) { $global:VaiModule.Prefix } else { "k" }

# RegistryKey from prefix "k" → "K"
$exports = [ordered]@{
    kctx   = ${function:Invoke-KubeKctx}
    kns    = ${function:Invoke-KubeKns}
    kgp    = ${function:Invoke-KubeKgp}
    kgd    = ${function:Invoke-KubeKgd}
    kgs    = ${function:Invoke-KubeKgs}
    kgn    = ${function:Invoke-KubeKgn}
    klogs  = ${function:Invoke-KubeKlogs}
    ksh    = ${function:Invoke-KubeKsh}
    ktop   = ${function:Invoke-KubeKtop}
    kdesc  = ${function:Invoke-KubeKdesc}
    kapp   = ${function:Invoke-KubeKapp}
    kdel   = ${function:Invoke-KubeKdel}
    kwatch = ${function:Invoke-KubeKwatch}
    kpf    = ${function:Invoke-KubeKpf}
    kev    = ${function:Invoke-KubeKev}
    khelp  = ${function:Invoke-KubeHelp}
    help   = ${function:Invoke-KubeHelp}
}

foreach ($name in $exports.Keys) {
    $alias = if ($name -eq "help") { "kube-help" } else { $name }
    Register-VaiExport -Module $reg -Name $name -ScriptBlock $exports[$name] -Alias $alias -Prefix $pfx
}
