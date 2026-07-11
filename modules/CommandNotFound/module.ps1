# ==============================================================================
# CommandNotFound v1.3 — VAI-FRAMEWORK
# ==============================================================================

Get-VaiModulePartFiles -ModuleRoot $PSScriptRoot | ForEach-Object { . $_ }

$reg = if ($global:VaiModule) { $global:VaiModule.RegistryKey } else { "Cnf" }
$pfx = if ($global:VaiModule) { $global:VaiModule.Prefix } else { "cnf" }

Register-VaiExport -Module $reg -Name suggest -ScriptBlock ${function:Invoke-CNFSuggest} -Alias "vai-suggest" -Prefix $pfx
Register-VaiExport -Module $reg -Name enable  -ScriptBlock ${function:Enable-CNF} -Alias "Enable-CommandNotFound" -Prefix $pfx
Register-VaiExport -Module $reg -Name disable -ScriptBlock ${function:Disable-CNF} -Alias "Disable-CommandNotFound" -Prefix $pfx
Register-VaiExport -Module $reg -Name history -ScriptBlock ${function:Invoke-CNFHistory} -Alias "vai-misses" -Prefix $pfx
Register-VaiExport -Module $reg -Name miss    -ScriptBlock ${function:Invoke-CNFMiss} -Alias "vai-miss" -Prefix $pfx

$autoEnable = $true
if ($script:CNF_Settings -and (Test-VaiProperty $script:CNF_Settings "AutoEnable")) {
    $autoEnable = [bool]$script:CNF_Settings.AutoEnable
}
if ($autoEnable) { Enable-CNF }
