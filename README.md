# Idea to Video

A GitHub Copilot skill for turning a rough idea into a planned, generated,
reviewed, and assembled video. The default production route is LTX-2.5 with
native video and audio.

The workflow covers concept development, a creative brief, shot planning,
prompting, a pilot render, continuity review, and final assembly. Explicit
approval gates keep model downloads, renders, and publishing under user control.
This repository provides the workflow and runtime setup helpers, not model weights or the
LTX inference runtime.

## Install in GitHub Copilot CLI

Use a Copilot CLI release with plugin support. Add this repository as a plugin
marketplace and install the skill:

```powershell
copilot plugin marketplace add sykuang/Idea-to-Video
copilot plugin install idea-to-video@idea-to-video-marketplace
```

Alternatively, install directly from GitHub:

```powershell
copilot plugin install sykuang/Idea-to-Video
```

In a new Copilot session, use `/skills list` to find `idea-to-video`, then ask:

> Use idea-to-video to develop a 20-second video of a tiny robot tending a rooftop garden.

The plugin is defined by `plugin.json`; its marketplace catalog is
`.github\plugin\marketplace.json`. Both reuse the skill in
`.github\skills\idea-to-video` without duplicating it. Installation adds the
workflow only; it does not install Python, PyTorch, inference packages, or models.
These commands become available from GitHub once the metadata is pushed.

### Use a local checkout

```powershell
git clone https://github.com/sykuang/Idea-to-Video.git
Set-Location Idea-to-Video
copilot
```

Copilot discovers the repository-local skill in `.github\skills`. To load the
checkout explicitly as a plugin, use `copilot --plugin-dir .` instead.

Use a user-managed working directory for rendering. With a marketplace install,
the skill invokes the bundled installer from that directory; you do not need to
clone Idea-to-Video separately. Do not store environments, weights, or video
projects in Copilot's installed plugin cache.

## Install LTX-2.5

