# GitTweaks — multi-file (v1.3)
Get-VaiModulePartFiles -ModuleRoot $PSScriptRoot | ForEach-Object { . $_ }

$reg = if ($global:VaiModule) { $global:VaiModule.RegistryKey } else { "Git" }
$pfx = if ($global:VaiModule) { $global:VaiModule.Prefix } else { "git" }

Register-VaiExport -Module $reg -Name gs      -ScriptBlock ${function:Invoke-GitGs}      -Alias gs      -Prefix $pfx
Register-VaiExport -Module $reg -Name glg     -ScriptBlock ${function:Invoke-GitGlg}     -Alias glg     -Prefix $pfx
Register-VaiExport -Module $reg -Name gcommit -ScriptBlock ${function:Invoke-GitGcommit} -Alias gcommit -Prefix $pfx
Register-VaiExport -Module $reg -Name gundo   -ScriptBlock ${function:Invoke-GitGundo}   -Alias gundo   -Prefix $pfx
Register-VaiExport -Module $reg -Name gstats  -ScriptBlock ${function:Invoke-GitGstats}  -Alias gstats  -Prefix $pfx
Register-VaiExport -Module $reg -Name gpull   -ScriptBlock ${function:Invoke-GitGpull}   -Alias gpull   -Prefix $pfx
Register-VaiExport -Module $reg -Name gpush   -ScriptBlock ${function:Invoke-GitGpush}   -Alias gpush   -Prefix $pfx
Register-VaiExport -Module $reg -Name gco     -ScriptBlock ${function:Invoke-GitGco}     -Alias gco     -Prefix $pfx
Register-VaiExport -Module $reg -Name gb      -ScriptBlock ${function:Invoke-GitGb}      -Alias gb      -Prefix $pfx
Register-VaiExport -Module $reg -Name gd      -ScriptBlock ${function:Invoke-GitGd}      -Alias gd      -Prefix $pfx
Register-VaiExport -Module $reg -Name gstash  -ScriptBlock ${function:Invoke-GitGstash}  -Alias gstash  -Prefix $pfx
Register-VaiExport -Module $reg -Name gsync   -ScriptBlock ${function:Invoke-GitGsync}   -Alias gsync   -Prefix $pfx
Register-VaiExport -Module $reg -Name help    -ScriptBlock ${function:Invoke-GitHelp}    -Alias "git-help" -Prefix $pfx
