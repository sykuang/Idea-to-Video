---
name: idea-to-video
description: Turn a rough idea into a planned, generated, reviewed, and assembled LTX-2.5 video. Use when a user wants to make a video, develop a video concept, create an AI video, storyboard an idea, or turn a prompt into one or more coherent LTX shots. Not for ordinary editing of finished footage or a request for only a standalone screenplay.
---

# Idea to Video

Own the path from a vague idea to a reviewable video. Interview rigorously, make the production decisions explicit, perform the mechanical work, and stop only at meaningful approval gates.

This is a native generated-video workflow, not an image slideshow workflow. Prefer synchronized video and audio from LTX-2.5. Use image conditioning, shot segmentation, and assembly when the requested duration or narrative cannot be generated reliably as one clip.

## Source of truth

Before constructing or running commands, consult the repository documentation:

- `README.md`
- `packages/ltx-pipelines/docs/installation.md`
- `packages/ltx-pipelines/docs/pipelines.md`
- `packages/ltx-pipelines/docs/optimization.md`

Run the selected pipeline with `--help` before relying on a CLI option. Repository behavior wins over this skill if they differ.

Read these skill references when entering the corresponding work:

- `references/interview.md` before IDEA_GRILL
- `references/ltx-production.md` before PRODUCTION_PLAN or any render
- `references/prompt-craft.md` before writing or reviewing an LTX prompt
- `references/state.md` before creating or updating project state

## Hard invariants

1. **No render before plan approval.** Hardware probes and CLI checks are allowed. Model downloads, generation, paid calls, and final assembly require approval at the relevant gate.
2. **Ask one decisive question at a time during the idea grill.** Ask grouped questions only when their answers are inseparable. Never dump a questionnaire.
3. **Do not accept ambiguous creative language.** Convert words such as "cinematic," "epic," or "viral" into observable choices: subject behavior, shot size, camera motion, lighting, pacing, sound, and ending.
4. **Do not invent user intent.** Reversible technical defaults may be proposed. Story facts, exact dialogue, brand claims, real-person likeness, and publication intent must be confirmed.
5. **Never claim continuity that was not reviewed.** Reusing prompts or seeds does not prove identity, wardrobe, spatial, voice, or motion continuity.
6. **Never expose or store secrets.** Check whether authentication is configured; do not request plaintext tokens, cookies, or API keys.
7. **Never publish automatically.** Uploading, posting, or changing a live account always requires separate authorization.
8. **Preserve source assets and prior renders.** Work only inside the project folder. Mark superseded artifacts stale; do not silently delete them.
9. **Verify actual capabilities.** Probe the current GPU, PyTorch/CUDA, model files, disk space, encoder, and media tools. Never claim a render path is available because it exists in documentation.
10. **Respect rights and safety.** Do not imitate protected footage or copy another creator's finished work. Do not generate deceptive real-person media, harmful content, or assets the user lacks rights to use.

## Interaction contract

At each user gate, keep the update compact and use:

- **Stage:** current stage and status
- **Working on:** what the skill is doing now
- **Need from you:** the single current decision or input
- **Deliverable:** what will exist after this stage
- **Next:** what approval unlocks

Do not ask the user which workflow step to take next. Determine the next stage from project state.

Allowed statuses: `not_started`, `in_progress`, `awaiting_approval`, `approved`, `needs_revision`, `skipped`.

## Start or resume

The workflow is:

`START -> IDEA_GRILL -> BRIEF -> PRODUCTION_PLAN -> PROMPT_PILOT -> PILOT_RENDER -> SHOT_RENDER -> REVIEW -> ASSEMBLY -> FINAL_ACCEPTANCE`

Use `projects/<project-slug>/` unless the user supplies another project folder. Each project uses stable artifacts:

```text
VIDEO_PROJECT.json
BRIEF.md
CONTINUITY.md
SHOT_PLAN.csv
PROMPTS.md
scripts/
references/
shots/
review/
renders/
```

On invocation:

1. Look for `VIDEO_PROJECT.json` in the supplied or inferred project folder.
2. If found, validate it using `references/state.md`, confirm referenced artifacts still exist, summarize the latest approved gate, and resume at `pending_request`.
3. If not found, initialize a new project and enter IDEA_GRILL.
4. Never repeat an approved question unless a later answer creates a direct contradiction.

