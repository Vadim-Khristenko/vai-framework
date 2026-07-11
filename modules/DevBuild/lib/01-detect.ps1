# DevBuild — stack detection + tool resolve

$script:DevBuildPresets = $null

function script:Get-DevProjectRoot {
    $root = Find-VaiProjectRoot
    if ($root) { return $root }
    return (Get-Location).Path
}

function script:Detect-DevStacks {
    param([string]$Root)

    $stacks = [System.Collections.Generic.List[object]]::new()

    $checks = @(
        @{ Id = "cargo";  File = "Cargo.toml";      Tool = "cargo";  Name = "Rust (cargo)" }
        @{ Id = "bun";    File = "bun.lockb";       Tool = "bun";    Name = "Bun" }
        @{ Id = "bun";    File = "bun.lock";        Tool = "bun";    Name = "Bun" }
        @{ Id = "pnpm";   File = "pnpm-lock.yaml";  Tool = "pnpm";   Name = "pnpm" }
        @{ Id = "yarn";   File = "yarn.lock";       Tool = "yarn";   Name = "Yarn" }
        @{ Id = "npm";    File = "package.json";    Tool = "npm";    Name = "Node (npm)" }
        @{ Id = "uv";     File = "uv.lock";         Tool = "uv";     Name = "Python (uv)" }
        @{ Id = "uv";     File = "pyproject.toml";  Tool = "uv";     Name = "Python (uv/pyproject)" }
        @{ Id = "poetry"; File = "poetry.lock";     Tool = "poetry"; Name = "Poetry" }
        @{ Id = "go";     File = "go.mod";          Tool = "go";     Name = "Go" }
        @{ Id = "dotnet"; File = "*.sln";           Tool = "dotnet"; Name = ".NET" }
        @{ Id = "dotnet"; File = "*.csproj";        Tool = "dotnet"; Name = ".NET (csproj)" }
        @{ Id = "make";   File = "Makefile";        Tool = "make";   Name = "Make" }
        @{ Id = "cmake";  File = "CMakeLists.txt";  Tool = "cmake";  Name = "CMake" }
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($c in $checks) {
        $path = Join-Path $Root $c.File
        $hit = $false
        if ($c.File -match '[\*\?]') {
            $hit = [bool](Get-ChildItem -LiteralPath $Root -Filter $c.File -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        }
        else {
            $hit = Test-Path -LiteralPath $path
        }
        if (-not $hit) { continue }
        if (-not $seen.Add($c.Id)) { continue }

        $bin = Get-VaiTool -Name $c.Tool
        $stacks.Add([PSCustomObject]@{
            Id      = $c.Id
            Name    = $c.Name
            Tool    = $c.Tool
            Present = [bool]$bin
            Path    = $bin
            Marker  = $c.File
        })
    }

    # package.json without lock → npm still valid if not already added via lock
    # (already handled by npm check)

    return @($stacks)
}

function script:Get-DevPresetMap {
    # action → stack → argv list (first element = tool name key)
    return @{
        build = @{
            cargo  = @("cargo", "build")
            bun    = @("bun", "run", "build")
            npm    = @("npm", "run", "build")
            pnpm   = @("pnpm", "run", "build")
            yarn   = @("yarn", "build")
            uv     = @("uv", "build")
            poetry = @("poetry", "build")
            go     = @("go", "build", "./...")
            dotnet = @("dotnet", "build")
            make   = @("make")
            cmake  = @("cmake", "--build", "build")
        }
        test = @{
            cargo  = @("cargo", "test")
            bun    = @("bun", "test")
            npm    = @("npm", "test")
            pnpm   = @("pnpm", "test")
            yarn   = @("yarn", "test")
            uv     = @("uv", "run", "pytest")
            poetry = @("poetry", "run", "pytest")
            go     = @("go", "test", "./...")
            dotnet = @("dotnet", "test")
            make   = @("make", "test")
        }
        run = @{
            cargo  = @("cargo", "run")
            bun    = @("bun", "run", "dev")
            npm    = @("npm", "run", "dev")
            pnpm   = @("pnpm", "run", "dev")
            yarn   = @("yarn", "dev")
            uv     = @("uv", "run", "python", "main.py")
            poetry = @("poetry", "run", "python", "main.py")
            go     = @("go", "run", ".")
            dotnet = @("dotnet", "run")
            make   = @("make", "run")
        }
        clean = @{
            cargo  = @("cargo", "clean")
            bun    = @("bun", "pm", "cache", "rm")
            npm    = @("npm", "cache", "clean", "--force")
            pnpm   = @("pnpm", "store", "prune")
            yarn   = @("yarn", "cache", "clean")
            uv     = @("uv", "cache", "clean")
            go     = @("go", "clean", "-cache")
            dotnet = @("dotnet", "clean")
            make   = @("make", "clean")
            cmake  = @("cmake", "--build", "build", "--target", "clean")
        }
        fix = @{
            cargo  = @("cargo", "fmt")
            bun    = @("bun", "run", "lint")
            npm    = @("npm", "run", "lint")
            pnpm   = @("pnpm", "run", "lint")
            yarn   = @("yarn", "lint")
            uv     = @("uv", "run", "ruff", "check", "--fix", ".")
            go     = @("go", "fmt", "./...")
            dotnet = @("dotnet", "format")
        }
        install = @{
            cargo  = @("cargo", "fetch")
            bun    = @("bun", "install")
            npm    = @("npm", "install")
            pnpm   = @("pnpm", "install")
            yarn   = @("yarn")
            uv     = @("uv", "sync")
            poetry = @("poetry", "install")
            go     = @("go", "mod", "download")
            dotnet = @("dotnet", "restore")
        }
        check = @{
            cargo  = @("cargo", "check")
            bun    = @("bun", "run", "typecheck")
            npm    = @("npm", "run", "typecheck")
            uv     = @("uv", "run", "pytest", "--collect-only")
            go     = @("go", "vet", "./...")
            dotnet = @("dotnet", "build", "--no-restore")
        }
    }
}

function script:Resolve-DevStack {
    param(
        [string]$Root,
        [string]$Prefer
    )
    $stacks = Detect-DevStacks -Root $Root
    if ($Prefer) {
        $hit = $stacks | Where-Object { $_.Id -eq $Prefer.ToLower() } | Select-Object -First 1
        if ($hit) { return $hit }
        # allow force stack even without marker
        return [PSCustomObject]@{
            Id = $Prefer.ToLower(); Name = $Prefer; Tool = $Prefer.ToLower()
            Present = [bool](Get-VaiTool $Prefer.ToLower()); Path = (Get-VaiTool $Prefer.ToLower()); Marker = "(forced)"
        }
    }
    # prefer stack whose tool is present
    $ready = @($stacks | Where-Object Present)
    if ($ready.Count -gt 0) { return $ready[0] }
    if ($stacks.Count -gt 0) { return $stacks[0] }
    return $null
}
