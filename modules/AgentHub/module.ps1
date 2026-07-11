# ==============================================================================
# AgentHub v1.2 — VAI-FRAMEWORK
# ==============================================================================

Get-VaiModulePartFiles -ModuleRoot $PSScriptRoot | ForEach-Object { . $_ }

$reg = if ($global:VaiModule) { $global:VaiModule.RegistryKey } else { "Ai" }
$pfx = if ($global:VaiModule) { $global:VaiModule.Prefix } else { "ai" }

Register-VaiExport -Module $reg -Name ai -ScriptBlock ${function:Invoke-Ai} -Alias ai -Prefix $pfx
