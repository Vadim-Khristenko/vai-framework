#Requires -Version 5.1
<#
.SYNOPSIS
  Fix common git/GPG/safe.directory issues and push VAI-Framework to GitHub.

.DESCRIPTION
  Use when:
  - "gpg failed to sign the data"
  - "dubious ownership" / safe.directory
  - remote missing / push failed
  - tag v* not on origin

.EXAMPLE
  pwsh -NoProfile -File .\scripts\fix-git-and-push.ps1
  pwsh -NoProfile -File .\scripts\fix-git-and-push.ps1 -SkipPush
  pwsh -NoProfile -File .\scripts\fix-git-and-push.ps1 -Tag v5.1.3
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),

    [string]$RemoteUrl = "https://github.com/Vadim-Khristenko/vai-framework.git",

    [string]$Branch = "main",

    # Optional: create/push this tag after push (e.g. v5.1.4)
    [string]$Tag = "",

    [switch]$SkipPush,

    [switch]$SkipSmoke,

    # Disable GPG for this run only (default: keep signing on if gpg works)
    [switch]$NoGpgSign
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Msg) {
    Write-Host ""
    Write-Host "==> $Msg" -ForegroundColor Cyan
}

function Write-Ok([string]$Msg) { Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Write-Err([string]$Msg) { Write-Host "  [X] $Msg" -ForegroundColor Red }

Write-Host ""
Write-Host "VAI git fix-and-push" -ForegroundColor Magenta
Write-Host "Root: $RepoRoot"

if (-not (Test-Path -LiteralPath $RepoRoot)) {
    Write-Err "Repo root not found: $RepoRoot"
    exit 1
}

Set-Location -LiteralPath $RepoRoot

# --- tools ---
Write-Step "Check tools"
foreach ($t in @("git", "gh")) {
    if (-not (Get-Command $t -ErrorAction SilentlyContinue)) {
        Write-Err "Missing command: $t"
        exit 1
    }
    Write-Ok "$t → $((Get-Command $t).Source)"
}

# --- safe.directory (fixes SYSTEM-owned folders / dubious ownership) ---
Write-Step "safe.directory"
$safeList = @(git config --global --get-all safe.directory 2>$null)
if ($safeList -notcontains $RepoRoot -and $safeList -notcontains ($RepoRoot -replace '\\', '/')) {
    git config --global --add safe.directory $RepoRoot
    # also unix-style path for some git builds
    $unix = $RepoRoot -replace '\\', '/'
    if ($unix -ne $RepoRoot) {
        git config --global --add safe.directory $unix 2>$null
    }
    Write-Ok "Added safe.directory $RepoRoot"
}
else {
    Write-Ok "safe.directory already set"
}

# --- ensure git repo ---
Write-Step "Repository"
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot ".git"))) {
    git init -b $Branch
    Write-Ok "git init -b $Branch"
}
else {
    Write-Ok "Already a git repo"
}

# --- identity (local only if missing) ---
Write-Step "Commit identity (local)"
$email = git config user.email 2>$null
$name = git config user.name 2>$null
# Always normalize identity for this repo
git config user.email "vadim@vai-rice.space"
git config user.name "Vadim Khristenko"
Write-Ok "user.name = Vadim Khristenko"
Write-Ok "user.email = vadim@vai-rice.space"

# --- GPG ---
Write-Step "GPG signing"
if ($NoGpgSign) {
    git config commit.gpgsign false
    git config tag.gpgsign false
    Write-Warn "GPG disabled for this repo (-NoGpgSign)"
}
else {
    git config commit.gpgsign true
    git config tag.gpgsign true
    Write-Ok "commit.gpgsign=true / tag.gpgsign=true"
    Write-Host "  If sign fails: re-run with -NoGpgSign or unlock gpg-agent" -ForegroundColor DarkGray
}

# --- remote ---
Write-Step "Remote origin"
$existing = git remote get-url origin 2>$null
if (-not $existing) {
    git remote add origin $RemoteUrl
    Write-Ok "Added origin → $RemoteUrl"
}
elseif ($existing -ne $RemoteUrl) {
    Write-Warn "origin is $existing"
    $ans = Read-Host "  Reset origin to $RemoteUrl ? (y/N)"
    if ($ans -match '^[yY]') {
        git remote set-url origin $RemoteUrl
        Write-Ok "origin updated"
    }
}
else {
    Write-Ok "origin → $existing"
}

