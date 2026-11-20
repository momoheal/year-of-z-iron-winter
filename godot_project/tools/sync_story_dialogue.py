#!/usr/bin/env python3
"""Sync the canonical literary script into Godot dialogue data and a full transcript.

English translations are reviewed separately (merge_yoz_en.py). Re-running --sync
preserves every existing `en` line and `title_en` by scene id + speaker + source
text, so adding a line cannot silently attach a translation to the wrong dialogue.
New or rewritten lines stay untranslated until reviewed or explicitly overridden.
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
    "katya", "lyudmila", "vikina", "dispatcher", "sergei", "accountant",
    "vasily", "zhukov", "medicine_seller", "boyko", "jana",
}

# Curated translations for lines rewritten in the canonical Chinese script.
# Keyed by scene id and exact Chinese text so line insertions cannot shift them.
ENGLISH_OVERRIDES = {
    ("3-2", "这里是诺沃斯克-17 最后的地下黑市。废弃机车库的铁轨间挤着帆布棚、补锅摊和换药的柜台；炉火把棚顶熏黑，几处灯还亮着，摊主敲打零件的声音一直没停。清杀队的巡逻车只在外围绕行——棚户巷窄，废车和岔道多，灯一照进去，反倒成了私兵的靶场。几名拿旧步枪和道钉枪的守卫看住出入口，狂暴者闯近时，他们就鸣枪把人赶回铁轨另一侧。"):
        "This is the last underground market in Novorsk-17. Canvas stalls, repair benches, and medicine counters crowd the tracks between abandoned locomotives. Stove smoke blackens the roofs; a few lamps still burn, and stallholders keep hammering at parts. OSK patrol trucks circle the perimeter but do not enter the narrow lanes and branching rows of derelict cars. Armed guards with old rifles and rail spikes watch the entrances, driving Rabid back across the tracks when they come near.",
    ("3-2", "这里谈不上富足，但比配给站更像一个还在运转的地方：有人修鞋、有人磨刀，也有人拿半袋煤换一把抗生素。被户籍簿和配给表一笔划掉的人，都挤在这片黑区里，靠交换、修补和彼此守夜撑下去。"):
        "There is no real abundance here, but the place feels more alive than the ration office: someone repairs boots, someone sharpens knives, someone trades half a sack of coal for antibiotics. People crossed out of the census and ration ledgers crowd into this black zone, surviving by barter, repairs, and keeping watch for one another.",
    ("3-2", "几个药贩子围在一台老式矿石收音机旁。短波 6.66 MHz 上反复传出黑市商贩的买卖暗号：【六六六……土豆换鳞粉……烙铁保平安……】。那是摊主招揽生意的呼号，不是求救信号。"):
        "A few medicine sellers crowd around an old crystal radio. On shortwave 6.66 MHz, the black-market traders repeat their barter code: [Six-six-six... potatoes for scale-powder... the branding iron keeps you safe...]. It is a call for business, not a distress signal.",
    ("3-2", "几个药贩子围在一台老式矿石收音机旁。短波 6.66 MHz 上反复传出黑市商贩的买卖暗号：【六六六……土豆换鳞粉……烙铁保平安……】那是摊主招揽生意的呼号，不是求救信号。"):
        "A few medicine sellers crowd around an old crystal radio. On shortwave 6.66 MHz, the black-market traders repeat their barter code: [Six-six-six... potatoes for scale-powder... the branding iron keeps you safe...]. It is a call for business, not a distress signal.",
    ("3-2", "喊什么喊！烫成三级烧伤，清杀队的刮片枪就测不出反应！这就叫‘工业事故’，懂不懂？不然明早直接拉上铁壳号！"):
        "What are you yelling about? Burned that badly, their scraper won't register anything. That's an ‘industrial accident,’ understand? Otherwise, they'll put you straight on the Buran in the morning!",
    ("3-2", "小子，内务部特勤连押的是一百七十六个退了烧的人。疗养所是写给家属看的。铁壳号真要去鹰嘴崖 3 号废矿。列车一进矿区，他们就封死洞口，把人和账一道抹掉。发车时刻我不知道，只有西站调度室那道盖红章的令上有。"):
        "Kid, the OSK special unit is escorting a hundred and seventy-six people whose fevers have broken. The sanatorium is what they tell the families. The Buran is really headed to the abandoned Pit No. 3 at Eagle's Crag. Once the train enters the mine, they will seal the entrance and erase the people along with the records. I don't know the departure time; only the red-stamped order in the West Station dispatch room has it.",
    ("3-2", "我在这条山线上开了二十五年。西站有张检修图，抄出来。车真停在鹰嘴崖，你得先知道从哪儿下到谷底。还有，市场东边那间旧信号检修室，我在 4.17 MHz 上听到过几秒短波回声。清杀队的监听组正在找这段频率，发报的人应该还在附近。"):
        "I've driven this mountain line for twenty-five years. I copied a maintenance map from West Station. If the train stops at Eagle's Crag, you need to know how to get down to the valley. There's something else: I heard a few seconds of shortwave echo at 4.17 MHz from the old signal workshop east of the market. The OSK listening unit is tracking that frequency. Whoever sent it should still be nearby.",
    ("3-2A", "市场地图东侧棚户巷标着一间旧铁路信号检修室。阿列克谢推开门时，收音机的 6.66 MHz 买卖暗号已经听不见了；桌上的短波机却刚从 4.17 MHz 切回静音。电池、手摇发电柄和压在旋钮下的庄园平面图说明，这个固定发射点已用了很久。内务部的监听组也在追这段频率，附近每多响几秒，搜查圈就会收紧一圈。"):
        "The market map marks an old railway signal workshop in the eastern shanty lane. When Aleksei opens the door, the traders' 6.66 MHz code is gone; the shortwave set on the table has just gone silent from 4.17 MHz. Batteries, a hand crank, and a manor plan pressed under the dial show that this fixed transmission point has been in use for a long time. OSK's listening unit is tracking the frequency; every few seconds on air tightens the search around it.",
    ("3-2A", "门后的女人没有举枪。她先关掉发射机，再把监听耳机摘下来。她是茹科夫专员的女儿叶莲娜，也是这条秘密广播的架设者。她用低功率的 4.17 MHz 短波，断续向城外的医疗救援频道通报退烧者仍然活着；内务部正沿着这段频率测向搜查。她把发射点固定在这间旧信号检修室，也保留了一条从排污检修管进入松林庄园的路线。"):
        "The woman behind the door does not raise a gun. She switches off the transmitter and removes her headphones. She is Yelena, Commissioner Zhukov's daughter, and the one who built the secret broadcast. In brief, low-power bursts on 4.17 MHz, she tells a medical rescue channel outside the city that those whose fevers broke are still alive. OSK is triangulating the frequency. She keeps the transmitter in this fixed workshop and has preserved a route into Pine Manor through the drainage duct.",
    ("3-2A", "你知道他们已经在追这段频率了吗？"):
        "You know they're already tracking this frequency?",
    ("3-2A", "我播了很多次。终于有人回话，我却先把发射机关了。我父亲把账本和第三节的记录锁在庄园里。排污管格栅松了，我带你进去。"):
        "I've sent the message many times. When someone finally answered, I shut the transmitter off first. My father has the ledgers and Boxcar Three's records locked in the manor. The drainage grate is loose. I'll take you in.",
    ("3-2A", "知道。天线我已经收了。先把门打开，出去以后再算。"):
        "I know. I've folded the antenna away. Open the door first. We'll count the cost after we get out.",
    ("3-3", "别替我算这笔账。门是我开的，水是我递的，4.17 MHz 的短波也是我架的。你说划掉的名字就是死人。好，写叶莲娜。盖你的红章，叫他们把我也装进第三节。"):
        "Don't balance this for me. I opened the door, I brought the water, and I set up the 4.17 MHz transmitter. You said a crossed-out name was a dead person. Fine. Write Yelena. Stamp it red and have them put me in Boxcar Three.",
    ("3-3", "刚才那车透析液推进炉子时，你闻见了吗？外头有人为半勺麦糊告密。你把救命的药烧了，让我在这二十六度的屋里喝茶。"):
        "Did you smell the dialysis fluid when they pushed that cart into the furnace? Outside, people inform on one another for half a spoonful of mash. You burned life-saving medicine so I could drink tea in this room at twenty-six degrees.",
    ("1-4A", "阿列克谢踩响一块冻裂的冰壳。扎哈尔猛地抬头，正往棉袄里塞的滤芯掉在雪上。远处巡逻灯扫过来；他看了阿列克谢一眼，脸上的血色退了个干净。"):
        "Aleksei's boot crunches on a patch of frozen ice. Zakhar jerks his head up; the filter cartridge he was slipping into his coat falls into the snow. A patrol light sweeps across the yard. He looks at Aleksei, and the color drains from his face.",
    ("1-4A", "别喊巡逻队。我叫扎哈尔。以前我替配给站登记每一袋粮，后来那本账上只剩空格。你不把这只滤芯的事报上去，我就跟你走，替你认废料、找补给。别把这当忠诚——我只是不想再挨饿。"):
        "Don't call the patrol. My name is Zakhar. I used to record every sack at the ration office; now that ledger holds nothing but blanks. If you don't report this filter, I'll come with you and help identify salvage and find supplies. Don't mistake it for loyalty. I just don't want to go hungry again.",
    ("1-4A", "阿列克谢问他，如果清杀队愿意拿配额换一份举报，他会怎么做。扎哈尔没有否认，只用拇指擦掉账本封面上的冻泥。"):
        "Aleksei asked what Zakhar would do if the OSK offered him a ration quota in exchange for a denunciation. Zakhar did not deny it; he only wiped the frozen mud from the ledger's cover with his thumb.",
    ("1-4A", "要是他们给的配额比你给的多，我会把知道的都报上去。账不会替谁讲情。"):
        "If they offer me a larger quota than you do, I'll report everything I know. A ledger pleads for no one.",
    ("2-3", "他叫瓦西里·费奥多罗维奇。把名字、年纪和工种都记上：二十岁，机务段的三级司炉工。等全城的门砸开那天，你当着大伙的面，把他的名字念出来。"):
        "His name was Vasily Fyodorovich. Write down his name, age, and trade: twenty years old, a third-grade stoker in the locomotive depot. When the doors across the city finally come down, read his name aloud in front of everyone.",
    ("2-4", "第三十七例！阿廖沙，这是第三十七例完整记录！只要给他们水，熬过第四天的高热和抽搐，灰鳞就会开始剥落！这不是绝症，他们能自己挺过来！"):
        "Case thirty-seven! Alyosha, the thirty-seventh complete record! Keep them hydrated and get them through the fever and convulsions on the fourth day; the Grey Scale starts to slough off! This isn't terminal. They can pull through on their own.",
    ("2-4", "在靠墙的一张铁床上，用医用牛皮带死死绑着一个年轻女孩。她在高烧中昏睡了三天，几乎没有醒来，手腕被皮带磨得皮开肉绽。但此刻，她身上的高热正在消退，原本硬化如蛇皮的灰白角质正大片大片地从胸口和颈部剥落，露出底下粉红色的新生皮肤。她的呼吸虚弱而均匀。"):
        "On an iron bed against the wall, a young girl is strapped down with medical leather belts. She has spent three days lost in a fevered sleep, barely waking; the straps have rubbed her wrists raw. But now her fever is breaking. Grey-white keratin, hardened like snakeskin, is sloughing from her chest and neck in great sheets, revealing pink new skin beneath. Her breathing is faint but even.",
    ("2-4", "铁床上的女孩突然发出一声微弱的呻吟。阿列克谢猛地转过头。"):
        "The girl on the iron bed lets out a faint moan. Aleksei turns sharply toward her.",
    ("2-4", "她艰难地睁开眼睛，瞳孔清澈透明。她看了看阿列克谢胸前的铁路调度工牌，又看向他大衣口袋里露出的妹妹照片，干裂的嘴唇吃力地开合："):
        "She opens her eyes with difficulty, her pupils clear. She looks at the railway dispatcher's badge on Aleksei's chest, then at the photograph of his sister peeking from his coat pocket. Her cracked lips move with effort:",
    ("2-4", "是我妹妹。你怎么会在疗养院？"):
        "She's my sister. How did you get to the sanatorium?",
    ("2-4", "我是安娜，档案号 0419。清杀队来留观站押人时，我烧到休克，被当成死人丢在站台上。梁医生和古丽娅发现我还有气，把我带回疗养院。高烧时我怕伤人，才用皮带把自己绑在床栏上。"):
        "I'm Anna, file 0419. When the OSK came to take people from the observation ward, I went into shock from the fever and collapsed on the platform. They left me there for dead. Dr. Leonov and Gulya found I was still breathing and brought me back to the sanatorium. I was afraid I'd hurt someone in the fever, so I strapped myself to the bed rail.",
    ("2-4", "那你最后一次见拉娜时，她还醒着吗？"):
        "When you last saw Lana, was she still awake?",
    ("2-4", "昨晚装车前，我短暂醒过一次。拉娜让我再看一眼体温计：三十六度八。她手背的鳞都掉了，还隔着铁网把半片阿司匹林塞给我。她让我记住你在货运站，说你会来接她。"):
        "Before they loaded her last night, I woke briefly. Lana asked me to check the thermometer once more: thirty-six point eight. The scales had fallen from the back of her hand. She slipped me half an aspirin through the wire. She told me to remember you worked at the freight yard and said you would come for her.",
}

ENGLISH_TITLE_OVERRIDES = {
    "3-2": "The Black Market and Old Ivan's Route Map",
    "3-2A": "4.17 MHz and the Old Signal Workshop",
}

# Every named speaker is explicit. An empty portrait key means the character has
# no matching bust yet; it must not silently borrow Aleksei's face.
SPEAKERS = {
    "旁白 / 阿列克谢": "aleksei",
    "旁白": "aleksei",
    "阿列克谢": "aleksei",
    "调度长": "dispatcher",
    "“老轨”伊万": "ivan",
    "老轨伊万": "ivan",
    "老轨伊万（列车长）": "ivan",
    "卡佳妈妈": "katya",
    "回退期的母亲": "katya",
    "切尔诺夫中士": "chernov",
    "谢尔盖": "sergei",
    "核算员扎哈尔": "zakhar",
    "核算员": "accountant",
    "柳德米拉大娘": "lyudmila",
    "费奥多尔": "fyodor",
    "费奥多尔老爹": "fyodor",
    "瓦西里": "vasily",
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
    "茹科夫专员": "zhukov",
    "假药贩": "medicine_seller",
    "博伊科": "boyko",
    "佳娜": "jana",
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
            if line.startswith("## "):
                body = body[:i]
                break

        dialogue: list[dict] = []
        choice_lines: list[str] = []
        speaker = "旁白 / 阿列克谢"
        stage = ""
        in_choices = False
        for paragraph in split_paragraphs(body):
            if paragraph.startswith(("---", "> **演出备注**")):
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
            # An explicit speaker label applies to one dialogue block. The next
            # unlabelled paragraph is narration, even within the same scene.
            speaker = "旁白 / 阿列克谢"
            stage = ""
        scenes.append({
            "id": scene_id,
            "title": title,
            "lines": dialogue,
            "choices_markdown": "\n\n".join(choice_lines).strip(),
        })
    return scenes


def load_existing_dialogue() -> dict:
    """Read reviewed English translations keyed by scene id and line identity."""
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
        lines: dict[tuple[str, str, str, str], str] = {}
        for line in scene.get("lines", []):
            en = str(line.get("en", "")).strip()
            if en:
                key = (
                    str(line.get("w", "")),
                    str(line.get("role", "")),
                    str(line.get("zh", "")).strip(),
                    str(line.get("stage", "")).strip(),
                )
                lines[key] = en
        existing[str(scene_id)] = {
            "title_en": str(scene.get("title_en", "")).strip(),
            "lines": lines,
        }
    return existing


def make_outputs(scenes: list[dict], existing: dict | None = None) -> tuple[str, str]:
    # 按「场景 id + 说话者 + 中文原文 + 舞台说明」回填译文，避免插行后错配。
    existing = existing or {}
    for scene in scenes:
        prior = existing.get(scene["id"], {})
        if scene["id"] in ENGLISH_TITLE_OVERRIDES:
            scene["title_en"] = ENGLISH_TITLE_OVERRIDES[scene["id"]]
        elif prior.get("title_en"):
            scene["title_en"] = prior["title_en"]
        for line in scene["lines"]:
            key = (
                str(line.get("w", "")),
                str(line.get("role", "")),
                str(line.get("zh", "")).strip(),
                str(line.get("stage", "")).strip(),
            )
            en = ENGLISH_OVERRIDES.get((scene["id"], line["zh"]))
            if not en:
                en = prior.get("lines", {}).get(key)
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
