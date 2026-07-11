# ==============================================================================
# VAI-NET — multi-file module (v5.1)
# ==============================================================================

Get-VaiModulePartFiles -ModuleRoot $PSScriptRoot | ForEach-Object { . $_ }

$reg = if ($global:VaiModule) { $global:VaiModule.RegistryKey } else { "Net" }
$pfx = if ($global:VaiModule) { $global:VaiModule.Prefix } else { "net" }

Register-VaiExport -Module $reg -Name ping    -ScriptBlock ${function:Invoke-NetPing}    -Alias "vai-ping"    -Prefix $pfx
Register-VaiExport -Module $reg -Name port    -ScriptBlock ${function:Invoke-NetPort}    -Alias "vai-port"    -Prefix $pfx
Register-VaiExport -Module $reg -Name dns     -ScriptBlock ${function:Invoke-NetDns}     -Alias "vai-dns"     -Prefix $pfx
Register-VaiExport -Module $reg -Name trace   -ScriptBlock ${function:Invoke-NetTrace}   -Alias "vai-trace"   -Prefix $pfx
Register-VaiExport -Module $reg -Name iface   -ScriptBlock ${function:Invoke-NetIface}   -Alias "vai-iface"   -Prefix $pfx
Register-VaiExport -Module $reg -Name http    -ScriptBlock ${function:Invoke-NetHttp}    -Alias "vai-http"    -Prefix $pfx
Register-VaiExport -Module $reg -Name scan    -ScriptBlock ${function:Invoke-NetScan}    -Alias "vai-scan"    -Prefix $pfx
Register-VaiExport -Module $reg -Name monitor -ScriptBlock ${function:Invoke-NetMonitor} -Alias "vai-monitor" -Prefix $pfx
Register-VaiExport -Module $reg -Name speed   -ScriptBlock ${function:Invoke-NetSpeed}   -Alias "vai-speed"   -Prefix $pfx
Register-VaiExport -Module $reg -Name help    -ScriptBlock ${function:Invoke-NetHelp}    -Alias "vai-net"     -Prefix $pfx
