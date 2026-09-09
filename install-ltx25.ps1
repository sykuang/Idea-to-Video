<#
.SYNOPSIS
Installs LTX into an existing Python environment while preserving custom PyTorch builds.
.PARAMETER LtxSourcePath
Path to a compatible LTX-2 source checkout containing packages\ltx-core and packages\ltx-pipelines.
Defaults to packages\LTX-2 under the current working directory, cloning it if missing.
An explicitly supplied path must already contain a compatible checkout.
.PARAMETER PythonPath
The target environment's Python interpreter. Defaults to .venv\Scripts\python.exe under the current working directory.
.PARAMETER PyTorchWheelPath
Local torch, torchaudio, or torchvision wheel files, or directories containing them.
Omit this parameter to preserve the three packages already installed in the target environment.
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$LtxSourcePath = (Join-Path (Get-Location).Path "packages\LTX-2"),
    [ValidateNotNullOrEmpty()]
    [string]$PythonPath = (Join-Path (Get-Location).Path ".venv\Scripts\python.exe"),
    [ValidateNotNullOrEmpty()]
    [string[]]$PyTorchWheelPath = @()
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
    throw "Python was not found at '$PythonPath'. Create a virtual environment with 'python -m venv .venv' or select an existing interpreter with -PythonPath."
}
$python = (Resolve-Path -LiteralPath $PythonPath).Path

if (-not $PSBoundParameters.ContainsKey("LtxSourcePath")) {
    $ignorePath = Join-Path (Get-Location).Path ".gitignore"
    $ignoreText = ""
    $ignoreEncoding = [System.Text.UTF8Encoding]::new($false)
    if (Test-Path -LiteralPath $ignorePath -PathType Leaf) {
        # Read the encoding and newline style, then append without rewriting existing bytes.
        $reader = [System.IO.StreamReader]::new($ignorePath, $ignoreEncoding, $true)
        try {
            $ignoreText = $reader.ReadToEnd()
            $ignoreEncoding = $reader.CurrentEncoding
        }
        finally {
            $reader.Dispose()
        }
    }
    elseif (Test-Path -LiteralPath $ignorePath) {
        throw "The workspace .gitignore path is not a file: '$ignorePath'."
    }

    if (-not [regex]::IsMatch($ignoreText, "(?m)^/?packages/[ `t]*`r?$")) {
        $newline = [Environment]::NewLine
        if ($ignoreText.Contains("`r`n")) {
            $newline = "`r`n"
        }
        elseif ($ignoreText.Contains("`n")) {
            $newline = "`n"
        }
        $separator = ""
        if ($ignoreText.Length -gt 0 -and -not $ignoreText.EndsWith("`n")) {
            $separator = $newline
        }
        [System.IO.File]::AppendAllText($ignorePath, "$separator/packages/$newline", $ignoreEncoding)
    }
}

if (-not (Test-Path -LiteralPath $LtxSourcePath -PathType Container)) {
    if (Test-Path -LiteralPath $LtxSourcePath) {
        throw "LTX source path is not a directory: '$LtxSourcePath'."
    }
    if ($PSBoundParameters.ContainsKey("LtxSourcePath")) {
        throw "LTX source checkout was not found at '$LtxSourcePath'. Clone a compatible Lightricks/LTX-2 revision first."
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is required to download LTX into '$LtxSourcePath'. Install Git or pass -LtxSourcePath with an existing checkout."
    }

    New-Item -ItemType Directory -Path (Split-Path $LtxSourcePath -Parent) -Force | Out-Null
    & git clone "https://github.com/Lightricks/LTX-2.git" $LtxSourcePath
    if ($LASTEXITCODE -ne 0) {
        throw "Cloning LTX into '$LtxSourcePath' failed with exit code $LASTEXITCODE. Inspect any partial checkout before retrying."
    }
}
$sourceRoot = (Resolve-Path -LiteralPath $LtxSourcePath).Path
$corePath = Join-Path $sourceRoot "packages\ltx-core"
$pipelinesPath = Join-Path $sourceRoot "packages\ltx-pipelines"
foreach ($packagePath in @($corePath, $pipelinesPath)) {
    if (-not (Test-Path -LiteralPath (Join-Path $packagePath "pyproject.toml") -PathType Leaf)) {
        throw "Missing pyproject.toml in '$packagePath'. Select a compatible LTX source checkout."
    }
}

