# ==============================================================================
# VAI-FRAMEWORK v5.1 :: Auto-update scaffolding (ready for public release)
# ==============================================================================

# Defaults — override via env VAI_UPDATE_URL / VAI_UPDATE_REPO or $Vai.Update
if (-not $global:Vai.Update) {
    $global:Vai.Update = @{
        Enabled     = $true
        Channel     = "stable"                          # stable | edge
        # Set when published, e.g. https://api.github.com/repos/you/vai/releases/latest
        ManifestUrl = $env:VAI_UPDATE_URL
        # Or "owner/repo" for GitHub Releases API
        Repo        = $env:VAI_UPDATE_REPO
        CheckOnBoot = $false                            # optional quiet check
        LastCheck   = $null
        RemoteVersion = $null
        Status      = "unpublished"                     # unpublished | current | available | error
    }
}

function global:Get-VaiUpdateConfig {
    if (-not $global:Vai.Update) {
        $global:Vai.Update = @{ Enabled = $true; Channel = "stable"; Status = "unpublished" }
    }
    return $global:Vai.Update
}

function global:Get-VaiRemoteManifest {
    <#
    .SYNOPSIS
        Fetch remote version manifest. Returns $null if not configured / offline.
    .NOTES
        Expected JSON: { "version": "5.2.0", "channel": "stable", "url": "...", "notes": "..." }
        Or GitHub release: tag_name / html_url / body
    #>
    [CmdletBinding()]
    param()

    $cfg = Get-VaiUpdateConfig
    if (-not $cfg.Enabled) { return $null }

    $url = $cfg.ManifestUrl
    if (-not $url -and $cfg.Repo) {
        $url = "https://api.github.com/repos/$($cfg.Repo)/releases/latest"
    }

    if (-not $url) {
        $cfg.Status = "unpublished"
        return $null
    }

    try {
        $headers = @{ "User-Agent" = "VAI-Framework/$($global:VaiCoreVersion)" }
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 12 -ErrorAction Stop

        # Normalize GitHub release vs custom manifest
        if ($resp.tag_name) {
            $ver = ($resp.tag_name -replace '^v', '')
            return [PSCustomObject]@{
                version = $ver
                channel = $cfg.Channel
                url     = $resp.html_url
                notes   = $resp.body
                raw     = $resp
            }
        }

        return [PSCustomObject]@{
            version = $resp.version
            channel = $(if ($resp.channel) { $resp.channel } else { $cfg.Channel })
            url     = $resp.url
            notes   = $resp.notes
            raw     = $resp
        }
    }
    catch {
        $cfg.Status = "error"
        Write-VaiLog -Level DEBUG -Message ("Update check failed: " + $_.Exception.Message) -NoConsole
        return $null
    }
}

function global:Compare-VaiVersion {
    param([string]$A, [string]$B)
    try {
        $va = [version]($A -replace '[^\d.].*', '' -replace '^\.', '0.')
        $vb = [version]($B -replace '[^\d.].*', '' -replace '^\.', '0.')
        return $va.CompareTo($vb)
    }
    catch {
        return [string]::CompareOrdinal($A, $B)
    }
}

function global:Test-VaiUpdate {
    <#
    .SYNOPSIS
        Check whether a newer version is available. Safe no-op if unpublished.
    #>
    [CmdletBinding()]
    param([switch]$Quiet)

    $cfg = Get-VaiUpdateConfig
    $cfg.LastCheck = Get-Date

    $remote = Get-VaiRemoteManifest
    if (-not $remote -or -not $remote.version) {
        $cfg.Status = "unpublished"
        $cfg.RemoteVersion = $null
        if (-not $Quiet) {
            Write-VaiBox -Title "VAI UPDATE" -Color Yellow -Lines @(
                "No remote channel configured yet.",
                "Local: v$($global:VaiCoreVersion)",
                "Set `$env:VAI_UPDATE_REPO = 'owner/repo'",
                "  or  `$env:VAI_UPDATE_URL  = 'https://.../manifest.json'",
                "Feature is ready — nothing to pull until publish."
            )
        }
        return [PSCustomObject]@{
            Available = $false
            Status    = $cfg.Status
            Local     = $global:VaiCoreVersion
            Remote    = $null
        }
    }

    $cfg.RemoteVersion = $remote.version
    $cmp = Compare-VaiVersion -A $global:VaiCoreVersion -B $remote.version

    if ($cmp -lt 0) {
        $cfg.Status = "available"
        if (-not $Quiet) {
            Write-VaiBox -Title "UPDATE AVAILABLE" -Color Magenta -Lines @(
                "Local : v$($global:VaiCoreVersion)",
                "Remote: v$($remote.version)",
                "URL   : $($remote.url)",
                "Run   : vai-update  (guided)"
            )
        }
        return [PSCustomObject]@{
            Available = $true
            Status    = "available"
            Local     = $global:VaiCoreVersion
            Remote    = $remote
        }
    }

    $cfg.Status = "current"
    if (-not $Quiet) {
        Write-VaiOk "Already on latest (v$($global:VaiCoreVersion))."
    }
    return [PSCustomObject]@{
        Available = $false
        Status    = "current"
        Local     = $global:VaiCoreVersion
        Remote    = $remote
    }
}

function global:Update-Vai {
    <#
    .SYNOPSIS
        Guided update. Until published: explains how to wire the channel.
        When available: opens release URL / prints install hints (no silent overwrite of user tree by default).
    #>
    [CmdletBinding()]
    param(
        [switch]$CheckOnly,
        [switch]$Force
    )

    Write-VaiBanner -Title "vai-update" -Subtitle "Stay sharp. Ship often." -Color Cyan

    $result = Test-VaiUpdate -Quiet
    if ($CheckOnly) { return $result }

    if ($result.Status -eq "unpublished") {
        Write-Host ""
        Write-Host ("  " + $global:Vai.Cyan + "When you publish to GitHub:" + $global:Vai.Reset)
        Write-Host "    1. Create releases with tags vX.Y.Z"
        Write-Host "    2. Set env VAI_UPDATE_REPO=you/vai-framework"
        Write-Host "    3. vai-update will detect and guide pull"
        Write-Host ""
        return $result
    }

    if (-not $result.Available -and -not $Force) {
        Write-VaiOk "Nothing to update."
        return $result
    }

    $remote = $result.Remote
    Write-Host ""
    Write-VaiKV "Remote" $remote.version
    if ($remote.url) {
        Write-VaiKV "Release" $remote.url
        if (Confirm-VaiAction "Open release page in browser?" -DefaultYes) {
            Open-VaiUrl $remote.url
        }
    }

    Write-Host ""
    Write-Host ("  " + $global:Vai.Yellow + "Auto-replace of local tree is opt-in later (safety)." + $global:Vai.Reset)
    Write-Host ("  " + $global:Vai.Gray + "For now: pull/release download is manual or via your git remote." + $global:Vai.Reset)
    Write-Host ""

    return $result
}

function global:vai-update {
    [CmdletBinding()]
    param(
        [switch]$Check,
        [switch]$Force
    )
    if ($Check) { Update-Vai -CheckOnly -Force:$Force }
    else { Update-Vai -Force:$Force }
}
