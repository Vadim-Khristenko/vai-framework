# ==============================================================================
# GitTweaks v1.3 — core commands
# ==============================================================================

function script:Test-GitReady {
    if (-not (Test-VaiCommand git)) {
        Write-VaiError "git not found in PATH."
        return $false
    }
    return $true
}

function script:Test-InGitRepo {
    if (-not (Test-GitReady)) { return $false }
    git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-VaiWarn "Not inside a git repository."
        return $false
    }
    return $true
}

$script:GT_CommitTypes = [ordered]@{
    "feat"     = "New feature"
    "fix"      = "Bug fix"
    "docs"     = "Documentation"
    "style"    = "Formatting only"
    "refactor" = "Refactor"
    "perf"     = "Performance"
    "test"     = "Tests"
    "build"    = "Build / deps"
    "ci"       = "CI/CD"
    "chore"    = "Chore"
    "revert"   = "Revert"
}

function script:Invoke-GitGs {
    if (-not (Test-InGitRepo)) { return }
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    $porcelain = @(git status --porcelain 2>$null)
    $root = git rev-parse --show-toplevel 2>$null

    Write-VaiBanner -Title "GIT STATUS" -Subtitle $root -Color Cyan
    Write-Host ("  " + (Write-VaiPill "branch" "hot") + "  " + $global:Vai.Green + $branch + $global:Vai.Reset)

    $ahead = git rev-list --count "@{u}..HEAD" 2>$null
    $behind = git rev-list --count "HEAD..@{u}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $bits = @()
        if ([int]$ahead -gt 0)  { $bits += (Write-VaiPill "↑$ahead" "ok") }
        if ([int]$behind -gt 0) { $bits += (Write-VaiPill "↓$behind" "fail") }
        if ($bits.Count -eq 0) { $bits += (Write-VaiPill "synced" "ok") }
        Write-Host ("  " + ($bits -join " "))
    }

    if (-not $porcelain -or $porcelain.Count -eq 0) {
        Write-VaiRule
        Write-Host ("  " + (Write-VaiPill "clean" "ok") + "  Working tree clean.")
        Write-Host ""
        return
    }

    $staged = 0; $mod = 0; $neu = 0; $del = 0
    Write-VaiRule -Label "changes"
    foreach ($line in $porcelain) {
        if ($line.Length -lt 4) { continue }
        $x = $line.Substring(0, 1)
        $y = $line.Substring(1, 1)
        $file = $line.Substring(3)
        if ($x -ne ' ' -and $x -ne '?') {
            $staged++; Write-Host ("  " + (Write-VaiPill "staged" "ok") + "  " + $file)
        }
        elseif ($y -eq 'M') {
            $mod++; Write-Host ("  " + (Write-VaiPill "mod" "info") + "     " + $global:Vai.Yellow + $file + $global:Vai.Reset)
        }
        elseif ($line -like '??*') {
            $neu++; Write-Host ("  " + (Write-VaiPill "new" "hot") + "     " + $global:Vai.Red + $file + $global:Vai.Reset)
        }
        elseif ($y -eq 'D' -or $x -eq 'D') {
            $del++; Write-Host ("  " + (Write-VaiPill "del" "fail") + "     " + $file)
        }
        else {
            Write-Host ("  " + (Write-VaiPill "??" "dim") + "      " + $file)
        }
    }
    Write-VaiRule
    Write-Host ("  " +
        (Write-VaiPill "n $($porcelain.Count)" "info") + " " +
        (Write-VaiPill "S $staged" "ok") + " " +
        (Write-VaiPill "M $mod" "info") + " " +
        (Write-VaiPill "? $neu" "hot") + " " +
        (Write-VaiPill "D $del" "fail"))
    Write-Host ""
}