`install-ltx25.ps1` installs `ltx-core` and `ltx-pipelines` from a compatible
[LTX source checkout](https://github.com/Lightricks/LTX-2) into an existing
Python environment. It is an **installer, not a render wrapper**.

Prepare a Python version supported by your LTX revision and wheel files, with
pip available. Use a dedicated virtual environment rather than a shared/system
Python installation. For a new environment, run this command from your working directory:

```powershell
python -m venv .venv
```

When `-LtxSourcePath` is omitted, the installer downloads the LTX repository into
`packages\LTX-2` under your **current working directory** if it is missing. Git
must be available on `PATH` for this first download. Existing checkouts are reused
without pulling, resetting, or overwriting them. For this default checkout,
the installer adds `/packages/` to the working directory's `.gitignore` if an
equivalent rule is missing, preserving existing contents. This happens before
downloading, including when the installer itself lives in Copilot's plugin cache.
An explicit `-LtxSourcePath` uses your existing checkout without modifying the
workspace's `.gitignore`.

Both default paths belong to the working directory: `packages\LTX-2` for the
source and `.venv\Scripts\python.exe` for Python. The examples below use the local
installer path; with a marketplace install, the skill uses the bundled installer's
absolute path while keeping your working directory unchanged.

Select a source revision that supports LTX-2.5 and your platform. The
`packages\ltx-pipelines\docs` paths referenced by the skill belong to that
source checkout. The installer uses editable installs, so keep the checkout in
place and record its revision for reproducibility. To use a specific existing
checkout, pass `-LtxSourcePath`; explicitly supplied paths must already exist.

### Install with custom prebuilt PyTorch binaries

Provide local **`.whl` files** for `torch`, `torchaudio`, and `torchvision`,
matching each other and the target Python version, OS, architecture, and CUDA
runtime. A directory must contain at most one wheel for each of these packages:

```powershell
.\install-ltx25.ps1 `
    -PyTorchWheelPath "C:\Builds\pytorch-wheels"
```

You can instead pass an explicit list of wheel paths, including paths in
different directories:

```powershell
$wheels = @(
    "C:\Builds\torch-2.13.0+custom-cp313-cp313-win_arm64.whl"
    "C:\Builds\torchaudio-2.13.0+custom-cp313-cp313-win_arm64.whl"
    "C:\Builds\torchvision-0.28.0+custom-cp313-cp313-win_arm64.whl"
)
.\install-ltx25.ps1 -PyTorchWheelPath $wheels
```

The filenames above are illustrative; use the actual compatible wheels from
your build. Raw DLL folders and unpacked build trees are not pip-installable
wheels. For those builds, install them into your chosen Python environment first,
then use the existing-build option below.

### Reuse an already-installed PyTorch build

Omit `-PyTorchWheelPath` to keep `torch`, `torchaudio`, and `torchvision` already
installed in the selected environment:

```powershell
.\install-ltx25.ps1
```

Both paths have defaults. Override them when using a different checkout or
environment:

```powershell
.\install-ltx25.ps1 `
    -LtxSourcePath "C:\Source\LTX-2" `
    -PythonPath "C:\AI Environments\ltx\Scripts\python.exe"
```

You may supply only some wheels when the remaining PyTorch packages are already
installed. Missing companions cause an error rather than an automatic download
of a different build.

| Parameter | Default | Purpose |
|-----------|---------|---------|
| `-LtxSourcePath` | `packages\LTX-2` under the current working directory | Cloned if missing when omitted; explicit paths select an existing checkout. |
| `-PythonPath` | `.venv\Scripts\python.exe` under the current working directory | Target interpreter; the environment must already exist. |
| `-PyTorchWheelPath` | Omitted | One or more wheel files/directories; otherwise reuse installed PyTorch packages. |

Both default paths and all explicit relative input paths resolve from the caller's
working directory, not the installer's location. The installer does not change
the working directory, activate an environment, or fall back to system Python.

Selected wheels are installed first without dependency resolution. The installer
then installs the two LTX packages and their dependencies with exact constraints
on all three PyTorch versions, including custom version suffixes. Conflicting
requirements fail instead of replacing those builds. Other dependencies and build
tools may be downloaded by pip; required packages unavailable for your platform
also stop installation rather than being silently skipped. Installation is not
transactional: a failure may leave selected wheels or other packages installed.

Finally, the installer checks dependency consistency, runtime imports, and the
distilled pipeline's CLI. It does **not** download model weights, render a video,
or establish that the GPU has sufficient free VRAM.

## Render directly from the installed environment

The skill selects the appropriate LTX pipeline and writes reproducible
per-shot commands rather than routing every render through a fixed wrapper.
Before each render, run the
[mandatory PyTorch GPU/VRAM preflight](.github/skills/idea-to-video/references/ltx-production.md#mandatory-pytorch-vram-preflight)
with the same interpreter used below. Recheck the chosen pipeline's live options:

```powershell
$pythonPath = (Resolve-Path .\.venv\Scripts\python.exe).Path
& $pythonPath -m ltx_pipelines.distilled --help
```

After approving the plan, downloading the matching model components, and running
the preflight, a split-checkpoint distilled command looks like:

```powershell
$modelRoot = "C:\Models\ltx-2.5"
& $pythonPath -m ltx_pipelines.distilled `
    --transformer-path "$modelRoot\diffusion_models\ltx-2.5-22b-distilled-transformer-bf16.safetensors" `
    --text-encoder-path "$modelRoot\text_encoders\gemma4-12b-with-proj-ltx-2.5-bf16.safetensors" `
    --video-vae-path "$modelRoot\vae\ltx-2.5-video-vae-bf16.safetensors" `
    --audio-vae-path "$modelRoot\vae\ltx-2.5-audio-vae-bf16.safetensors" `
    --spatial-upsampler-path "$modelRoot\latent_upscale_models\ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors" `
    --prompt "Ocean waves roll onto a quiet beach at sunset, with synchronized surf audio." `
    --output-path "C:\Videos\pilot-01.mp4" `
    --width 768 --height 512 --num-frames 121 --seed 42
if ($LASTEXITCODE -ne 0) { throw "LTX generation failed." }
```

Use existing parent directories and a new output filename for each attempt.
Model/output paths are chosen by the project, not anchored to an installer or
plugin directory. For distilled generation, width and height must be divisible
by 64 and frame counts normally satisfy `frames % 8 == 1`; verify constraints
for other pipelines. Keep FFmpeg/ffprobe available for review and assembly.

## Workflow and project files

The skill moves through concept questions, brief approval, production planning,
pilot approval/rendering, remaining shots, review, assembly, and final acceptance.
It keeps each project's state and artifacts in `projects\<project-slug>\`:

```text
VIDEO_PROJECT.json
BRIEF.md
CONTINUITY.md
SHOT_PLAN.csv
PROMPTS.md
scripts\
references\
shots\
review\
renders\
```

Read the [skill instructions](.github/skills/idea-to-video/SKILL.md) for the full
workflow. Prompt guidance, production rules, and templates live beside the skill.
Generated media still requires human review with audio; publishing requires
separate approval.
