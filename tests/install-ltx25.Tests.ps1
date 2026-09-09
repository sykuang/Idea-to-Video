$repositoryRoot = Split-Path $PSScriptRoot -Parent

Describe "LTX installer with custom PyTorch" {
    function git {
        param($Action, $Repository, $Destination)
        throw "Unexpected Git invocation in an installer test."
    }

    BeforeEach {
        $originalLocation = Get-Location
        $originalExitCode = $global:LASTEXITCODE
        $previousTestState = $global:LtxInstallerTest
        $global:LtxInstallerTest = @{
            Calls = @()
            Versions = @{ torch = "2.13.0+custom"; torchaudio = "2.13.0+custom"; torchvision = "0.28.0+custom" }
            FailurePattern = $null
            ConstraintsPath = $null
            Constraints = @()
            ChangeTorchVersion = $false
            CloneFailed = $false
            GitCalls = @()
        }
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $installerRoot = Join-Path $caseRoot "installer"
        $sourceRoot = Join-Path $caseRoot "LTX source [custom]"
        $environmentRoot = Join-Path $caseRoot "Python environment"
        $wheelRoot = Join-Path $caseRoot "wheel builds [custom]"
        New-Item -ItemType Directory -Path $installerRoot, $sourceRoot, $environmentRoot, $wheelRoot -Force |
            Out-Null
        Set-Location $caseRoot
        $installer = Join-Path $installerRoot "install-ltx25.ps1"
        Copy-Item -LiteralPath (Join-Path $repositoryRoot "install-ltx25.ps1") -Destination $installer
        foreach ($package in @("ltx-core", "ltx-pipelines")) {
            $packagePath = Join-Path $sourceRoot "packages\$package"
            New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $packagePath "pyproject.toml") | Out-Null
        }
        $pythonPath = Join-Path $environmentRoot "python.ps1"
        New-Item -ItemType File -Path $pythonPath -Value @'
$global:LASTEXITCODE = 0
$state = $global:LtxInstallerTest
$state.Calls += ,@($args)
if ($args -contains "--constraint") {
    $state.ConstraintsPath = $args[[array]::IndexOf($args, "--constraint") + 1]
    $state.Constraints = @(Get-Content -LiteralPath $state.ConstraintsPath)
}
if ($state.FailurePattern -and ($args -join " ") -match $state.FailurePattern) {
    $global:LASTEXITCODE = 9
    return
}
if ($args -contains "--no-deps") {
    foreach ($argument in $args) {
        if ([IO.Path]::GetFileName($argument) -match "^(torch|torchaudio|torchvision)-([^-]+)-.+\.whl$") {
            $state.Versions[$Matches[1]] = $Matches[2]
        }
    }
}
if ($args -contains "--constraint" -and $state.ChangeTorchVersion) {
    $state.Versions.torch = "0.0.0"
}
if ($args[0] -eq "-c" -and $args[1] -match "importlib.metadata") {
    ConvertTo-Json -InputObject $state.Versions -Compress
}
'@ | Out-Null
        $parameters = @{ LtxSourcePath = $sourceRoot; PythonPath = $pythonPath }
        $global:LtxInstallerTest.SourceTemplate = $sourceRoot
        Mock git {
            param($Action, $Repository, $Destination)
            $state = $global:LtxInstallerTest
            $state.GitCalls += ,@($Action, $Repository, $Destination)
            if ($state.CloneFailed) {
                $global:LASTEXITCODE = 8
            }
            else {
                Copy-Item -LiteralPath $state.SourceTemplate -Destination $Destination -Recurse
                $global:LASTEXITCODE = 0
            }
        }
    }

    AfterEach {
        Set-Location $originalLocation
        $global:LASTEXITCODE = $originalExitCode
        $global:LtxInstallerTest = $previousTestState
    }

    It "installs both LTX source packages while preserving installed PyTorch versions" {
        & $installer @parameters | Out-Null
        $installs = @($global:LtxInstallerTest.Calls | Where-Object { $_ -contains "install" })
        $installs.Count | Should Be 1
        $installs[0][0] | Should Be "-m"
        $installs[0][1] | Should Be "pip"
        $installs[0][-4] | Should Be "--editable"
        $installs[0][-3] | Should Be (Join-Path $sourceRoot "packages\ltx-core")
        $installs[0][-2] | Should Be "--editable"
        $installs[0][-1] | Should Be (Join-Path $sourceRoot "packages\ltx-pipelines")
        ($global:LtxInstallerTest.Constraints -join "`n") |
            Should Be "torch===2.13.0+custom`ntorchaudio===2.13.0+custom`ntorchvision===0.28.0+custom"
        (Test-Path -LiteralPath $global:LtxInstallerTest.ConstraintsPath) | Should Be $false
        ($global:LtxInstallerTest.Calls[-3] -join " ") | Should Be "-m pip check"
        $global:LtxInstallerTest.Calls[-2][1] | Should Match "import torch"
        ($global:LtxInstallerTest.Calls[-1] -join " ") | Should Be "-m ltx_pipelines.distilled --help"
    }

    It "installs a complete wheel directory before resolving any LTX dependencies" {
        foreach ($name in @("torch", "torchaudio", "torchvision")) {
            $global:LtxInstallerTest.Versions[$name] = $null
            New-Item -ItemType File -Path (Join-Path $wheelRoot "$name-2.13.0+local-cp313-cp313-win_arm64.whl") |
                Out-Null
        }
        New-Item -ItemType File -Path (Join-Path $wheelRoot "unrelated-1.0-py3-none-any.whl") | Out-Null
        & $installer @parameters -PyTorchWheelPath $wheelRoot | Out-Null
        $installs = @($global:LtxInstallerTest.Calls | Where-Object { $_ -contains "install" })
        $installs.Count | Should Be 2
        ($installs[0] -contains "--no-deps") | Should Be $true
        ($installs[0] -contains "--force-reinstall") | Should Be $true
        @($installs[0] | Where-Object { $_ -like "*.whl" }).Count | Should Be 3
        ($installs[1] -contains "--constraint") | Should Be $true
        $global:LtxInstallerTest.Constraints[0] | Should Be "torch===2.13.0+local"
    }

    It "accepts explicit wheel files and retains companions that are already installed" {
        $torchWheel = Join-Path $wheelRoot "torch-2.13.0+local-cp313-cp313-win_arm64.whl"
        $audioWheel = Join-Path $caseRoot "torchaudio-2.13.0+local-cp313-cp313-win_arm64.whl"
        New-Item -ItemType File -Path $torchWheel, $audioWheel | Out-Null
        & $installer @parameters -PyTorchWheelPath @($torchWheel, $audioWheel) | Out-Null
        $global:LtxInstallerTest.Constraints[0] | Should Be "torch===2.13.0+local"
        $global:LtxInstallerTest.Constraints[1] | Should Be "torchaudio===2.13.0+local"
        $global:LtxInstallerTest.Constraints[2] | Should Be "torchvision===0.28.0+custom"
    }

    It "resolves relative inputs from the caller without changing the working directory" {
        Set-Location $caseRoot
        & $installer -LtxSourcePath ".\LTX source [custom]" -PythonPath ".\Python environment\python.ps1" |
            Out-Null
        (Get-Location).Path | Should Be $caseRoot
    }

    It "resolves default Python from the working directory instead of the cached installer" {
        Set-Location $caseRoot
        $defaultPython = Join-Path $caseRoot ".venv\Scripts\python.exe"
        { & $installer } | Should Throw "Python was not found at '$defaultPython'"
    }

    It "reuses packages under the caller's working directory without downloading again" {
        $defaultSource = Join-Path $environmentRoot "packages\LTX-2"
        New-Item -ItemType Directory -Path (Split-Path $defaultSource -Parent) | Out-Null
        Copy-Item -LiteralPath $sourceRoot -Destination $defaultSource -Recurse
        Set-Location $environmentRoot
        & $installer -PythonPath $pythonPath | Out-Null
        $installs = @($global:LtxInstallerTest.Calls | Where-Object { $_ -contains "install" })
        $installs[0][-3] | Should Be (Join-Path $defaultSource "packages\ltx-core")
        $installs[0][-1] | Should Be (Join-Path $defaultSource "packages\ltx-pipelines")
        (Get-Location).Path | Should Be $environmentRoot
        $global:LtxInstallerTest.GitCalls.Count | Should Be 0
    }

    It "downloads a missing default checkout into the caller's packages directory" {
        Set-Location $environmentRoot
        $defaultSource = Join-Path $environmentRoot "packages\LTX-2"
        & $installer -PythonPath $pythonPath | Out-Null
        $global:LtxInstallerTest.GitCalls.Count | Should Be 1
        ($global:LtxInstallerTest.GitCalls[0] -join "`n") |
            Should Be ("clone`nhttps://github.com/Lightricks/LTX-2.git`n$defaultSource")
        $installs = @($global:LtxInstallerTest.Calls | Where-Object { $_ -contains "install" })
        $installs[0][-3] | Should Be (Join-Path $defaultSource "packages\ltx-core")
        (Get-Location).Path | Should Be $environmentRoot
        (Get-Content -LiteralPath (Join-Path $environmentRoot ".gitignore") -Raw).Trim() |
            Should Be "/packages/"
        (Test-Path -LiteralPath (Join-Path $installerRoot ".gitignore")) | Should Be $false
    }

    It "preserves existing ignore rules and appends a missing rule only once" {
        Set-Location $environmentRoot
        $ignorePath = Join-Path $environmentRoot ".gitignore"
        $original = "# workspace rules`r`n*.log"
        New-Item -ItemType File -Path $ignorePath -Value $original | Out-Null
        & $installer -PythonPath $pythonPath | Out-Null
        & $installer -PythonPath $pythonPath | Out-Null
        (Get-Content -LiteralPath $ignorePath -Raw) | Should Be "$original`r`n/packages/`r`n"
        $global:LtxInstallerTest.GitCalls.Count | Should Be 1
    }

    It "leaves an existing packages ignore rule and LF line endings untouched" {
        Set-Location $environmentRoot
        $ignorePath = Join-Path $environmentRoot ".gitignore"
        $original = "# workspace rules`n/packages/`n*.log`n"
        New-Item -ItemType File -Path $ignorePath -Value $original | Out-Null
        & $installer -PythonPath $pythonPath | Out-Null
        (Get-Content -LiteralPath $ignorePath -Raw) | Should Be $original
    }

    It "recognizes an equivalent unanchored packages directory rule" {
        Set-Location $environmentRoot
        $ignorePath = Join-Path $environmentRoot ".gitignore"
        New-Item -ItemType File -Path $ignorePath -Value "packages/`n" | Out-Null
        & $installer -PythonPath $pythonPath | Out-Null
        (Get-Content -LiteralPath $ignorePath -Raw) | Should Be "packages/`n"
    }

    It "preserves LF line endings when appending a rule" {
        Set-Location $environmentRoot
        $ignorePath = Join-Path $environmentRoot ".gitignore"
        New-Item -ItemType File -Path $ignorePath -Value "# workspace rules`n*.log`n" | Out-Null
        & $installer -PythonPath $pythonPath | Out-Null
        (Get-Content -LiteralPath $ignorePath -Raw) | Should Be "# workspace rules`n*.log`n/packages/`n"
    }

    It "preserves the encoding and existing bytes of an ignore file" {
        Set-Location $environmentRoot
        $ignorePath = Join-Path $environmentRoot ".gitignore"
        $original = "# workspace rules`r`n*.log"
        [System.IO.File]::WriteAllText($ignorePath, $original, [System.Text.Encoding]::Unicode)
        $before = [System.IO.File]::ReadAllBytes($ignorePath)
        & $installer -PythonPath $pythonPath | Out-Null
        $after = [System.IO.File]::ReadAllBytes($ignorePath)
        [Convert]::ToBase64String($after, 0, $before.Length) | Should Be ([Convert]::ToBase64String($before))
        [System.IO.File]::ReadAllText($ignorePath) | Should Be "$original`r`n/packages/`r`n"
    }

    It "does not change workspace ignore rules when using an explicit source checkout" {
        & $installer @parameters | Out-Null
        (Test-Path -LiteralPath (Join-Path $caseRoot ".gitignore")) | Should Be $false
    }

    It "stops before downloading when the workspace ignore path is a directory" {
        Set-Location $environmentRoot
        New-Item -ItemType Directory -Path (Join-Path $environmentRoot ".gitignore") | Out-Null
        { & $installer -PythonPath $pythonPath } | Should Throw "workspace .gitignore path is not a file"
        $global:LtxInstallerTest.GitCalls.Count | Should Be 0
    }

    It "stops before installing packages when downloading the checkout fails" {
        Set-Location $environmentRoot
        $global:LtxInstallerTest.CloneFailed = $true
        { & $installer -PythonPath $pythonPath } | Should Throw "failed with exit code 8"
        $global:LtxInstallerTest.Calls.Count | Should Be 0
    }

    It "reports missing Git before downloading a checkout" {
        Set-Location $environmentRoot
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "git" }
        { & $installer -PythonPath $pythonPath } | Should Throw "Git is required to download LTX"
        $global:LtxInstallerTest.GitCalls.Count | Should Be 0
    }

    It "does not overwrite a file at the default checkout path" {
        Set-Location $environmentRoot
        $defaultSource = Join-Path $environmentRoot "packages\LTX-2"
        New-Item -ItemType Directory -Path (Split-Path $defaultSource -Parent) | Out-Null
        New-Item -ItemType File -Path $defaultSource -Value "preserve me" | Out-Null
        { & $installer -PythonPath $pythonPath } | Should Throw "LTX source path is not a directory"
        (Get-Content -LiteralPath $defaultSource -Raw) | Should Be "preserve me"
        $global:LtxInstallerTest.GitCalls.Count | Should Be 0
    }

    It "does not overwrite or redownload an incomplete existing checkout" {
        Set-Location $environmentRoot
        $defaultSource = Join-Path $environmentRoot "packages\LTX-2"
        New-Item -ItemType Directory -Path $defaultSource -Force | Out-Null
        { & $installer -PythonPath $pythonPath } |
            Should Throw "Missing pyproject.toml"
        $global:LtxInstallerTest.GitCalls.Count | Should Be 0
        $global:LtxInstallerTest.Calls.Count | Should Be 0
    }

    It "rejects an unavailable interpreter" {
        $parameters.PythonPath = Join-Path $caseRoot "missing.exe"
        { & $installer @parameters } | Should Throw "Python was not found"
        $global:LtxInstallerTest.Calls.Count | Should Be 0
    }

    It "rejects a missing source checkout" {
        $parameters.LtxSourcePath = Join-Path $caseRoot "missing-source"
        { & $installer @parameters } | Should Throw "LTX source checkout was not found"
        $global:LtxInstallerTest.GitCalls.Count | Should Be 0
    }

    It "rejects a checkout missing a source package before invoking Python" {
        Remove-Item -LiteralPath (Join-Path $sourceRoot "packages\ltx-core\pyproject.toml")
        { & $installer @parameters } | Should Throw "Missing pyproject.toml"
        $global:LtxInstallerTest.Calls.Count | Should Be 0
    }

    It "rejects a missing wheel path" {
        { & $installer @parameters -PyTorchWheelPath (Join-Path $caseRoot "missing.whl") } |
            Should Throw "PyTorch wheel path was not found"
    }

    It "rejects raw binary directories" {
        New-Item -ItemType File -Path (Join-Path $wheelRoot "torch.dll") | Out-Null
        { & $installer @parameters -PyTorchWheelPath $wheelRoot } | Should Throw "No PyTorch wheels found"
    }

    It "rejects unrelated explicitly supplied wheel files" {
        $wheel = Join-Path $wheelRoot "unrelated-1.0-py3-none-any.whl"
        New-Item -ItemType File -Path $wheel | Out-Null
        { & $installer @parameters -PyTorchWheelPath $wheel } | Should Throw "Unsupported PyTorch wheel"
    }

    It "rejects ambiguous directories containing multiple builds of the same package" {
        foreach ($version in @("2.12.0", "2.13.0")) {
            New-Item -ItemType File -Path (Join-Path $wheelRoot "torch-$version-cp313-cp313-win_arm64.whl") |
                Out-Null
        }
        { & $installer @parameters -PyTorchWheelPath $wheelRoot } | Should Throw "Multiple wheels supplied"
        $global:LtxInstallerTest.Calls.Count | Should Be 0
    }

    It "rejects missing companion builds before modifying the environment" {
        $global:LtxInstallerTest.Versions.torchaudio = $null
        { & $installer @parameters } | Should Throw "'torchaudio' is not installed"
        @($global:LtxInstallerTest.Calls | Where-Object { $_ -contains "install" }).Count | Should Be 0
    }

    It "propagates pip availability failures" {
        $global:LtxInstallerTest.FailurePattern = "^-m pip --version$"
        { & $installer @parameters } | Should Throw "Checking pip failed with exit code 9"
    }

    It "stops after a wheel installation failure without attempting LTX installation" {
        $wheel = Join-Path $wheelRoot "torch-2.13.0+local-cp313-cp313-win_arm64.whl"
        New-Item -ItemType File -Path $wheel | Out-Null
        $global:LtxInstallerTest.FailurePattern = "--no-deps"
        { & $installer @parameters -PyTorchWheelPath $wheel } |
            Should Throw "Installing local PyTorch wheels failed with exit code 9"
        @($global:LtxInstallerTest.Calls | Where-Object { $_ -contains "--constraint" }).Count | Should Be 0
    }

    It "surfaces dependency resolution failures and removes temporary constraints" {
        $global:LtxInstallerTest.FailurePattern = "--constraint"
        { & $installer @parameters } | Should Throw "Installing LTX and runtime dependencies failed with exit code 9"
        (Test-Path -LiteralPath $global:LtxInstallerTest.ConstraintsPath) | Should Be $false
    }

    It "rejects unexpected changes to a selected PyTorch version" {
        $global:LtxInstallerTest.ChangeTorchVersion = $true
        { & $installer @parameters } | Should Throw "version changed during LTX installation"
        (Test-Path -LiteralPath $global:LtxInstallerTest.ConstraintsPath) | Should Be $false
    }

    It "surfaces incompatible dependencies rather than claiming success" {
        $global:LtxInstallerTest.FailurePattern = "^-m pip check$"
        { & $installer @parameters } | Should Throw "Checking dependency compatibility failed with exit code 9"
    }

    It "surfaces binary import failures" {
        $global:LtxInstallerTest.FailurePattern = "import torch"
        { & $installer @parameters } | Should Throw "Importing the installed runtime failed with exit code 9"
    }

    It "surfaces unsupported pipeline CLIs" {
        $global:LtxInstallerTest.FailurePattern = "^-m ltx_pipelines.distilled --help$"
        { & $installer @parameters } | Should Throw "Loading the LTX pipeline CLI failed with exit code 9"
    }
}