function script:Invoke-GitGlg {
    param([int]$Count = 15)
    if (-not (Test-InGitRepo)) { return }
    Write-VaiBanner -Title "GIT LOG" -Subtitle ("last $Count") -Color Magenta
    git log --graph --abbrev-commit --decorate -n $Count `
        --format="%C(bold magenta)%h%C(reset) %C(dim white)%ar%C(reset) %C(green)%an%C(reset)%C(auto)%d%C(reset)%n  %s"
    Write-Host ""
}

function script:Invoke-GitGcommit {
    param([switch]$All)
    if (-not (Test-InGitRepo)) { return }

    $staged = git diff --cached --name-only 2>$null
    if (-not $staged -and -not $All) {
        Write-VaiWarn "Nothing staged. Use git add or -All."
        if (Confirm-VaiAction "Stage all changes?") { git add -A; $All = $true } else { return }
    }
    if ($All) { git add -A }

    Write-VaiBanner -Title "COMMIT" -Subtitle "Conventional Commits" -Color Green
    $types = @($script:GT_CommitTypes.Keys)
    for ($i = 0; $i -lt $types.Count; $i++) {
        $t = $types[$i]
        Write-Host ("    " + (Write-VaiPill ($i + 1) "info") + " " +
            $global:Vai.Green + $t.PadRight(10) + $global:Vai.Reset + " " +
            $global:Vai.Gray + $script:GT_CommitTypes[$t] + $global:Vai.Reset)
    }
    $sel = Read-Host "  Type number"
    if ($sel -notmatch '^\d+$' -or [int]$sel -lt 1 -or [int]$sel -gt $types.Count) {
        Write-VaiError "Invalid choice."; return
    }
    $type = $types[[int]$sel - 1]
    $scope = Read-Host "  Scope (optional)"
    $desc = Read-Host "  Short description"
    if ([string]::IsNullOrWhiteSpace($desc)) { Write-VaiError "Description required."; return }
    $breaking = Read-Host "  Breaking change? (y/N)"
    $isBreaking = $breaking -match '^[yYдД]'
    $body = Read-Host "  Body (optional)"

    $header = "$type"
    if ($scope) { $header += "($scope)" }
    if ($isBreaking) { $header += "!" }
    $header += ": $desc"

    $bodyParts = @()
    if ($body) { $bodyParts += $body }
    if ($isBreaking) {
        $breakingDesc = Read-Host "  Describe breaking change"
        $bodyParts += "BREAKING CHANGE: $breakingDesc"
    }
    $bodyText = $bodyParts -join "`n`n"

    Write-VaiBox -Title "PREVIEW" -Color Green -Lines (@($header) + $(if ($bodyText) { $bodyText -split "`n" } else { @() }))
    if (-not (Confirm-VaiAction "Create commit?" -DefaultYes)) {
        Write-Host ("  " + $global:Vai.Gray + "Cancelled." + $global:Vai.Reset); return
    }

    $commitArgs = @("commit", "-m", $header)
    if ($bodyText) { $commitArgs += @("-m", $bodyText) }
    & git @commitArgs
    if ($LASTEXITCODE -eq 0) {
        Write-VaiOk "Commit created."
        Write-VaiLog -Level INFO -Message "GitTweaks: $header"
    }
    else { Write-VaiError "Commit failed." }
}

function script:Invoke-GitGundo {
    if (-not (Test-InGitRepo)) { return }
    $last = git log -1 --format="%h %s" 2>$null
    if (-not $last) { Write-VaiWarn "No commits."; return }
    Write-VaiBanner -Title "UNDO" -Subtitle "soft reset HEAD~1" -Color Yellow
    Write-Host ("  " + $global:Vai.Yellow + $last + $global:Vai.Reset)
    if (-not (Confirm-VaiAction "Soft-reset last commit?")) { return }
    git reset --soft HEAD~1
    Write-VaiOk "Undone; changes staged."
}

function script:Invoke-GitGstats {
    if (-not (Test-InGitRepo)) { return }
    Write-VaiBanner -Title "REPO STATS" -Color Cyan
    $totalCommits = git rev-list --count HEAD 2>$null
    $branches = (git branch -a 2>$null | Measure-Object).Count
    $contributors = (git shortlog -sn HEAD 2>$null | Measure-Object).Count
    $firstCommit = git log --reverse --format="%ar" 2>$null | Select-Object -First 1
    Write-VaiKV "commits" $totalCommits
    Write-VaiKV "branches" $branches
    Write-VaiKV "authors" $contributors
    Write-VaiKV "first" $firstCommit
    Write-VaiRule -Label "top"
    git shortlog -sn HEAD 2>$null | Select-Object -First 5 | ForEach-Object {
        Write-Host ("  " + $global:Vai.Green + $_ + $global:Vai.Reset)
    }
    Write-Host ""
}

function script:Invoke-GitGpull {
    if (-not (Test-InGitRepo)) { return }
    Write-VaiBanner -Title "PULL" -Subtitle "ff-only preferred" -Color Blue
    git pull --ff-only 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-VaiWarn "ff-only failed; trying regular pull..."
        git pull
    }
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Pull done." } else { Write-VaiError "Pull failed." }
}

