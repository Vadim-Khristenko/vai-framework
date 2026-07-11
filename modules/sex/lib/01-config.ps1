# SEX config discovery + load

$script:SexSlogan = if ($global:Vai.Slogan -and $global:Vai.Slogan.Sex) {
    $global:Vai.Slogan.Sex
} else {
    "Ship. Execute. eXcite."
}

$script:SexBgJobs = [System.Collections.Generic.List[object]]::new()

function script:Get-SexSampleYaml {
    return @"
# SEX — Script EXecutor
# $($script:SexSlogan)
name: my-app
default: up

env:
  NODE_ENV: development

tools:
  bun: bun
  uv: uv
  cargo: cargo
  claude: claude
  grok: grok
  codex: codex
  opencode: opencode

targets:
  up:
    desc: "Spin up local dev"
    cwd: .
    run:
      - cmd: echo SEX is live — replace with docker compose / bun run dev
    open:
      - http://localhost:3000
    after: "You're in. $($script:SexSlogan)"

  test:
    desc: "Run the suite"
    run:
      - cmd: echo wire me to uv run pytest / cargo test / bun test

  ai:
    desc: "Launch AI agent via AgentHub if present"
    run:
      - cmd: echo prefer: ai run claude
"@
}

function script:Find-SexConfigPath {
    $cwd = (Get-Location).Path
    foreach ($name in @("sex.yaml", "sex.yml", "sex.json")) {
        $p = Join-Path $cwd $name
        if (Test-Path -LiteralPath $p) { return $p }
    }

    $root = Find-VaiProjectRoot -StartPath $cwd
    if ($root) {
        foreach ($name in @("sex.yaml", "sex.yml", "sex.json")) {
            $p = Join-Path $root $name
            if (Test-Path -LiteralPath $p) { return $p }
        }
    }

    $user = Join-Path (Get-VaiConfigDir) "sex.yaml"
    if (Test-Path -LiteralPath $user) { return $user }

    $fw = Join-Path $global:VaiFrameworkRoot "modules\sex\default.yaml"
    if (Test-Path -LiteralPath $fw) { return $fw }

    return $null
}

function script:Read-SexConfig {
    param([string]$Path)

    if (-not $Path) { return $null }

    if ($Path -match '\.json$') {
        return (Read-VaiJson $Path)
    }

    return (Read-VaiYaml -Path $Path)
}

function script:Get-SexMapValue {
    param($Object, [string]$Key, $Default = $null)
    return (Get-VaiValue $Object $Key $Default)
}

function script:Get-SexTargets {
    param($Config)
    $t = Get-SexMapValue $Config "targets" $null
    if ($null -eq $t) { return @{} }
    if ($t -is [hashtable]) { return $t }
    $h = @{}
    if ($t.PSObject -and $t.PSObject.Properties) {
        foreach ($p in $t.PSObject.Properties) { $h[$p.Name] = $p.Value }
    }
    return $h
}
