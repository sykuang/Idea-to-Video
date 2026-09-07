# LTX production rules

Repository documentation and live CLI help are authoritative. Recheck them before rendering.

## Default routing

- Start with `ltx_pipelines.distilled` for a fast pilot.
- Use DFR when production quality is requested and resources permit; acquire missing approved assets rather than requiring them to be preinstalled.
- Use image conditioning for a designed opening frame or cross-shot visual handoff.
- Select official task-specific adapters using `lora-selection.md`: native x2 detailing/upscaling, Deblur for optical defocus, Decompression for compression damage, or Ingredients for reference-sheet identity. Download missing approved adapters and apply them only to the relevant shots.
- Use retake for a bounded defect inside an otherwise accepted clip.
- Use another pipeline only when its conditioning mode matches the brief.

## LTX-2.5 constraints

- Width and height must satisfy the selected pipeline. The distilled two-stage pipeline requires both dimensions to be divisible by 64; verify other pipelines with live CLI/source validation.
- Frame count normally satisfies `num_frames % 8 == 1`.
- At 24 FPS, 121 frames are approximately 5.04 seconds and 241 frames are approximately 10.04 seconds.
- At 24 FPS, a nominal 30-second single clip is 721 frames, but capacity alone does not make that the best production plan.
- Longer and higher-resolution shots increase tokens, memory, runtime, and continuity risk.
- Prefer narrative shot boundaries for long work. Do not split dialogue or actions arbitrarily.
- Budget transition handles and breathing room; generated duration is not all usable story time.

## Prompt contract

Read `prompt-craft.md`. Write a single flowing paragraph in chronological playback order for a continuous shot, or explicit prose transitions for a native multi-shot scene. Include:

1. main visible action
2. subject appearance and movement
3. environment and important props
4. framing and camera movement
5. lighting, palette, and depth
6. timed audible events and exact approved dialogue
7. final visual state needed for the next shot

Keep it literal and precise. Do not use prompt space on invisible backstory unless it changes an observable behavior.

For adapter-conditioned shots, the trained prompt formats in `lora-selection.md` take precedence over the ordinary paragraph layout. Keep the scene/action content chronological and preserve the required trigger words or reference labels.

LTX-2.5 supports native multi-shot generation. Prefer 2–4 clearly differentiated shots in one prompt, naming each cut and re-establishing framing, identity, and audio continuity. More cuts or longer narratives should be partitioned into independently reviewable generation units.

Every generation unit must have a boundary plan. Generate a readable opening handle and a stable or deliberately moving ending handle. Record picture transition, audio transition, and intended hold duration in the shot plan before rendering.

## Continuity hierarchy

For adjacent shots, preserve continuity in this order unless the brief says otherwise:

1. subject identity and immutable traits
2. wardrobe and props
3. environment and time of day
4. screen direction and position
5. action phase and final pose
6. camera side, height, and movement
7. lighting direction and palette
8. voice, ambience, and music

A repeated seed is not a continuity mechanism. Prefer a reviewed handoff image, explicit continuity text, and a compatible next-shot composition.

## Resource policy

Always run the PyTorch preflight below during production planning and immediately before every render, including resumed work, retries, and retakes. Probe model readiness separately. Use full BF16 when it fits and quality is preferred. Consider `--quantization fp8-cast` or CPU/disk offload only when necessary or deliberately benchmarking the tradeoff. Do not promise speed.

### Mandatory PyTorch VRAM preflight

Run this command with the same Python interpreter, environment, host, and CUDA device visibility as generation. Replace `python` with the render environment's interpreter or launcher when needed. For remote rendering, run it on the render host, not the client.

PowerShell:

```powershell
@'
import sys
import torch

print(f"Python: {sys.executable}")
print(f"PyTorch: {torch.__version__}; CUDA runtime: {torch.version.cuda}")
if not torch.cuda.is_available():
    raise SystemExit("PyTorch CUDA is unavailable; stop before rendering.")

for index in range(torch.cuda.device_count()):
    device = torch.device(f"cuda:{index}")
    probe = torch.ones(1, device=device)
    (probe + probe).item()
    torch.cuda.synchronize(device)
    properties = torch.cuda.get_device_properties(device)
    free_bytes, _ = torch.cuda.mem_get_info(device)
    print(
        f"{device}: {properties.name}; capability={properties.major}.{properties.minor}; "
        f"total_vram_gib={properties.total_memory / 1024**3:.2f}; "
        f"free_vram_gib={free_bytes / 1024**3:.2f}"
    )
    del probe
'@ | python -
if ($LASTEXITCODE -ne 0) { throw "PyTorch GPU preflight failed." }
```

On other shells, execute the same Python body with the render interpreter. Record the selected CUDA device indices, GPU names, total/free VRAM in GiB, and probe time with the plan or render attempt. For multi-GPU rendering, measure each participating device separately; do not treat summed VRAM as one allocation pool.

`total_memory` is device capacity; `mem_get_info()` reports currently free device memory, not just this process's allocations. Free VRAM is a snapshot, not a reservation or proof that a workload will fit. Do not use `memory_allocated()` or `memory_reserved()` as substitutes for capacity or free VRAM. GPU specifications, Windows WMI/Task Manager readings, and `nvidia-smi` may supplement diagnostics but never replace this PyTorch command.

If PyTorch cannot import, CUDA is unavailable, a memory query fails, or the tensor operation fails, surface the error and stop before rendering. Do not guess VRAM or silently fall back to another source.

On Windows ARM64, verify optional backends rather than assuming Linux CUDA packages exist. Standard SDR generation must not depend on EXR/HDR tooling.

## Render records

Every attempt records:

- shot and attempt ID
- prompt hash or full prompt reference
- seed, dimensions, FPS, frames
- pipeline and all non-default options
- PyTorch preflight time, selected CUDA device indices/names, and measured total/free VRAM in GiB
- checkpoint paths or immutable identifiers
- adapter repositories/revisions, local hashes/paths, references, effective strengths, and compatibility/pilot outcomes when adapters are used
- source conditioning assets
- output path, start/end time, and result
- observed defects and approval status

## Assembly

Prefer stream-compatible cuts only when media properties match exactly. Otherwise normalize explicitly during final encoding. Check:

- video codec, pixel format, dimensions, FPS, and time base
- audio codec, sample rate, channels, and loudness
- combined duration and A/V drift
- transition boundaries and duplicated handoff frames
- dialogue clearance, head/tail handles, hold duration, and whether the next clip arrives too early

Keep the reproducible command under `scripts/`.
