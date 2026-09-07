# Official LoRA selection and acquisition

Select, download, and apply a task-specific adapter when it is needed for the approved shot plan. Do not merely recommend an adapter and leave the mechanical work to the user. Do not download the whole catalog, stack adapters speculatively, or apply a restoration pass to an already clean render.

## Sources and compatibility

Before selecting an adapter, read its current official model card, file listing, and the [official adapter catalog](https://docs.ltx.io/open-source-model/integration-tools/ic-lo-ra-adapters). The [IC-LoRA usage guide](https://docs.ltx.io/open-source-model/usage-guides/ic-lo-ra) describes reference preparation. Local pipeline source and live `--help` determine which commands this checkout can run.

The catalog lists several LTX-2.3-trained adapters for use with LTX-2.5, but this is not universal compatibility. Keep their real repository names and filenames; never manufacture an LTX-2.5 filename by changing a version string. Prove the selected base/adapter/runtime combination on a pilot before batch use.

The official catalog currently marks **Dub-It, HDR, and Relight as not yet supporting LTX-2.5**. Do not select or download them for an LTX-2.5 run unless updated official documentation explicitly confirms support. If sources conflict or the required workflow is unavailable locally, report the blocker rather than silently swapping base models or ignoring missing adapter weights.

## Choose by observable need

| Need | Official adapter | When to use / limits |
|------|------------------|----------------------|
| Higher output resolution or finer generated detail | [LTX-2.5 Pixel Spatial Upscaler](https://huggingface.co/Lightricks/LTX-2.5-22b-IC-LoRA-Pixel-Spatial-Upscaler) | Prefer the native 2.5 x2 adapter for DFR or a reference-video upscale. Synthesizes detail; not compression repair, blind denoising, or factual restoration. The native 2.5 card currently publishes x2 only; do not assume the older x4 checkpoint is interchangeable. |
| Unintended optical defocus | [Deblur](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Deblur) | Use the blurry clip as reference. Not for intentional shallow depth of field, motion blur, noise, compression damage, or upscaling. |
| Visible compression damage | [Decompression](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Decompression) | Use for macroblocking, ringing, or chroma bleed. Prefer re-encoding a clean source when available; this adapter is not a general quality booster. |
| Recurring characters, props, or locations | [Ingredients](https://huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Ingredients) | Use a user-approved reference sheet to condition generation. It cannot recover identities absent from the sheet and is not a post-render sharpening pass. |

If the actual defect is wrong action, missing dialogue, or an incorrect scene, correct the prompt/conditioning and use retake or regeneration. These adapters are not substitutes for semantic correctness.

## Download only what the plan needs

1. Record the chosen adapter, reason, source/reference asset, intended pipeline, expected output properties, and resource cost in the shot plan. Include missing base components as well as adapter files in the download budget. Run the mandatory PyTorch VRAM preflight and check disk space on the render host.
2. Obtain production-plan approval covering the downloads and use. Once covered, automatically acquire missing files and run the approved pilot without a separate question for each download. Newly discovered repairs may proceed under an already approved repair budget; otherwise return to plan approval before downloading or rendering.
3. Resolve an immutable repository revision and the exact checkpoint filename from official Hugging Face metadata. Inspect file size, published SHA-256 when available, license/access requirements, and adapter metadata. Reuse matching verified local files or the existing Hugging Face cache.
4. Download only selected files using `hf download` or `huggingface_hub.hf_hub_download`, with the resolved revision. Default new project-local downloads to `models\loras\<adapter-id>\<revision>` inside the project; reuse a shared model directory only if it is already authorized. On remote runs, download on the render host.
5. Check the command's exit status, confirm the file is complete, compare size and any published digest, and compute a local SHA-256 for provenance. Do not treat nonzero size alone as integrity proof. A failed or partial download blocks the dependent render. Do not overwrite a known-good checkpoint with a different revision.
6. Record the resolved absolute path and acquisition metadata in project state, then supply that exact file to the selected pipeline. A downloaded file is not proof that the LoRA was applied.

Published checkpoint filenames to locate and recheck:

| Adapter ID | Repository | File |
|------------|------------|------|
| `pixel-spatial-x2` | `Lightricks/LTX-2.5-22b-IC-LoRA-Pixel-Spatial-Upscaler` | `ltx-2.5-22b-ic-lora-pixel-spatial-upscaler-x2-1.0.safetensors` |
| `deblur` | `Lightricks/LTX-2.3-22b-IC-LoRA-Deblur` | `ltx-2.3-22b-ic-lora-deblur-0.9.safetensors` |
| `decompression` | `Lightricks/LTX-2.3-22b-IC-LoRA-Decompression` | `ltx-2.3-22b-ic-lora-decompression-0.9.safetensors` |
| `ingredients` | `Lightricks/LTX-2.3-22b-IC-LoRA-Ingredients` | `ltx-2.3-22b-ic-lora-ingredients-0.9.safetensors` |

PowerShell download template, after setting `$repo`, `$filename`, `$revision`, and `$modelDir` to the approved, resolved values above:

```powershell
hf download $repo $filename --revision $revision --local-dir $modelDir
if ($LASTEXITCODE -ne 0) { throw "Adapter download failed; do not render." }
Get-Item -LiteralPath (Join-Path $modelDir $filename)
Get-FileHash -LiteralPath (Join-Path $modelDir $filename) -Algorithm SHA256
```

Use the render environment's existing Hugging Face tooling. If missing, follow the repository's installation guidance before retrying; do not install a second generation stack just for acquisition. If access requires license acceptance or authentication, surface that requirement without collecting tokens or accepting terms on the user's behalf.

## Wire the adapter into generation

### DFR detailing

Use `ltx_pipelines.dfr_pipeline` with the **distilled LTX-2.5 transformer**, matching text encoder/VAEs, latent spatial upscaler, and `--detailing-lora PATH` pointing to the native x2 checkpoint. This is the quality-oriented generation path, not an arbitrary finished-video input command.

This checkout fixes DFR's detailing strength at **0.5**; passing another value does not tune it. The model card's **1.0** recommendation is for its standalone IC-LoRA workflow, not an override of the DFR implementation. Do not add a distillation LoRA or replace the distilled transformer with the dev transformer.

DFR's extra reference/keyframe tokens and higher-resolution pass cost memory and time. When longer duration is the priority, prefer a simpler distilled draft, lower resolution, or independently renderable shots before adding DFR. Quantization saves weight memory, not all activation or decoder memory; measure rather than assuming the adapter fits.

### Reference-video adapters

Use `ltx_pipelines.ic_lora` with the distilled model stack, `--lora PATH STRENGTH`, and `--video-conditioning REFERENCE_PATH 1.0`. Loading a generic LoRA without the reference input does not perform the IC-LoRA task.

For Deblur, Decompression, and identity-sensitive Ingredients pilots, use the single-stage reference-conditioned route (`--skip-stage-2`) unless the current verified workflow specifies otherwise. Stage 2 in this checkout has no IC-LoRA reference and may drift. Important: this flag decodes at **half the CLI width and height**. To obtain W x H output, pass width 2W and height 2H and validate the resulting geometry; e.g. 1920 x 1088 CLI canvas produces 960 x 544 output. Do not double duration or FPS.

For a standalone native x2 upscale, keep the reference at half the intended output's linear resolution, with the same framing, duration, and aspect ratio. The adapter's `reference_downscale_factor=2` supplies the reference scaling. Account separately for the CLI's half-canvas rule when using `--skip-stage-2`.

Start Deblur and Decompression at LoRA strength 1.0, then adjust only on observed pilot evidence. For Ingredients, use the current official workflow's strength for the selected base/sampler; do not copy dev-only CFG, step-count, or negative-prompt settings into the distilled CLI, which uses fixed sigmas without those controls. Run live `--help` before building each command. In particular, do not copy model-card flags such as `--tile-reference-encode` or `--lora-strength` unless this checkout actually exposes them.

Use the actual output resolution and FPS for reference preparation. Deblur and Decompression use same-resolution references and need no control extractor. If a source does not satisfy pipeline frame/geometry constraints, explicitly plan the trim, pad, resize, or segmentation; never silently drop frames or change speed.

For Ingredients, build a black-background sheet from approved assets, with readable character, prop, and location panels and no text. Loop it into a static reference video matching output resolution/FPS and at least `max(121, output_frame_count)` frames. Start near the documented 768 x 448, 121-frame, 24 FPS bucket when it meets the approved plan. Preserve the sheet and derived reference video.

The current `ic_lora` CLI generates audio; it does not preserve the reference soundtrack automatically. For visual-only repairs/upscales, keep the original audio separately and remux it into the candidate after confirming frame timing and duration match. Do not replace approved dialogue with newly generated audio. If exact alignment cannot be maintained, stop for an explicit audio/edit decision.

## Task-specific prompt formats

Read the current adapter card before drafting. These trained formats take precedence over the normal single-paragraph T2V prompt layout; the intended action still needs to be chronological and cuts explicit.

- **Deblur:** describe the reference's actual scene and defocus, describe the same scene in sharp focus, include the exact `DEBLUR` trigger, and constrain identity/framing/geometry to remain unchanged.
- **Decompression:** describe the source scene and observed compression damage, describe the clean version, include `ENHANCE QUALITY`, and make clear that only compression damage should change.
- **Ingredients:** use `Reference sheet: <panel descriptions>` followed by `Generated video: <chronological shot description>`. Describe only elements actually present in the approved sheet.
- **Pixel Spatial Upscaler:** describe the same reference scene, motion, materials, and lighting; do not prompt an unrelated scene or invent a trigger.

Keep prompt enhancement off for these prepared adapter prompts so it cannot remove triggers, labels, exact dialogue, or preservation constraints.

## Pilot, review, and records

Before every adapter render, rerun the PyTorch VRAM preflight from `ltx-production.md`. Validate the exact base model, adapter, quantization, sampler, and reference combination on one representative pilot before applying it to a batch. Do not silently ignore incompatible keys or proceed without a selected adapter.

Preserve the source and every candidate under different attempt paths. Compare before/after at matching timestamps for the intended improvement, identity, action, text, flicker, scene geometry, duration, and sound. Ingredients needs comparison against the sheet and adjacent shots, not merely a sharper-looking frame. A successful load or automated score is not approval.

Record each adapter's purpose, official repository, immutable revision, filename, byte size, local SHA-256, absolute local path, compatibility evidence, reference path, pipeline, effective strength, quantization, actual output dimensions/FPS/frame count, and pilot outcome. Use the existing `options`, `conditioning_asset`, and `depends_on` shot-plan columns; retain per-attempt adapter details in state as described in `state.md`. Accept only candidates that improve the requested property without unacceptable regressions, with human approval unchanged.
