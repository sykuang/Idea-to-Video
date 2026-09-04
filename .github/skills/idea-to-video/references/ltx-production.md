# LTX production rules

Repository documentation and live CLI help are authoritative. Recheck them before rendering.

## Default routing

- Start with `ltx_pipelines.distilled` for a fast pilot.
- Use DFR when production quality is requested and all DFR assets are installed.
- Use image conditioning for a designed opening frame or cross-shot visual handoff.
- Use retake for a bounded defect inside an otherwise accepted clip.
- Use another pipeline only when its conditioning mode matches the brief.

## LTX-2.5 constraints

- Width and height must satisfy the selected pipeline. The distilled two-stage pipeline requires both dimensions to be divisible by 64; verify other pipelines with live CLI/source validation.
- Frame count normally satisfies `num_frames % 8 == 1`.
- At 24 FPS, 121 frames are approximately 5.04 seconds and 241 frames are approximately 10.04 seconds.
- At 24 FPS, a nominal 30-second single clip is 721 frames, but capacity alone does not make that the best production plan.
- Longer and higher-resolution shots increase tokens, memory, runtime, and continuity risk.
- Prefer narrative shot boundaries for long work. Do not split dialogue or actions arbitrarily.

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

LTX-2.5 supports native multi-shot generation. Prefer 2–4 clearly differentiated shots in one prompt, naming each cut and re-establishing framing, identity, and audio continuity. More cuts or longer narratives should be partitioned into independently reviewable generation units.

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

Probe actual VRAM and model readiness. Use full BF16 when it fits and quality is preferred. Consider `--quantization fp8-cast` or CPU/disk offload only when necessary or deliberately benchmarking the tradeoff. Do not promise speed.

On Windows ARM64, verify optional backends rather than assuming Linux CUDA packages exist. Standard SDR generation must not depend on EXR/HDR tooling.

## Render records

Every attempt records:

- shot and attempt ID
- prompt hash or full prompt reference
- seed, dimensions, FPS, frames
- pipeline and all non-default options
- checkpoint paths or immutable identifiers
- source conditioning assets
- output path, start/end time, and result
- observed defects and approval status

## Assembly

Prefer stream-compatible cuts only when media properties match exactly. Otherwise normalize explicitly during final encoding. Check:

- video codec, pixel format, dimensions, FPS, and time base
- audio codec, sample rate, channels, and loudness
- combined duration and A/V drift
- transition boundaries and duplicated handoff frames

Keep the reproducible command under `scripts/`.
