# KubeTweaks — core helpers

function script:Test-KubeReady {
    if (-not (Test-VaiCommand kubectl)) {
        Write-VaiError "kubectl not found in PATH."
        Write-Host ("  " + $global:Vai.Gray + "Install: https://kubernetes.io/docs/tasks/tools/" + $global:Vai.Reset)
        return $false
    }
    # cluster reachability — soft: allow offline cmds like kctx list from kubeconfig
    return $true
}

function script:Test-KubeCluster {
    if (-not (Test-KubeReady)) { return $false }
    $prev = $ExecutionContext.InvokeCommand.CommandNotFoundAction
    try {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $null
        kubectl cluster-info --request-timeout=3s 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-VaiWarn "kubectl present but cluster not reachable (check context/VPN)."
            return $false
        }
        return $true
    }
    finally {
        $ExecutionContext.InvokeCommand.CommandNotFoundAction = $prev
    }
}

function script:Get-KubeCurrentContext {
    kubectl config current-context 2>$null
}

function script:Get-KubeCurrentNamespace {
    $ctx = Get-KubeCurrentContext
    if (-not $ctx) { return "default" }
    $ns = kubectl config view --minify -o jsonpath='{..namespace}' 2>$null
    if ([string]::IsNullOrWhiteSpace($ns)) { return "default" }
    return $ns
}

function script:Invoke-Kubectl {
    param([string[]]$Args)
    & kubectl @Args
    return $LASTEXITCODE
}

function script:Select-KubePod {
    param(
        [string]$Name,
        [string]$Namespace
    )
    if (-not $Namespace) { $Namespace = Get-KubeCurrentNamespace }

    $fmt = "{{.metadata.name}}"
    $pods = @(kubectl get pods -n $Namespace -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>$null)
    $pods = @($pods | Where-Object { $_ -and $_.Trim() })
    if ($pods.Count -eq 0) {
        Write-VaiWarn "No pods in namespace '$Namespace'."
        return $null
    }

    if ($Name) {
        $hit = $pods | Where-Object { $_ -like "*$Name*" } | Select-Object -First 1
        if ($hit) { return [PSCustomObject]@{ Name = $hit; Namespace = $Namespace } }
        Write-VaiWarn "Pod matching '$Name' not found."
    }

    if ($pods.Count -eq 1) {
        return [PSCustomObject]@{ Name = $pods[0]; Namespace = $Namespace }
    }

    $idx = Show-VaiMenu -Title ("Pods · $Namespace") -Items $pods
    if ($idx -le 0) { return $null }
    return [PSCustomObject]@{ Name = $pods[$idx - 1]; Namespace = $Namespace }
}

function script:Write-KubeHeader {
    param([string]$Title, [string]$Subtitle)
    $ctx = Get-KubeCurrentContext
    $ns = Get-KubeCurrentNamespace
    $sub = if ($Subtitle) { $Subtitle } else { "ctx=$ctx · ns=$ns" }
    Write-VaiBanner -Title $Title -Subtitle $sub -Color Cyan
}
