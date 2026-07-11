# KubeTweaks — commands

function script:Invoke-KubeKctx {
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$List
    )
    if (-not (Test-KubeReady)) { return }

    if ($List -or -not $Name) {
        Write-KubeHeader "CONTEXTS"
        $cur = Get-KubeCurrentContext
        $rows = @(kubectl config get-contexts -o name 2>$null)
        foreach ($c in $rows) {
            if ($c -eq $cur) {
                Write-Host ("  " + (Write-VaiPill "*" "hot") + " " + (Write-VaiPill "current" "ok") + " " + $global:Vai.Cyan + $c + $global:Vai.Reset)
            }
            else {
                Write-Host ("      " + $global:Vai.Gray + $c + $global:Vai.Reset)
            }
        }
        Write-Host ""
        Write-Host ("  " + $global:Vai.Gray + "Switch: kctx <name>" + $global:Vai.Reset)
        Write-Host ""
        return
    }

    kubectl config use-context $Name
    if ($LASTEXITCODE -eq 0) {
        Write-VaiOk "Context → $Name"
        Write-VaiKV "namespace" (Get-KubeCurrentNamespace)
    }
    else {
        Write-VaiError "Failed to switch context"
    }
}

function script:Invoke-KubeKns {
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$List
    )
    if (-not (Test-KubeReady)) { return }

    if ($List -or -not $Name) {
        Write-KubeHeader "NAMESPACES"
        $cur = Get-KubeCurrentNamespace
        $rows = @(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>$null)
        foreach ($n in $rows) {
            if (-not $n) { continue }
            if ($n -eq $cur) {
                Write-Host ("  " + (Write-VaiPill "*" "hot") + " " + (Write-VaiPill "current" "ok") + " " + $global:Vai.Green + $n + $global:Vai.Reset)
            }
            else {
                Write-Host ("      " + $n)
            }
        }
        Write-Host ""
        Write-Host ("  " + $global:Vai.Gray + "Set: kns <name>" + $global:Vai.Reset)
        Write-Host ""
        return
    }

    kubectl config set-context --current --namespace=$Name
    if ($LASTEXITCODE -eq 0) {
        Write-VaiOk "Namespace → $Name"
    }
    else {
        Write-VaiError "Failed to set namespace"
    }
}

function script:Invoke-KubeKgp {
    param(
        [string]$Namespace,
        [switch]$AllNamespaces,
        [string]$Label
    )
    if (-not (Test-KubeCluster)) { return }
    Write-KubeHeader "PODS"
    $args = @("get", "pods", "-o", "wide")
    if ($AllNamespaces) { $args += "-A" }
    elseif ($Namespace) { $args += @("-n", $Namespace) }
    if ($Label) { $args += @("-l", $Label) }
    & kubectl @args
}

function script:Invoke-KubeKgd {
    param([string]$Namespace, [switch]$AllNamespaces)
    if (-not (Test-KubeCluster)) { return }
    Write-KubeHeader "DEPLOYMENTS"
    $args = @("get", "deploy", "-o", "wide")
    if ($AllNamespaces) { $args += "-A" }
    elseif ($Namespace) { $args += @("-n", $Namespace) }
    & kubectl @args
}

function script:Invoke-KubeKgs {
    param([string]$Namespace, [switch]$AllNamespaces)
    if (-not (Test-KubeCluster)) { return }
    Write-KubeHeader "SERVICES"
    $args = @("get", "svc", "-o", "wide")
    if ($AllNamespaces) { $args += "-A" }
    elseif ($Namespace) { $args += @("-n", $Namespace) }
    & kubectl @args
}

function script:Invoke-KubeKgn {
    if (-not (Test-KubeCluster)) { return }
    Write-KubeHeader "NODES"
    kubectl get nodes -o wide
}

function script:Invoke-KubeKlogs {
    param(
        [string]$Name,
        [string]$Namespace,
        [int]$Tail = 100,
        [switch]$Follow,
        [string]$Container
    )
    if (-not (Test-KubeCluster)) { return }
    $pod = Select-KubePod -Name $Name -Namespace $Namespace
    if (-not $pod) { return }

    Write-KubeHeader "LOGS" "$($pod.Namespace)/$($pod.Name)"
    $args = @("logs", "-n", $pod.Namespace, $pod.Name, "--tail=$Tail")
    if ($Follow) { $args += "-f" }
    if ($Container) { $args += @("-c", $Container) }
    & kubectl @args
}

function script:Invoke-KubeKsh {
    param(
        [string]$Name,
        [string]$Namespace,
        [string]$Shell = "",
        [string]$Container
    )
    if (-not (Test-KubeCluster)) { return }
    $pod = Select-KubePod -Name $Name -Namespace $Namespace
    if (-not $pod) { return }

    Write-Host ("  " + (Write-VaiPill "exec" "hot") + " " + $pod.Namespace + "/" + $pod.Name)
    $args = @("exec", "-it", "-n", $pod.Namespace, $pod.Name)
    if ($Container) { $args += @("-c", $Container) }
    $args += "--"
    if ($Shell) {
        $args += $Shell
    }
    else {
        $args += @("sh", "-c", "command -v bash >/dev/null && exec bash || exec sh")
    }
    & kubectl @args
}

