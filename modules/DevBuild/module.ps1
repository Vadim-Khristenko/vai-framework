# ==============================================================================
# DevBuild v1.0 — VAI-FRAMEWORK
# ==============================================================================

Get-VaiModulePartFiles -ModuleRoot $PSScriptRoot | ForEach-Object { . $_ }

$reg = if ($global:VaiModule) { $global:VaiModule.RegistryKey } else { "Db" }
$pfx = if ($global:VaiModule) { $global:VaiModule.Prefix } else { "db" }

Register-VaiExport -Module $reg -Name db -ScriptBlock ${function:Invoke-Db} -Alias db -Prefix $pfx