## Stage 1: IDEA_GRILL

Read `references/interview.md`.

Interrogate the concept until it is production-decidable. Start with:

> What should the viewer see, hear, and feel by the end of this video?

Follow the highest-uncertainty branch. Challenge vague answers with concrete alternatives. Keep asking until these are known or explicitly delegated as defaults:

- viewer and viewing context
- platform, aspect ratio, duration, and language
- beginning, change, and final beat
- subjects, environment, action, and continuity requirements
- camera grammar, pacing, visual treatment, and lighting
- dialogue, voice, ambience, music, and silence
- references to learn from and qualities to avoid
- source assets, rights, restrictions, and acceptance criteria

Do not solve the concept while critical contradictions remain. When enough is known, present a concise decision ledger containing:

- confirmed decisions
- proposed defaults
- unresolved risks
- explicit exclusions

**Gate:** the user confirms the decision ledger.

## Stage 2: BRIEF

Create `BRIEF.md` from `assets/brief-template.md`. Write for production rather than marketing: every creative adjective must have an observable implementation.

Create `CONTINUITY.md` from `assets/continuity-template.md` whenever the video has multiple shots or recurring subjects. Record immutable traits separately from shot-specific changes.

Derive a one-sentence creative promise and a beat outline. Ensure the planned ending fulfills the opening promise.

**Gate:** the user approves the brief and continuity rules.

## Stage 3: PRODUCTION_PLAN

Read `references/ltx-production.md`, inspect the local environment, and choose the simplest viable route:

- **DistilledPipeline:** default pilot and fastest native audio-video generation.
- **DFRPipeline:** production-quality route when its detailing LoRA and required assets are present.
- **Image-conditioned distilled/DFR:** recurring subject, designed first frame, or cross-shot handoff.
- **RetakePipeline:** repair a bounded temporal region of an otherwise accepted clip.
- **Other repository pipeline:** only when the requested conditioning matches it and required assets exist.

Probe, do not guess:

- operating system and architecture
- Python, PyTorch version, CUDA availability, GPU name/capability/VRAM
- required checkpoint paths and sizes
- free disk space
- pipeline import and `--help`
- FFmpeg/PyAV availability for inspection and assembly

Calculate frame counts from duration and FPS. Every LTX shot frame count must satisfy the currently documented constraint; for LTX-2.5 this is normally `frames % 8 == 1`. Treat the extra endpoint frame explicitly when calculating duration.

For long videos, split at narrative or camera boundaries instead of blindly dividing time. Prefer independently reviewable shots. For continuous action, plan an overlap or last-frame-to-next-shot image-conditioning handoff. Do not assume a seed alone preserves continuity.

LTX-2.5 can generate native multi-shot scenes. Prefer one generation containing 2–4 connected shots when the action, identity, and soundscape benefit from remaining together. Name every cut, re-establish the framing after it, repeat identifying traits, and state whether audio continues. Use separate generations when the scene is too long, materially changes place/time/style, or needs independent retries.

Create `SHOT_PLAN.csv` from `assets/shot-plan-template.csv`. Every row must specify:

- shot ID and narrative purpose
- target seconds, FPS, and valid frame count
- visible action in chronological order
- camera, composition, lighting, and palette
- audible event, dialogue, and ambience
- continuity inputs and expected end frame
- pipeline, resolution, seed, model options, dependencies, and status

Estimate cost in concrete terms: shot count, generated frames, resolution, expected model assets, and known memory mitigations. Do not fabricate render time.

**Gate:** the user approves the complete shot plan and resource implications.

## Stage 4: PROMPT_PILOT

Read `references/prompt-craft.md`, then write `PROMPTS.md`, one prompt per generation unit. A unit may be one continuous shot or an approved 2–4-shot native multi-shot scene. Follow the repository's current prompting guidance:

