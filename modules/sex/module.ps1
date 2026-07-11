# ==============================================================================
# SEX — Script EXecutor v1.0 (VAI-FRAMEWORK v5.1)
# Slogan: Ship. Execute. eXcite.
# ==============================================================================

Get-VaiModulePartFiles -ModuleRoot $PSScriptRoot | ForEach-Object { . $_ }

$reg = if ($global:VaiModule) { $global:VaiModule.RegistryKey } else { "Sex" }
$pfx = if ($global:VaiModule) { $global:VaiModule.Prefix } else { "sex" }

Register-VaiExport -Module $reg -Name sex -ScriptBlock ${function:Invoke-Sex} -Alias sex -Prefix $pfx
