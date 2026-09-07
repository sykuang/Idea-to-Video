# LTX-2.5 prompt craft

Use the current official guide as the source of truth:

- <https://docs.ltx.io/open-source-model/usage-guides/prompting-guide>
- <https://ltx.io/blog/ltx-2-5-prompt-guide>
- the prompting section in the repository `README.md`

This reference turns that guidance into a repeatable drafting and linting process.

For task-specific IC-LoRAs, also read `lora-selection.md`. Their trained reference/edited or reference-sheet prompt formats override the ordinary paragraph layout, while action order, explicit cuts, exact dialogue, and continuity constraints still apply.

## Choose the prompt shape

### Single continuous shot

Use one flowing paragraph, normally 4–8 descriptive sentences. Keep one coherent camera path and lighting logic. Describe how the frame looks after a camera move so the move has a clear destination.

Prefer a single continuous take for uninterrupted camera motion, intimate performance, or lip-synced dialogue held in one framing. For image-to-video conditioned on a first frame, stay in that take by default; use multiple shots only when the prompt deliberately describes a cut away from the opening image.

### Native multi-shot scene

LTX-2.5 can generate connected shots in one prompt. Prefer 2–4 shots, each with one clear job. Write the full scene chronologically, and at every edit:

1. name the transition in prose: hard cut, match cut, view cuts, or dissolve
2. re-establish shot scale, camera angle, subjects, and relevant lighting
3. repeat stable identifying traits for recurring subjects
4. state whether dialogue, ambience, or music continues or changes

Give the viewer time to register each new composition. After an important line, reveal, or reaction, write an explicit beat such as "the camera holds on her reaction for a quiet beat" before introducing the next cut.

Do not use a numbered shot list as the model prompt. The planning artifact may be tabular, but the generation prompt must flow as prose.

## Build in this order

1. **Opening frame:** shot scale, viewpoint, subject, place, and immediately legible action.
2. **Scene logic:** coherent light source, palette, textures, atmosphere, and spatial relationship.
3. **Character definition:** age range, hair, clothing, distinctive traits, posture, and physical emotion cues.
4. **Action chain:** present-tense verbs in strict playback order.
5. **Camera chain:** movement relative to the subject and the composition reached after each move.
6. **Sound chain:** ambience first, then effects, speech, music, silence, and changes.
7. **Ending frame:** final pose, framing, sound state, and any handoff needed by the next generation.

For a separately rendered clip, also write an **edit handle** at each boundary:

- opening handle: a readable composition before the first major action or line
- ending handle: a stable hold or simple continuing motion after the final beat
- picture transition: hard cut, match cut, dissolve, fade, or another approved edit
- audio transition: continue, stop, pre-lap, or crossfade narration/music/ambience

Do not place essential dialogue at the first or last instant of a clip. Leave room for the edit and for the viewer to absorb the final beat.

Match detail to scale. A close-up needs face, gaze, micro-gesture, voice, and focus detail; a wide shot needs geography, trajectories, scale, and atmosphere.

## Dialogue construction

Dialogue is an audiovisual event, not detached screenplay text. For each line specify:

- who speaks and whether they are visible or off-screen
- physical action immediately before or during speech
- delivery: language/accent when needed, voice quality, pace, and volume
- exact words in quotation marks
- the listener's visible reaction, if important
- an explicit pause or interruption when timing depends on it
- what ambience or music does underneath the line

Example pattern:

> Mara grips the cup with both hands and avoids his gaze. In a quiet, unsteady British voice she says, "I didn't come here to apologize." A beat of silence follows; the refrigerator hum remains audible. Daniel stops mid-step and looks toward her without speaking.

Do not overload a short clip with dialogue. Read the lines aloud together with described pauses and actions. If they do not fit comfortably inside the target duration, shorten the words, simplify the action, increase the approved duration, or split at a meaningful beat. Never solve a timing problem by silently dropping confirmed dialogue.

For multiple speakers, make turn-taking unmistakable. Re-name the speaker for each line rather than relying on pronouns. Keep the number of speakers and simultaneous actions low enough that each turn remains visually readable.

### Dub-It speech replacement

Compatibility gate: the current official adapter catalog marks Dub-It as LTX-2.3-only, with LTX-2.5 support in development. Do not use the following recipe on LTX-2.5 unless updated official documentation confirms support; do not silently switch the project's base model.

Dub-It replaces speech in a supplied source video, rather than generating a new scene from text alone. Use this capability-specific template:

