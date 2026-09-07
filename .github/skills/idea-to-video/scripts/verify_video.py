#!/usr/bin/env python3
"""Automated pre-review triage for a rendered shot using Qwen3-Omni.

This is an *advisory triage pass*, not a replacement for Stage 7 (REVIEW) of
the idea-to-video skill. It flags candidate issues so a human reviewer can
focus attention faster; it does not gate approval and its findings must
still be confirmed by watching the shot with audio.

Reuses the same local Qwen3-Omni vLLM server the ltx-trainer captioning
tools talk to (see packages/ltx-trainer/scripts/serve_captioner.py). Launch
that server once, then run this script against a rendered shot:

    # One-time, in a separate terminal:
    uv run --project packages/ltx-trainer python \
        packages/ltx-trainer/scripts/serve_captioner.py

    # Per shot:
    python .github/skills/idea-to-video/scripts/verify_video.py \
        projects/my-video/renders/shot01.mp4 \
        --shot-id shot01 \
        --prompt "the exact generation prompt used for this shot" \
        --project-dir projects/my-video

The result is appended to <project-dir>/review/<shot-id>.md under a
clearly labeled "Automated pre-review" section, alongside (not replacing)
the human-authored review content described in SKILL.md Stage 7.
"""

import argparse
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_VLLM_BASE_URL = "http://127.0.0.1:8001/v1"
DEFAULT_MODEL = "Qwen/Qwen3-Omni-30B-A3B-Thinking"

# Mirrors the Stage 7 (REVIEW) checklist in SKILL.md so the automated pass and
# the human pass look at the same dimensions.
REVIEW_INSTRUCTION = """\
You are performing an automated pre-review triage of one rendered AI video \
shot before a human reviews it. Watch the video and listen to the audio \
track if provided, then report findings against this checklist. Be \
specific (timestamps, what you saw/heard) and concise. Do not invent \
details you cannot verify from the video and audio; if something cannot be \
assessed (e.g. no audio track was provided), say so explicitly instead of \
guessing.

The shot's intended generation prompt is:
\"\"\"
{prompt}
\"\"\"

Report on each of these, one short bullet section per item, using exactly \
these headings:

## Prompt adherence
Does the observed action, in chronological order, match the prompt? Note \
missing, extra, or reordered events.

## Subject and continuity
Subject identity, wardrobe, props, environment, and screen direction -- \
anything that looks inconsistent within the shot.

## Visual defects
Anatomy errors, geometry/warping artifacts, garbled on-screen text, \
flicker, or unready transition frames.

## Camera and pacing
Camera behavior (motion, framing) and whether pacing matches the prompt's \
intent (rushed, stalled, or on-beat).

## Dialogue and audio
Transcribe any dialogue you can hear. Note speaker attribution, omitted or \
invented words, lip-sync, ambience, clipping, unwanted silence, or missing \
audio. If no audio was provided to you, say so instead of assessing sync.

## Overall verdict
One line: likely-fine / needs-human-attention / likely-reject, plus the \
single biggest risk if any.
"""


def _extract_audio_wav(src: Path, dest: Path) -> bool:
    """Best-effort 16kHz mono WAV extraction. Returns False if there's no audio."""
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        return False
    try:
        subprocess.run(
            [ffmpeg, "-y", "-i", str(src), "-vn", "-ac", "1", "-ar", "16000", str(dest)],
            check=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError:
        return False
    return dest.exists() and dest.stat().st_size > 0


def _build_content(video_path: Path, audio_url: str | None, instruction: str) -> list[dict]:
    parts: list[dict] = [{"type": "video_url", "video_url": {"url": f"file://{video_path.resolve()}"}}]
    if audio_url:
        parts.append({"type": "audio_url", "audio_url": {"url": audio_url}})
    parts.append({"type": "text", "text": instruction})
    return parts


def run_review(
    video_path: Path,
    prompt: str,
    base_url: str,
    model: str,
    fps: int,
    max_tokens: int,
    timeout_s: float,
) -> str:
    """Call the Qwen3-Omni server and return its raw triage report text."""
    from openai import OpenAI  # noqa: PLC0415 -- optional dependency, only needed here

    client = OpenAI(base_url=base_url, api_key="EMPTY", timeout=timeout_s)
    instruction = REVIEW_INSTRUCTION.format(prompt=prompt.strip())

    with tempfile.TemporaryDirectory(prefix="verifyvideo_") as tmp:
        wav = Path(tmp) / "audio.wav"
        audio_url = f"file://{wav.resolve()}" if _extract_audio_wav(video_path, wav) else None

        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": _build_content(video_path, audio_url, instruction)}],
            max_tokens=max_tokens,
            temperature=0.0,
            extra_body={
                "repetition_penalty": 1.05,
                "chat_template_kwargs": {"enable_thinking": False},
                "mm_processor_kwargs": {"fps": fps},
            },
        )
        raw = response.choices[0].message.content or ""
        if audio_url is None:
            raw = (
                "_No audio track was extracted (missing ffmpeg, or the clip has no audio stream); "
                "dialogue/sync assessment below is based on video only._\n\n" + raw
            )
        return raw.strip()


def write_review_section(review_dir: Path, shot_id: str, video_path: Path, model: str, report: str) -> Path:
    """Append (or create) review/<shot-id>.md with a labeled automated section."""
    review_dir.mkdir(parents=True, exist_ok=True)
    review_path = review_dir / f"{shot_id}.md"
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    section = f"""
## Automated pre-review ({model}, {timestamp})

**Advisory only -- not a substitute for human review.** Confirm every \
finding below by watching the shot with audio before acting on it.

Source: `{video_path}`

{report}
"""
    with review_path.open("a", encoding="utf-8") as f:
        if review_path.stat().st_size == 0:
            f.write(f"# Review: {shot_id}\n")
        f.write(section)
    return review_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("video", type=Path, help="Path to the rendered shot to triage.")
    parser.add_argument("--shot-id", required=True, help="Shot ID, matching SHOT_PLAN.csv (e.g. shot01).")
    parser.add_argument("--prompt", required=True, help="The exact generation prompt used for this shot.")
    parser.add_argument(
        "--project-dir",
        type=Path,
        default=Path("."),
        help="Project folder containing (or to contain) review/<shot-id>.md. Default: current directory.",
    )
    parser.add_argument("--vllm-url", default=DEFAULT_VLLM_BASE_URL, help="Base URL of the running vLLM server.")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model identifier the server is serving.")
    parser.add_argument("--fps", type=int, default=2, help="Frames per second sampled from the video.")
    parser.add_argument("--max-tokens", type=int, default=2048, help="Max tokens for the triage report.")
    parser.add_argument("--timeout-s", type=float, default=600.0, help="Per-request HTTP timeout.")
    args = parser.parse_args()

    if not args.video.is_file():
        raise SystemExit(f"Video not found: {args.video}")

    report = run_review(
        video_path=args.video,
        prompt=args.prompt,
        base_url=args.vllm_url,
        model=args.model,
        fps=args.fps,
        max_tokens=args.max_tokens,
        timeout_s=args.timeout_s,
    )
    review_path = write_review_section(
        review_dir=args.project_dir / "review",
        shot_id=args.shot_id,
        video_path=args.video,
        model=args.model,
        report=report,
    )
    print(f"Appended automated pre-review to {review_path}")


if __name__ == "__main__":
    main()