$torchPackages = @("torch", "torchaudio", "torchvision")
$wheels = @{}
foreach ($wheelInput in $PyTorchWheelPath) {
    if (Test-Path -LiteralPath $wheelInput -PathType Container) {
        $candidates = @(Get-ChildItem -LiteralPath $wheelInput -Filter "*.whl" -File |
            Where-Object { $_.Name -match "^(torch|torchaudio|torchvision)-" })
        if ($candidates.Count -eq 0) {
            throw "No PyTorch wheels found in '$wheelInput'. Supply .whl files, not raw DLLs or a build directory."
        }
    }
    elseif (Test-Path -LiteralPath $wheelInput -PathType Leaf) {
        $candidates = @(Get-Item -LiteralPath $wheelInput)
    }
    else {
        throw "PyTorch wheel path was not found: '$wheelInput'."
    }

    foreach ($wheel in $candidates) {
        if ($wheel.Name -notmatch "^(torch|torchaudio|torchvision)-.+\.whl$") {
            throw "Unsupported PyTorch wheel '$($wheel.Name)'. Supply torch, torchaudio, or torchvision .whl files."
        }
        $name = $Matches[1].ToLowerInvariant()
        if ($wheels.ContainsKey($name)) {
            throw "Multiple wheels supplied for '$name'. Select exactly one wheel per package for the target Python version and architecture."
        }
        $wheels[$name] = $wheel.FullName
    }
}

function Invoke-LtxPython {
    param(
        [string[]]$Arguments,
        [string]$Operation
    )

    & $python @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE. Resolve the reported error and rerun the installer; no fallback build will be installed."
    }
}

$metadataCode = @'
import importlib.metadata as metadata
import json

versions = {}
for name in ("torch", "torchaudio", "torchvision"):
    try:
        versions[name] = metadata.version(name)
    except metadata.PackageNotFoundError:
        versions[name] = None
print(json.dumps(versions))
'@

Invoke-LtxPython -Arguments @("-m", "pip", "--version") -Operation "Checking pip"
$versions = Invoke-LtxPython -Arguments @("-c", $metadataCode) -Operation "Reading PyTorch metadata" |
    ConvertFrom-Json
foreach ($name in $torchPackages) {
    if (-not $versions.$name -and -not $wheels.ContainsKey($name)) {
        throw "'$name' is not installed and no local wheel was supplied. Provide its compatible prebuilt wheel with -PyTorchWheelPath, or install it in '$python' first."
    }
}

if ($wheels.Count -gt 0) {
    $wheelFiles = @($torchPackages | Where-Object { $wheels.ContainsKey($_) } | ForEach-Object { $wheels[$_] })
    # Install the selected binaries first; resolve their dependencies with LTX under exact constraints.
    Invoke-LtxPython -Arguments (@("-m", "pip", "install", "--no-deps", "--force-reinstall") + $wheelFiles) `
        -Operation "Installing local PyTorch wheels"
    $versions = Invoke-LtxPython -Arguments @("-c", $metadataCode) -Operation "Reading installed PyTorch metadata" |
        ConvertFrom-Json
}

$pins = foreach ($name in $torchPackages) {
    if (-not $versions.$name) {
        throw "The selected environment has no installed '$name' distribution after wheel installation."
    }
    "$name===$($versions.$name)"
}

$constraints = New-TemporaryFile
try {
    Set-Content -LiteralPath $constraints.FullName -Value $pins -Encoding UTF8
    Invoke-LtxPython -Arguments @(
        "-m", "pip", "install", "--constraint", $constraints.FullName,
        "--editable", $corePath, "--editable", $pipelinesPath
    ) -Operation "Installing LTX and runtime dependencies"

    $installedVersions = Invoke-LtxPython -Arguments @("-c", $metadataCode) -Operation "Checking preserved PyTorch versions" |
        ConvertFrom-Json
    foreach ($name in $torchPackages) {
        if ($installedVersions.$name -ne $versions.$name) {
            throw "The '$name' version changed during LTX installation. Expected '$($versions.$name)', found '$($installedVersions.$name)'."
        }
    }
    Invoke-LtxPython -Arguments @("-m", "pip", "check") -Operation "Checking dependency compatibility"
    Invoke-LtxPython -Arguments @("-c", @'
import torch
import torchaudio
import torchvision
import ltx_core
import ltx_pipelines

print(f"PyTorch: {torch.__version__}; CUDA runtime: {torch.version.cuda}")
print(f"PyTorch location: {torch.__file__}")
'@) -Operation "Importing the installed runtime"
    Invoke-LtxPython -Arguments @("-m", "ltx_pipelines.distilled", "--help") `
        -Operation "Loading the LTX pipeline CLI" | Out-Null
}
finally {
    Remove-Item -LiteralPath $constraints.FullName
}

Write-Output "LTX installation complete. Python: $python"
Write-Output "LTX source: $sourceRoot"
Write-Output "Run the mandatory PyTorch GPU/VRAM preflight before rendering, then invoke the selected ltx_pipelines module directly with this interpreter."