- one flowing chronological description
- roughly 4–8 descriptive sentences for a normal single shot
- present-tense verbs that create motion in every action beat
- describe observable action, appearance, environment, camera, lighting, and sound
- put events in playback order
- attribute every line to a visible or off-screen speaker and put exact confirmed dialogue in quotation marks
- write pauses, interruptions, reactions, and changes in volume as timed actions
- for every cut, name the transition, re-establish the new view, and state audio continuity
- avoid abstract quality labels without visual implementation
- keep recurring facts identical to `CONTINUITY.md`
- stay within the documented prompt length

Run the prompt lint in `references/prompt-craft.md`. Do not render a prompt that fails dialogue fit, temporal order, scene-load, camera, lighting, or final-state checks. Use `--enhance-prompt` for rough or foreign-model prompts; leave it off when exact authored wording and timing must remain unchanged.

Choose one representative pilot shot. It should test the hardest recurring risk, such as character identity, dialogue, motion, camera movement, or style—not merely the easiest shot.

Present the pilot prompt, parameters, and the exact risks it tests.

**Gate:** the user approves the pilot prompt and settings.

## Stage 5: PILOT_RENDER

Before rendering:

1. Confirm the model files exist and are complete.
2. Confirm the selected device with an actual CUDA tensor operation.
3. Validate width, height, and frame count.
4. Write the reproducible command to `scripts/render-<shot-id>.ps1` on Windows or `.sh` on Unix.
5. Record prompt, seed, paths, software versions, and parameters in project state.

Render only the approved pilot. On failure, diagnose the root cause and retry only after a material correction. Do not disguise a failed render as a completed preview.

Create `review/<shot-id>.md` with:

- output path and media metadata
- representative frame paths
- expected versus observed events
- visible or audible defects
- continuity observations
- exact parameters used

For dialogue pilots, listen to the entire clip and transcribe what was actually produced. Check speaker attribution, omitted or invented words, delivery, lip movement, pauses, interruptions, ambience, and synchronization; waveform presence alone is not dialogue acceptance.

Ask the user to approve, reject, or name the largest issue. If rejected, change one controlled dimension at a time where practical and preserve prior attempts.

**Gate:** the pilot is approved.

## Stage 6: SHOT_RENDER

Render remaining shots in dependency order.

- Shots without dependencies may run independently when system resources permit.
- Continuity-dependent shots wait for the preceding shot's approved handoff frame.
- Extract and inspect handoff frames before using them as conditioning.
- Keep one immutable render script and metadata record per attempt.
- Never overwrite an approved render.

After each logical batch, run structural checks: file existence, non-zero duration, dimensions, FPS, frame count, audio stream, corruption, and expected shot IDs.

**Gate:** all required shots exist, or missing shots are explicitly waived.

## Stage 7: REVIEW

Create a contact sheet or representative frames plus a shot review table. Review:

- prompt adherence and chronological event order
- subject identity, wardrobe, props, environment, and screen direction
- anatomy, geometry, text, flicker, and transition readiness
- camera behavior and pacing
- dialogue, sync, voice consistency, ambience, clipping, and silence
- first/last-frame compatibility between adjacent shots

Machine checks do not replace watching every shot with audio. Ask the user to approve specific shots or identify exact revisions. Route localized defects to retake when viable; regenerate a whole shot when its premise or continuity is wrong.

**Gate:** the shot set and edit order are approved.

## Stage 8: ASSEMBLY

Assemble only approved shots. Preserve each source render. Use the confirmed edit plan for:

- trims and overlap handling
- cuts, dissolves, or deliberate discontinuities
- audio crossfades and loudness consistency
- captions or titles only if approved
- final dimensions, FPS, codec, and audio settings

Create a preview before the final encode. Validate audio/video duration, streams, dimensions, FPS, and playability.

**Gate:** the user approves the assembled preview.

## Stage 9: FINAL_ACCEPTANCE

Render the final master to `renders/`, then record:

- master path and media properties
- source shot manifest
- prompts and seeds
- model/checkpoint identifiers
- known limitations and accepted exceptions
- reproducible assembly command

Status remains `awaiting_approval` until the user watches and accepts the master. Publishing is outside this gate and requires separate authorization.

## Completion

Completion means:

- the final master exists and is playable
- all source shots and reproducibility metadata are preserved
- project state validates
- the user explicitly accepted the master

Report only the delivered artifact, its essential properties, and any accepted limitation. Do not call a successful pilot a completed video.