function script:Invoke-GitGpush {
    param([switch]$Force)
    if (-not (Test-InGitRepo)) { return }
    Write-VaiBanner -Title "PUSH" -Color Magenta
    if ($Force) {
        if (-not (Confirm-VaiAction "Force-with-lease push?")) { return }
        git push --force-with-lease
    }
    else {
        git push
        if ($LASTEXITCODE -ne 0) {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            Write-VaiWarn "Push failed — set upstream?"
            if (Confirm-VaiAction "git push -u origin $branch ?") {
                git push -u origin $branch
            }
        }
    }
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Push done." } else { Write-VaiError "Push failed." }
}

function script:Invoke-GitGco {
    param([Parameter(Position = 0)][string]$Branch)
    if (-not (Test-InGitRepo)) { return }
    if (-not $Branch) {
        $branches = @(git branch --format="%(refname:short)" 2>$null)
        $idx = Show-VaiMenu -Title "CHECKOUT" -Items $branches
        if ($idx -le 0) { return }
        $Branch = $branches[$idx - 1]
    }
    git checkout $Branch
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "On branch $Branch" } else { Write-VaiError "Checkout failed." }
}

function script:Invoke-GitGb {
    param(
        [Parameter(Position = 0)][string]$Name,
        [switch]$All,
        [switch]$Delete
    )
    if (-not (Test-InGitRepo)) { return }
    if ($Delete -and $Name) {
        if (Confirm-VaiAction "Delete branch $Name?") {
            git branch -d $Name
        }
        return
    }
    if ($Name) {
        git checkout -b $Name
        if ($LASTEXITCODE -eq 0) { Write-VaiOk "Created & switched to $Name" }
        return
    }
    Write-VaiBanner -Title "BRANCHES" -Color Cyan
    $args = @("branch", "-v")
    if ($All) { $args = @("branch", "-av") }
    & git @args
    Write-Host ""
}

function script:Invoke-GitGd {
    param([switch]$Staged, [int]$Stat)
    if (-not (Test-InGitRepo)) { return }
    Write-VaiBanner -Title "DIFF" -Color Yellow
    if ($Staged) { git diff --staged }
    elseif ($Stat -gt 0) { git diff --stat }
    else { git diff }
}

function script:Invoke-GitGstash {
    param(
        [ValidateSet("push", "pop", "list", "drop")]
        [string]$Action = "list",
        [string]$Message
    )
    if (-not (Test-InGitRepo)) { return }
    switch ($Action) {
        "push" {
            if ($Message) { git stash push -m $Message } else { git stash push }
            Write-VaiOk "Stashed."
        }
        "pop"  { git stash pop; Write-VaiOk "Popped." }
        "drop" { git stash drop; Write-VaiOk "Dropped." }
        default {
            Write-VaiBanner -Title "STASH" -Color Blue
            git stash list
            Write-Host ("  " + $global:Vai.Gray + "gstash push|pop|list|drop" + $global:Vai.Reset)
            Write-Host ""
        }
    }
}

function script:Invoke-GitGsync {
    if (-not (Test-InGitRepo)) { return }
    Write-VaiBanner -Title "SYNC" -Subtitle "fetch + status + pull ff" -Color Hot
    git fetch --all --prune 2>&1 | ForEach-Object { Write-Host ("  " + $global:Vai.Gray + $_ + $global:Vai.Reset) }
    Invoke-GitGs
    Write-VaiRule -Label "pull"
    git pull --ff-only 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) { Write-VaiOk "Sync complete." } else { Write-VaiWarn "Pull needs attention (non-ff?)." }
}

function script:Invoke-GitHelp {
    Write-VaiBanner -Title "GIT TWEAKS" -Subtitle "v1.3 power tools" -Color Cyan
    Write-VaiBox -Title "COMMANDS" -Color Green -Lines @(
        "gs / git:gs              Status TUI",
        "glg [N]                  Log graph",
        "gcommit [-All]           Conventional commit",
        "gundo                    Soft undo last commit",
        "gstats                   Repo stats",
        "gpull / gpush [-Force]   Sync remotes",
        "gco [branch]             Checkout (menu if empty)",
        "gb [name] [-All|-Delete] Branches",
        "gd [-Staged]             Diff",
        "gstash [push|pop|list]   Stash",
        "gsync                    fetch + status + pull",
        "Invoke-Vai Git gs        Script API"
    )
}
