param(
    [string]$Prompt = "A cinematic shot of ocean waves at sunset, with synchronized ambient surf audio.",
    [string]$OutputPath = "output.mp4",
    [int]$Width = 768,
    [int]$Height = 512,
    [int]$NumFrames = 121,
    [int]$Seed = 42
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$modelRoot = Join-Path $PSScriptRoot "models\ltx-2.5"
$modelPaths = @{
    Transformer = Join-Path $modelRoot "diffusion_models\ltx-2.5-22b-distilled-transformer-bf16.safetensors"
    TextEncoder = Join-Path $modelRoot "text_encoders\gemma4-12b-with-proj-ltx-2.5-bf16.safetensors"
    VideoVae = Join-Path $modelRoot "vae\ltx-2.5-video-vae-bf16.safetensors"
    AudioVae = Join-Path $modelRoot "vae\ltx-2.5-audio-vae-bf16.safetensors"
    SpatialUpsampler = Join-Path $modelRoot "latent_upscale_models\ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors"
}

if (-not (Test-Path $python)) {
    throw "The LTX Python environment was not found at '$python'."
}

if (($Width % 64) -ne 0 -or ($Height % 64) -ne 0) {
    throw "Width and height must both be divisible by 64 for the distilled two-stage pipeline."
}

if (($NumFrames % 8) -ne 1) {
    throw "NumFrames must satisfy NumFrames % 8 == 1."
}

$missingModels = $modelPaths.Values | Where-Object { -not (Test-Path $_) }
if ($missingModels) {
    throw "Missing LTX-2.5 model files:`n$($missingModels -join "`n")"
}

& $python -m ltx_pipelines.distilled `
    --transformer-path $modelPaths.Transformer `
    --text-encoder-path $modelPaths.TextEncoder `
    --video-vae-path $modelPaths.VideoVae `
    --audio-vae-path $modelPaths.AudioVae `
    --spatial-upsampler-path $modelPaths.SpatialUpsampler `
    --prompt $Prompt `
    --output-path $OutputPath `
    --width $Width `
    --height $Height `
    --num-frames $NumFrames `
    --seed $Seed

if ($LASTEXITCODE -ne 0) {
    throw "LTX-2.5 generation failed with exit code $LASTEXITCODE."
}
