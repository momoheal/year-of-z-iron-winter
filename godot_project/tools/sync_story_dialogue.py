#!/usr/bin/env python3
"""Sync the canonical literary script into Godot dialogue data and a full transcript.

English translations are reviewed separately (merge_yoz_en.py). Re-running --sync
preserves every existing `en` line and `title_en` by scene id + line index, so a
Chinese-script refresh never wipes the reviewed translation. If a scene loses
lines, only the indices that still exist are kept; re-run the merge script to
fill any new lines.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/zh/Z年纪事_全量文学剧本_去AI重排整合版.md"
GODOT = ROOT / "godot_project"
DATA_OUT = GODOT / "data/story_dialogue.json"
TRANSCRIPT_OUT = ROOT / "铁冬_全量对话剧本_Gemini.md"
ALLOWED_MOODS = {"calm", "sad", "intense"}
PORTRAIT_ROLES = {
    "aleksei", "chernov", "fyodor", "ivan", "anna", "pasha", "gulya", "lana",
    "pavel", "ash", "leonov", "yelena", "zakhar", "osk",
    "katya", "lyudmila", "vikina",
}

# Every named speaker is explicit. An empty portrait key means the character has
# no matching bust yet; it must not silently borrow Aleksei's face.
SPEAKERS = {
    "旁白 / 阿列克谢": "aleksei",
    "旁白": "aleksei",
    "阿列克谢": "aleksei",
    "调度长": "",
    "“老轨”伊万": "ivan",
    "老轨伊万": "ivan",
    "老轨伊万（列车长）": "ivan",
    "卡佳妈妈": "katya",
    "回退期的母亲": "katya",
    "切尔诺夫中士": "chernov",
    "谢尔盖": "",
    "核算员扎哈尔": "zakhar",
    "核算员": "",
    "柳德米拉大娘": "lyudmila",
    "费奥多尔": "fyodor",
    "费奥多尔老爹": "fyodor",
    "瓦西里": "",
    "帕沙": "pasha",
    "清杀队新兵帕沙": "pasha",
    "古丽娅": "gulya",
    "古丽娅医生": "gulya",
    "梁诺夫医生": "leonov",
    "梁诺夫": "leonov",
    "安娜": "anna",
    "安娜（0419）": "anna",
    "拉娜": "lana",
    "拉娜（0420）": "lana",
    "叶莲娜": "yelena",
    "茹科夫专员": "",
    "假药贩": "",
    "博伊科": "",
    "佳娜": "",
    "帕维尔老爹": "pavel",
    "帕维尔": "pavel",
    "督察专员": "osk",
    "清杀队": "osk",
}

SCENE_RE = re.compile(r"^### 【场次\s*([^：:]+)[：:](.*?)】\s*$")
SPEAKER_RE = re.compile(r"^\*\*(.+?)\*\*\s*$")


def infer_mood(text: str, stage: str = "") -> str:
    sample = stage + text
    if re.search(r"怒吼|嘶吼|尖叫|咆哮|狂奔|猛地|狠狠|扑向|爆炸|枪声|开火|决绝|怒斥|撕裂|挣扎|！！！|！！", sample):
        return "intense"
    if re.search(r"泪|哭|悲|死|冻死|孤|无声|凄|绝望|害怕|疼|痛|告别|哀|失去|不再|眼眶|哽咽|伤口", sample):
        return "sad"
    return "calm"


def split_paragraphs(lines: list[str]) -> list[str]:
    paragraphs: list[str] = []
    current: list[str] = []
    for raw in lines:
        if raw.strip():
            current.append(raw.rstrip())
        elif current:
            paragraphs.append("\n".join(current).strip())
            current = []
    if current:
        paragraphs.append("\n".join(current).strip())
    return paragraphs


def parse_scenes(markdown: str) -> list[dict]:
    lines = markdown.splitlines()
    starts: list[tuple[int, str, str]] = []
    for i, line in enumerate(lines):
        match = SCENE_RE.match(line)
        if match:
            starts.append((i, match.group(1).strip(), match.group(2).strip()))
    scenes: list[dict] = []
    for n, (start, scene_id, title) in enumerate(starts):
        end = starts[n + 1][0] if n + 1 < len(starts) else len(lines)
        body = lines[start + 1 : end]
        for i, line in enumerate(body):
            if line.startswith("## 附录"):
                body = body[:i]
                break

        dialogue: list[dict] = []
        choice_lines: list[str] = []
        speaker = "旁白 / 阿列克谢"
        stage = ""
        in_choices = False
        for paragraph in split_paragraphs(body):
            if paragraph.startswith("---"):
                continue
            if re.match(r"^\*\*【(?:抉择|终局闸)", paragraph):
                in_choices = True
            if in_choices:
                choice_lines.append(paragraph)
                continue
            if paragraph.startswith("### ") or paragraph.startswith("## "):
                continue
            paragraph_lines = paragraph.splitlines()
            first_line = paragraph_lines[0].strip() if paragraph_lines else ""
            speaker_match = SPEAKER_RE.match(first_line)
            if speaker_match:
                candidate = speaker_match.group(1).strip()
                if candidate.startswith("【") or candidate.startswith("👉"):
                    in_choices = True
                    choice_lines.append(paragraph)
                    continue
                if candidate in SPEAKERS or not candidate.endswith(("。", "！", "？", ".", "!", "?")):
                    speaker = candidate
                    paragraph_lines = paragraph_lines[1:]
                else:
                    paragraph_lines[0] = candidate
            content_lines: list[str] = []
            for raw_line in paragraph_lines:
                row = raw_line.strip()
                if not row:
                    continue
                if row.startswith(("（", "(")) and row.endswith(("）", ")")):
                    stage = (stage + " " + row).strip()
                else:
                    content_lines.append(row)
            text = "\n".join(content_lines).replace("\r", "").strip()
            text = re.sub(r"\n+", "\n", text)
            text = re.sub(r"\*\*(.*?)\*\*", r"\1", text)
            text = re.sub(r"(?<!\*)\*(?!\*)(.*?)\*(?!\*)", r"\1", text)
            text = text.replace("`", "")
            if not text:
                continue
            dialogue.append({
                "w": speaker,
                "role": SPEAKERS.get(speaker, "__UNMAPPED__"),
                "mood": infer_mood(text, stage),
                "zh": text,
                "stage": stage,
            })
            stage = ""
        scenes.append({
            "id": scene_id,
            "title": title,
            "lines": dialogue,
            "choices_markdown": "\n\n".join(choice_lines).strip(),
        })
    return scenes


def load_existing_dialogue() -> dict:
    """Read reviewed English translations keyed by (scene id, line index)."""
    if not DATA_OUT.exists():
        return {}
    try:
        data = json.loads(DATA_OUT.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"WARN: cannot read existing dialogue for translation preservation: {exc}",
              file=sys.stderr)
        return {}
    existing: dict[str, dict] = {}
    for scene_id, scene in data.get("scenes", {}).items():
        lines: dict[int, str] = {}
        for index, line in enumerate(scene.get("lines", [])):
            en = str(line.get("en", "")).strip()
            if en:
                lines[index] = en
        existing[str(scene_id)] = {
            "title_en": str(scene.get("title_en", "")).strip(),
            "lines": lines,
        }
    return existing


def make_outputs(scenes: list[dict], existing: dict | None = None) -> tuple[str, str]:
    # 中文剧本重排后按「场景 id + 行号」回填已审校的英文，绝不静默抹掉译文。
    existing = existing or {}
    for scene in scenes:
        prior = existing.get(scene["id"], {})
        if prior.get("title_en"):
            scene["title_en"] = prior["title_en"]
        for index, line in enumerate(scene["lines"]):
            en = prior.get("lines", {}).get(index)
            if en:
                line["en"] = en
    data = {
        "source": "docs/zh/Z年纪事_全量文学剧本_去AI重排整合版.md",
        "moods": sorted(ALLOWED_MOODS),
        "speakers": SPEAKERS,
        "scenes": {scene["id"]: scene for scene in scenes},
    }
    json_text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    output = [
        "# 《Z年纪事：凛冬铁轨》全量对话剧本",
        "",
        "> 本文件由 `godot_project/tools/sync_story_dialogue.py` 从全量文学剧本同步生成。",
        "> 场景正文、选择分支和角色对白以文学剧本为准；每句对白标注 Godot 说话者映射与 calm / sad / intense 情绪。",
        "> 人物映射为空表示角色当前没有专属胸像，游戏不会错误显示阿列克谢的头像。",
        "",
        f"场景数：{len(scenes)}。",
        "",
    ]
    for scene in scenes:
        output.extend([f"## [{scene['id']}] {scene['title']}", ""])
        for i, line in enumerate(scene["lines"], 1):
            role = line["role"]
            role_label = role if role else "无专属胸像"
            text = line["zh"].replace("\n", "\n    ")
            output.append(f"{i:02d}. **{line['w']}**（{line['mood']} / {role_label}）：{text}")
        if scene["choices_markdown"]:
            output.extend(["", "### 原剧本选择与分支", "", scene["choices_markdown"]])
        output.append("")
    return json_text, "\n".join(output).rstrip() + "\n"


def godot_speaker_map() -> dict[str, str]:
    hud = (GODOT / "scripts/CampaignHUD.gd").read_text(encoding="utf-8")
    match = re.search(r"const STORY_SPEAKERS := \{(.*?)\n\}", hud, re.S)
    if not match:
        return {}
    return dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]*)"', match.group(1)))


def validate(scenes: list[dict], json_text: str, transcript_text: str) -> list[str]:
    errors: list[str] = []
    scene_ids = [scene["id"] for scene in scenes]
    if len(scene_ids) != len(set(scene_ids)):
        errors.append("canonical script contains duplicate scene IDs")
    if not scenes:
        errors.append("canonical script contains no scene IDs")
    data = json.loads(json_text)
    transcript_ids = re.findall(r"^## \[([^\]]+)\] ", transcript_text, re.M)
    if scene_ids != transcript_ids:
        errors.append("transcript scene IDs do not exactly match the canonical script")
    if list(data["scenes"].keys()) != scene_ids:
        errors.append("Godot JSON scene IDs do not exactly match the canonical script")
    hud_speakers = godot_speaker_map()
    for scene in scenes:
        for index, line in enumerate(scene["lines"], 1):
            speaker = line["w"]
            if line["mood"] not in ALLOWED_MOODS:
                errors.append(f"{scene['id']} line {index}: invalid mood {line['mood']}")
            if not line["zh"].strip():
                errors.append(f"{scene['id']} line {index}: empty line")
            if speaker not in SPEAKERS:
                errors.append(f"{scene['id']} line {index}: speaker missing from sync map: {speaker}")
            if speaker not in hud_speakers:
                errors.append(f"{scene['id']} line {index}: speaker missing from CampaignHUD: {speaker}")
            elif hud_speakers[speaker] != SPEAKERS.get(speaker):
                errors.append(f"{scene['id']} line {index}: speaker role mismatch: {speaker}")
            if line["role"] == "__UNMAPPED__":
                errors.append(f"{scene['id']} line {index}: unmapped speaker: {speaker}")
            if line["role"] not in PORTRAIT_ROLES and line["role"] != "":
                errors.append(f"{scene['id']} line {index}: unknown portrait role {line['role']}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--sync", action="store_true", help="regenerate the Godot JSON and Markdown transcript")
    mode.add_argument("--check", action="store_true", help="verify IDs, speaker mappings, and mood tags")
    args = parser.parse_args()
    source = SOURCE.read_text(encoding="utf-8")
    scenes = parse_scenes(source)
    existing = load_existing_dialogue()
    json_text, transcript_text = make_outputs(scenes, existing)
    if args.sync:
        DATA_OUT.parent.mkdir(parents=True, exist_ok=True)
        DATA_OUT.write_text(json_text, encoding="utf-8")
        TRANSCRIPT_OUT.write_text(transcript_text, encoding="utf-8")
        print(f"Synced {len(scenes)} scenes -> {DATA_OUT.relative_to(ROOT)} and {TRANSCRIPT_OUT.name}")
    elif DATA_OUT.read_text(encoding="utf-8") != json_text:
        print("FAIL: Godot dialogue JSON is out of sync; run --sync", file=sys.stderr)
        return 1
    elif TRANSCRIPT_OUT.read_text(encoding="utf-8") != transcript_text:
        print("FAIL: full dialogue script is out of sync; run --sync", file=sys.stderr)
        return 1
    errors = validate(scenes, json_text, transcript_text)
    if errors:
        for error in errors:
            print("FAIL:", error, file=sys.stderr)
        return 1
    if args.check:
        print(f"PASS: {len(scenes)} scene IDs; all {sum(len(s['lines']) for s in scenes)} lines have mapped speakers and valid moods.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