# --- smoke ---
if (-not $SkipSmoke) {
    Write-Step "Smoke tests"
    $smoke = Join-Path $RepoRoot "tests\Smoke-Vai.ps1"
    if (Test-Path $smoke) {
        & pwsh -NoProfile -File $smoke
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Smoke failed (exit $LASTEXITCODE). Fix tests or re-run with -SkipSmoke"
            exit $LASTEXITCODE
        }
        Write-Ok "Smoke passed"
    }
    else {
        Write-Warn "No tests/Smoke-Vai.ps1 — skip"
    }
}
else {
    Write-Warn "Smoke skipped (-SkipSmoke)"
}

# --- status / commit if dirty ---
Write-Step "Working tree"
git status -sb
$dirty = git status --porcelain
if ($dirty) {
    Write-Warn "Uncommitted changes detected"
    $ans = Read-Host "  git add -A && commit? (y/N)"
    if ($ans -match '^[yY]') {
        git add -A
        $msg = Read-Host "  Commit message (empty = chore: sync local changes)"
        if ([string]::IsNullOrWhiteSpace($msg)) { $msg = "chore: sync local changes" }
        if ($NoGpgSign) {
            git -c commit.gpgsign=false commit --no-gpg-sign -m $msg
        }
        else {
            git commit -m $msg
        }
        Write-Ok "Committed"
    }
    else {
        Write-Warn "Left uncommitted — push may still work for existing commits"
    }
}
else {
    Write-Ok "Clean working tree"
}

if ($SkipPush) {
    Write-Ok "Done (-SkipPush). No network push."
    exit 0
}

# --- gh auth ---
Write-Step "GitHub auth"
gh auth status 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Err "gh not logged in. Run: gh auth login"
    exit 1
}

# --- ensure repo exists ---
Write-Step "Ensure GitHub repo exists"
$repoCheck = gh api repos/Vadim-Khristenko/vai-framework --jq .full_name 2>$null
if (-not $repoCheck) {
    Write-Warn "Repo not found — creating public Vadim-Khristenko/vai-framework"
    gh api user/repos `
        -f name=vai-framework `
        -f description="VAI-Framework — hybrid-registry PowerShell toolkit. Ship. Execute. eXcite." `
        -F private=false `
        -F has_issues=true `
        -F has_wiki=false | Out-Null
    Write-Ok "Repo created"
}
else {
    Write-Ok "Repo: $repoCheck"
}

# --- push branch ---
Write-Step "Push $Branch"
$branchNow = git rev-parse --abbrev-ref HEAD
if ($branchNow -ne $Branch) {
    Write-Warn "Current branch is '$branchNow' (expected $Branch)"
}

git push -u origin HEAD:${Branch}
if ($LASTEXITCODE -ne 0) {
    Write-Err "git push failed. Retry later or check network/credentials."
    Write-Host "  Manual: git push -u origin $Branch" -ForegroundColor DarkGray
    exit $LASTEXITCODE
}
Write-Ok "Pushed $Branch"

# --- optional tag ---
if ($Tag) {
    Write-Step "Tag $Tag"
    if (-not ($Tag -match '^v\d+')) {
        Write-Warn "Tag should look like v5.1.3 (got $Tag)"
    }
    $exists = git tag -l $Tag
    if (-not $exists) {
        if ($NoGpgSign) {
            git -c tag.gpgsign=false tag -a $Tag -m "VAI-Framework $Tag"
        }
        else {
            git tag -a $Tag -m "VAI-Framework $Tag"
        }
        Write-Ok "Created local tag $Tag"
    }
    else {
        Write-Ok "Tag $Tag already exists locally"
    }
    git push origin $Tag
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Pushed tag $Tag (Release workflow should run)"
    }
    else {
        Write-Err "Tag push failed — run: git push origin $Tag"
        exit $LASTEXITCODE
    }
}

Write-Host ""
Write-Host "All set." -ForegroundColor Green
Write-Host "  Repo:    https://github.com/Vadim-Khristenko/vai-framework"
Write-Host "  Actions: https://github.com/Vadim-Khristenko/vai-framework/actions"
Write-Host "  Release: https://github.com/Vadim-Khristenko/vai-framework/releases"
Write-Host ""