> [Speaker] is speaking [Language/Accent], saying: "[Dialogue]"

Add physical emotion cues or delivery instructions when needed. Supply every intended word in the target language's native script; Dub-It follows the supplied dialogue and does not translate it for you. The beta supports one speaker and does not distinguish multiple speakers.

The official guide lists English, French, Spanish, German, and Russian as validated languages. Recheck the [Dub-It model guide](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-DubIt) before promising support for another language.

Keep the replacement close to the source speech's duration and syllable count. A slightly longer line is preferable to one that is too short, but excessive length can cause omitted words; an overly short line can sound unnaturally slow. Do not silently change confirmed dialogue to make it fit.

## Clip-quality choices

LTX responds well to:

- cinematic wide, medium, and close compositions
- a single subject's expressions and subtle physical reactions
- readable camera language such as static, slow dolly, pan, tracking, or over-the-shoulder
- coherent lighting, weather, reflections, fog, rain, dust, and surface texture
- named visual treatments placed early in the prompt
- clearly described voice, ambience, music, and sound effects

Reduce or isolate:

- crowded casts and many layered actions
- chaotic, twisting, or implausible physics
- conflicting camera instructions
- unexplained geography, wardrobe, or lighting changes
- exact signs, logos, captions, or critical on-screen spelling
- abstract internal emotion without posture, gesture, gaze, breath, or facial cues

Add critical text and logos in post unless the user explicitly accepts generative text risk.

## Optional vocabulary palette

Use these examples to make an approved visual or audio choice concrete, not as a tag list to paste into every prompt. Pick compatible terms and explain what the viewer actually sees or hears.

| Dimension | Example choices |
|-----------|-----------------|
| Genre or medium | Observational documentary, noir mystery, hand-drawn animation, clay stop-motion |
| Lighting and palette | Cool window light, warm practical lamps, muted earth tones, high-contrast monochrome |
| Texture and atmosphere | Scratched metal, frayed fabric, low mist, rain on glass |
| Camera and framing | Locked-off wide shot, shoulder-height tracking, slow push toward a face, overhead view |
| Sound and delivery | Distant cafe chatter, leaves rustling, a hesitant whisper, brisk radio-style speech |
| Pacing and transitions | Hold on a reaction, continuous take, match cut, slow dissolve, time-lapse |
| Image treatment and effects | Fine film grain, shallow depth of field, restrained lens flare, motion blur |

Place the main genre or medium early. Tie camera terms to a subject and destination, sound terms to their source, and pacing terms to a specific beat.

## Prompt enhancer policy

Use `--enhance-prompt` when the input is short, rough, or written for another video model. It translates rough intent into LTX-oriented language.

Leave enhancement off when:

- exact dialogue must remain unchanged
- the prompt already follows this structure
- a carefully timed beat or continuity phrase must be preserved
- a prepared IC-LoRA prompt contains required task triggers, reference labels, or preservation constraints

If enhancement is used, save and review the enhanced prompt before treating it as production-approved whenever the pipeline exposes it.

## Pre-render lint

A prompt passes only when every answer is yes:

### Structure

- Is it chronological scene prose or a documented adapter prompt format, rather than tags or an unsupported shot list?
- Does each action sentence contain a concrete present-tense verb?
- Is the opening frame immediately understandable?
- Is the ending state explicit?
- For first-frame image-to-video, is the take continuous unless a cut away from the opening image is explicitly described?

### Scene load

- Does each shot have one primary visual job?
- Are the number of characters, actions, props, and effects manageable?
- Are complex physics avoided or isolated as the pilot risk?

### Camera and light

- Is camera movement relative to the subject?
- Is the post-move composition described?
- Is there one coherent lighting logic per shot?

### Dialogue and audio

- Is every line attributed and quoted?
- Do delivery, volume, language/accent when needed, and physical behavior agree?
- Are pauses and reactions written where timing depends on them?
- Does spoken dialogue plus action fit comfortably when read aloud?
- Is ambience/music continuity stated across cuts?
- Is there breathing room after important lines and reveals?

### Continuity

- Are recurring identifiers copied exactly from `CONTINUITY.md`?
- Is screen direction and geography understandable?
- Does every cut re-establish the shot and preserve or explicitly change audio?
- Does the final state support the next shot or handoff image?
- Do separate clips provide usable opening/ending handles and an approved transition?

When a prompt fails, simplify before adding more detail.