function script:Invoke-KubeKtop {
    param(
        [ValidateSet("pods", "nodes")]
        [string]$What = "pods",
        [string]$Namespace,
        [switch]$AllNamespaces
    )
    if (-not (Test-KubeCluster)) { return }
    Write-KubeHeader "TOP" $What
    if ($What -eq "nodes") {
        kubectl top nodes
        return
    }
    $args = @("top", "pods")
    if ($AllNamespaces) { $args += "-A" }
    elseif ($Namespace) { $args += @("-n", $Namespace) }
    & kubectl @args
}

function script:Invoke-KubeKdesc {
    param(
        [Parameter(Position = 0)]
        [string]$Kind = "pod",
        [Parameter(Position = 1)]
        [string]$Name,
        [string]$Namespace
    )
    if (-not (Test-KubeCluster)) { return }
    if (-not $Name) {
        if ($Kind -eq "pod" -or $Kind -eq "pods") {
            $pod = Select-KubePod -Namespace $Namespace
            if (-not $pod) { return }
            $Name = $pod.Name
            $Namespace = $pod.Namespace
            $Kind = "pod"
        }
        else {
            Write-VaiWarn "Usage: kdesc <kind> <name> [-Namespace x]"
            return
        }
    }
    Write-KubeHeader "DESCRIBE" "$Kind/$Name"
    $args = @("describe", $Kind, $Name)
    if ($Namespace) { $args += @("-n", $Namespace) }
    & kubectl @args
}

function script:Invoke-KubeKapp {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$File,
        [switch]$DryRun
    )
    if (-not (Test-KubeReady)) { return }
    if (-not (Test-Path -LiteralPath $File)) {
        Write-VaiError "File not found: $File"
        return
    }
    Write-KubeHeader "APPLY" $File
    $args = @("apply", "-f", $File)
    if ($DryRun) { $args += "--dry-run=client" }
    & kubectl @args
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Applied." } else { Write-VaiError "Apply failed." }
}

function script:Invoke-KubeKdel {
    param(
        [Parameter(Position = 0)]
        [string]$Kind = "pod",
        [Parameter(Position = 1)]
        [string]$Name,
        [string]$Namespace,
        [switch]$Force
    )
    if (-not (Test-KubeCluster)) { return }
    if (-not $Name) {
        Write-VaiWarn "Usage: kdel <kind> <name> [-Namespace x] [-Force]"
        return
    }
    if (-not (Confirm-VaiAction "Delete $Kind/$Name ?" -Force:$Force)) {
        Write-VaiWarn "Cancelled."
        return
    }
    $args = @("delete", $Kind, $Name)
    if ($Namespace) { $args += @("-n", $Namespace) }
    if ($Force) { $args += @("--force", "--grace-period=0") }
    & kubectl @args
}

function script:Invoke-KubeKwatch {
    param(
        [string]$Namespace,
        [switch]$AllNamespaces
    )
    if (-not (Test-KubeCluster)) { return }
    Write-KubeHeader "WATCH PODS" "Ctrl+C to stop"
    $args = @("get", "pods", "-w")
    if ($AllNamespaces) { $args += "-A" }
    elseif ($Namespace) { $args += @("-n", $Namespace) }
    & kubectl @args
}

function script:Invoke-KubeKpf {
    param(
        [Parameter(Position = 0)]
        [string]$Name,
        [Parameter(Position = 1)]
        [string]$Ports = "8080:80",
        [string]$Namespace
    )
    if (-not (Test-KubeCluster)) { return }
    $pod = Select-KubePod -Name $Name -Namespace $Namespace
    if (-not $pod) { return }
    Write-KubeHeader "PORT-FORWARD" "$($pod.Name) · $Ports"
    Write-Host ("  " + $global:Vai.Gray + "Ctrl+C to stop" + $global:Vai.Reset)
    kubectl port-forward -n $pod.Namespace "pod/$($pod.Name)" $Ports
}

function script:Invoke-KubeKev {
    param(
        [string]$Namespace,
        [switch]$AllNamespaces
    )
    if (-not (Test-KubeCluster)) { return }
    Write-KubeHeader "EVENTS"
    $args = @("get", "events", "--sort-by=.lastTimestamp")
    if ($AllNamespaces) { $args += "-A" }
    elseif ($Namespace) { $args += @("-n", $Namespace) }
    & kubectl @args
}

function script:Invoke-KubeHelp {
    $ctx = if (Test-VaiCommand kubectl) { Get-KubeCurrentContext } else { "(no kubectl)" }
    $ns = if (Test-VaiCommand kubectl) { Get-KubeCurrentNamespace } else { "-" }
    Write-VaiBanner -Title "KUBE TWEAKS" -Subtitle "v1.0 · $ctx / $ns" -Color Cyan
    Write-VaiBox -Title "COMMANDS" -Color Blue -Lines @(
        "kctx [name] [-List]         Contexts / switch",
        "kns  [name] [-List]         Namespace / set",
        "kgp  [-AllNamespaces]       Get pods",
        "kgd / kgs / kgn             Deployments / svc / nodes",
        "klogs [pod] [-Follow]       Logs (picker)",
        "ksh  [pod]                  Shell into pod",
        "ktop [pods|nodes]           Resource top",
        "kdesc [kind] [name]         Describe",
        "kapp <file> [-DryRun]       kubectl apply -f",
        "kdel <kind> <name>          Delete (confirm)",
        "kwatch                      Watch pods",
        "kpf  [pod] [local:remote]   Port-forward",
        "kev                         Events",
        "Invoke-Vai K kgp            Script API"
    )
}
