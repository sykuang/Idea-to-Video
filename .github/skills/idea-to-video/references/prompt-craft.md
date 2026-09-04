# LTX-2.5 prompt craft

Use the current official guide as the source of truth:

- <https://docs.ltx.io/open-source-model/usage-guides/prompting-guide>
- the prompting section in the repository `README.md`

This reference turns that guidance into a repeatable drafting and linting process.

## Choose the prompt shape

### Single continuous shot

Use one flowing paragraph, normally 4–8 descriptive sentences. Keep one coherent camera path and lighting logic. Describe how the frame looks after a camera move so the move has a clear destination.

### Native multi-shot scene

LTX-2.5 can generate connected shots in one prompt. Prefer 2–4 shots, each with one clear job. Write the full scene chronologically, and at every edit:

1. name the transition in prose: hard cut, match cut, view cuts, or dissolve
2. re-establish shot scale, camera angle, subjects, and relevant lighting
3. repeat stable identifying traits for recurring subjects
4. state whether dialogue, ambience, or music continues or changes

Do not use a numbered shot list as the model prompt. The planning artifact may be tabular, but the generation prompt must flow as prose.

## Build in this order

1. **Opening frame:** shot scale, viewpoint, subject, place, and immediately legible action.
2. **Scene logic:** coherent light source, palette, textures, atmosphere, and spatial relationship.
3. **Character definition:** age range, hair, clothing, distinctive traits, posture, and physical emotion cues.
4. **Action chain:** present-tense verbs in strict playback order.
5. **Camera chain:** movement relative to the subject and the composition reached after each move.
6. **Sound chain:** ambience first, then effects, speech, music, silence, and changes.
7. **Ending frame:** final pose, framing, sound state, and any handoff needed by the next generation.

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

For Dub-It, use the current capability-specific template and provide the full target-language dialogue in native script. Match the source speech timing and syllable load; the beta is documented for one speaker.

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

## Prompt enhancer policy

Use `--enhance-prompt` when the input is short, rough, or written for another video model. It translates rough intent into LTX-oriented language.

Leave enhancement off when:

- exact dialogue must remain unchanged
- the prompt already follows this structure
- a carefully timed beat or continuity phrase must be preserved

If enhancement is used, save and review the enhanced prompt before treating it as production-approved whenever the pipeline exposes it.

## Pre-render lint

A prompt passes only when every answer is yes:

### Structure

- Is it chronological prose rather than tags or an unsupported shot list?
- Does each action sentence contain a concrete present-tense verb?
- Is the opening frame immediately understandable?
- Is the ending state explicit?

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

### Continuity

- Are recurring identifiers copied exactly from `CONTINUITY.md`?
- Is screen direction and geography understandable?
- Does every cut re-establish the shot and preserve or explicitly change audio?
- Does the final state support the next shot or handoff image?

When a prompt fails, simplify before adding more detail.
