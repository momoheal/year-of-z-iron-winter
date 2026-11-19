"""Run with Python 3 after export_story_archive.gd. Emits the GitHub Pages HTML."""

import argparse
import html
import json
import re
from pathlib import Path
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "deliverables/story_review"
PROJECT = ROOT / "godot_project"

# Map, chapter and cast annotations are editorial. Captions come from the game.
SCENES = {
    "prologue": ("602 室与货运调度室", "序章", "阿列克谢、卡佳、拉娜、清杀队"),
    "coldstore": ("coldstore", "第一幕", "阿列克谢、切尔诺夫、谢尔盖、玛丽亚、灰烬"),
    "yard": ("yard", "第一幕", "阿列克谢、扎哈尔"),
    "redzone_mother": ("yard", "第一幕", "阿列克谢、退烧的母亲、清杀队"),
    "pasha_watchtower": ("marshalling", "第一幕", "阿列克谢、帕沙"),
    "canteen": ("canteen", "第二幕", "阿列克谢、瓦西里、费奥多尔"),
    "canteen_vasily_qte": ("canteen", "第二幕", "阿列克谢、瓦西里、费奥多尔"),
    "canteen_aftermath": ("canteen", "第二幕", "阿列克谢、瓦西里、费奥多尔"),
    "sanitarium": ("sanitarium", "第二幕", "阿列克谢、梁诺夫、古丽娅、安娜"),
    "mother": ("602 室", "据点", "阿列克谢、卡佳"),
    "mother_waiting": ("602 室", "据点", "阿列克谢、卡佳"),
    "mother_memory": ("602 室", "据点", "阿列克谢"),
    "fluid_given": ("602 室", "据点", "阿列克谢、卡佳"),
    "vikina_lead": ("602 室", "据点", "阿列克谢、维京娜"),
    "market": ("market", "第三幕", "阿列克谢、药贩、伊万"),
    "market_refuge": ("market", "第三幕", "阿列克谢"),
    "broadcast": ("market", "第三幕", "阿列克谢、叶莲娜"),
    "manor": ("manor", "第三幕", "阿列克谢、茹科夫、维克多"),
    "manor_confrontation": ("manor", "第三幕", "阿列克谢、茹科夫"),
    "manor_outcome": ("manor", "第三幕", "阿列克谢"),
    "mine_inscriptions": ("mine", "第四幕", "阿列克谢、矿工（留字）"),
    "marshalling": ("marshalling", "第四幕", "阿列克谢、随行伙伴"),
    "archive_copy": ("archive", "调查支线", "阿列克谢"),
    "fire_rescue": ("第 3 居住区楼梯间", "第五幕", "阿列克谢、柳德米拉、佳娜、居民"),
    "station_buran_yard": ("station_buran_yard", "第五幕", "阿列克谢"),
    "station_route": ("station_buran_yard", "第五幕", "阿列克谢"),
    "eagle_beak_cliff": ("eagle_beak_cliff", "第五幕", "阿列克谢"),
    "crag_reveal": ("eagle_beak_cliff", "第五幕", "阿列克谢、拉娜、车厢幸存者"),
    "eagle_escape": ("eagle_beak_cliff", "第五幕", "阿列克谢、拉娜"),
    "evidence_handover": ("602 室", "第六幕", "阿列克谢"),
    "broadcast_tower_302": ("broadcast_tower_302", "第六幕", "阿列克谢、拉娜"),
    "broadcast_complete": ("broadcast_tower_302", "第六幕", "阿列克谢、听众"),
    "zakhar_betrayed": ("清杀队岗亭", "条件余波", "阿列克谢、扎哈尔"),
    "mother_lost": ("602 室", "条件余波", "阿列克谢"),
    "ENDING_A_RETURN_HOME": ("602 室", "结局", "阿列克谢、卡佳"),
    "ENDING_B_FLAWED_LIBERATION": ("broadcast_tower_302", "结局", "阿列克谢、拉娜"),
    "ENDING_C_NUMBNESS": ("602 室与地窖", "结局", "阿列克谢"),
    "TRUE_ALPHA_HELLO_LANA": ("602 室", "结局", "阿列克谢、拉娜、卡佳"),
    "TRUE_BETA_OUTLAND_FIRE": ("城外雪原", "结局", "阿列克谢、拉娜"),
    "pasha_epilogue": ("eagle_beak_cliff", "结局余波", "帕沙、无名女子、阿列克谢"),
}
TITLES = dict(zip(SCENES, [
    "封城第十个月", "账面死人", "铁壳号编组单", "退烧的母亲", "假人哨塔",
    "东街食堂", "食堂卡刀", "费奥多尔的回访", "回退手稿", "和母亲说话", "母亲在等",
    "母亲的遗物", "交付透析液", "维京娜的线索", "黑市与老轨", "失母后的黑市暂住",
    "6.66 MHz", "松林庄园", "父女对峙", "庄园行动结果", "岩壁刻字", "西站发车令",
    "档案馆退件", "焊死的单元门", "南侧编组线", "交接底单", "鹰嘴崖进场", "打开第三节车厢",
    "鹰嘴崖撤离", "602 室证据交接", "302 广播塔", "广播完成", "扎哈尔离队", "602 室的空床",
    "A 留在 602", "B 荒诞解放", "C 麻木", "α 你好，拉娜", "β 荒原之火", "帕沙的防化服",
], strict=True))
MAPS = dict(zip(
    "boiler coldstore yard underpass canteen sanitarium market manor marshalling mine birch workshop greenhouse archive station_buran_yard eagle_beak_cliff broadcast_tower_302".split(),
    "Boiler Coldstore Yard Underpass Canteen Sanitarium Market Manor Marshalling MineNo3 Birch Workshop Greenhouse Archive StationBuranYard EagleBeakCliff BroadcastTower302".split(),
    strict=True,
))
ENTRY = {
    "redzone_mother": "战役货场首次靠近锅炉房通风口",
    "canteen_vasily_qte": "瓦西里扑出后的近战输入",
    "canteen_aftermath": "瓦西里死亡并完成相应夜潜后",
    "mine_inscriptions": "首次靠近矿坑爆破断面",
    "fire_rescue": "开启鹰嘴崖行动前，按同行者选页",
    "crag_reveal": "搜索第三节车厢目标后，撤离前必须选择",
    "eagle_escape": "完成有效撤离后按救援范围分流",
    "station_route": "带回交接底单后标记检修线",
    "manor_confrontation": "庄园战役选择确认后的过场",
    "manor_outcome": "完成对应现场目标并结算后",
    "broadcast_complete": "完成播报后，按操作者及公开范围分流",
    "ENDING_A_RETURN_HOME": "无真相证据，母亲在世",
    "ENDING_C_NUMBNESS": "无真相证据，母亲离世",
    "ENDING_B_FLAWED_LIBERATION": "真相在手，有划痕",
    "TRUE_ALPHA_HELLO_LANA": "真相在手，母亲在世，零划痕，未被出卖",
    "TRUE_BETA_OUTLAND_FIRE": "真相在手，零划痕，母亲离世或触发背叛",
    "pasha_epilogue": "帕沙目击与鹰嘴崖存活旗标同时成立",
}
CAST_PORTRAITS = {
    "阿列克谢": "Aleksei", "卡佳": "Katya", "拉娜": "Lana", "切尔诺夫": "Chernov",
    "谢尔盖": "Sergei", "费奥多尔": "Fyodor", "瓦西里": "Vasily", "梁诺夫": "Leonov",
    "茹科夫": "Zhukov", "帕沙": "Pasha", "柳德米拉": "Lyudmila", "佳娜": "Jana",
    "维京娜": "Vikina", "药贩": "MedicineSeller", "博伊科": "Boyko",
}


def esc(value):
    return html.escape(str(value or ""))


def image(path, alt, cls=""):
    if not path:
        return ""
    path = path.removeprefix("res://")
    if not (PROJECT / path).is_file():
        raise FileNotFoundError(path)
    url = "../../godot_project/" + quote(path)
    return f'<a class="{cls}" href="{url}"><img src="{url}" alt="{esc(alt)}" loading="lazy"></a>'


def bilingual(zh, en):
    return f'<p class="caption">{esc(zh)}</p>' + (
        f'<details class="translation"><summary>English</summary><p>{esc(en)}</p></details>' if en else ""
    )


def choices(options):
    if not options:
        return ""
    rows = []
    for item in options:
        result = item.get("toast_zh") or item.get("d_zh")
        row = f'<li>{esc(item.get("zh"))}' + (f'<p>{esc(result)}</p>' if result else "")
        if item.get("en"):
            row += '<details class="translation"><summary>English</summary>'
            row += f'<p>{esc(item["en"])} {esc(item.get("toast_en") or item.get("d_en"))}</p></details>'
        if "followup" in item:
            followup = item["followup"]
            row += image(followup.get("img"), "选项追加幻灯", "cg")
            row += image(followup.get("portrait"), "游戏指定头像", "portrait")
            row += bilingual(followup.get("zh"), followup.get("en"))
        rows.append(row + "</li>")
    return '<aside><strong>选项与回执</strong><ol>' + "".join(rows) + "</ol></aside>"


def dialogue(lines):
    return "".join(
        f'<p><b>{esc(line.get("w") or "旁白")}</b> {esc(line.get("stage"))} {esc(line.get("zh"))}</p>'
        for line in lines
    )


def slide(page, number, title):
    visuals = page.get("img", [])
    if isinstance(visuals, str):
        visuals = [visuals]
    pictures = "".join(image(path, f"{title} 第 {number} 页的 CG", "cg") for path in visuals)
    portrait = image(page.get("portrait"), "游戏指定头像", "portrait")
    lines = page.get("lines_zh")
    text = bilingual(page.get("zh"), page.get("en"))
    if lines is not None:
        text = dialogue(lines) + '<details class="translation"><summary>English</summary>'
        text += "".join(f'<p>{esc(line.get("en"))}</p>' for line in page["lines_en"]) + "</details>"
    if page.get("qte"):
        text += f'<p class="meta">QTE 操作 · {esc(page["qte"].get("prompt_zh"))}</p>'
    if page.get("required_choice"):
        text += '<p class="meta">必选 · 播完后继续夜潜，撤离成功才结算</p>'
    return f'<li class="frame"><div>{pictures}</div><div>{portrait}{text}{choices(page.get("choices"))}</div></li>'


def record(title, group, meta, content, anchor, search=""):
    search = esc(" ".join([title, group, meta, search]))
    return (f'<details class="record" id="{anchor}" data-group="{esc(group)}" data-search="{search}">'
            f'<summary><strong>{esc(title)}</strong><span>{esc(meta)}</span></summary>{content}</details>')


def main(export):
    data = json.loads(export.read_text(encoding="utf-8"))
    literary = json.loads((PROJECT / "data/story_dialogue.json").read_text(encoding="utf-8"))["scenes"]
    locations = {loc["id"]: loc for loc in data["locations"]}
    deck_rows = []
    for index, deck in enumerate(data["decks"]):
        ident, group, variant = (deck[key] for key in ("id", "group", "variant"))
        place, stage, cast = SCENES[ident]
        for person in ("叶莲娜", "帕维尔", "灰烬", "伊万", "古丽娅", "安娜", "扎哈尔"):
            if person in variant and "缺席" not in variant and person not in cast:
                cast += "、" + person
        place_name = locations.get(place, {}).get("zh", place)
        title = TITLES[ident]
        meta = " / ".join(filter(None, [stage, place_name, group, variant]))
        extra = ENTRY.get(ident, "")
        if group == "抉择余波表":
            extra = "静态余波表。部分旧选项已由现场过场替代，触发以游戏入口为准。"
        if place in MAPS:
            extra = esc(extra) + f' <a href="#map-{place}">查看地图</a>'
        else:
            extra = esc(extra)
        slides = "".join(slide(p, n, title) for n, p in enumerate(deck["pages"], 1))
        body = f'<p class="cast">出场或被记录人物　{esc(cast)}</p><p>{extra}</p><ol class="frames">{slides}</ol>'
        key = f"deck-{ident}-{index + 1}"
        deck_rows.append((stage, record(title, group, meta, body, key, f"{cast} {ident}")))

    stages = ["序章", "据点", "第一幕", "第二幕", "第三幕", "第四幕", "调查支线", "第五幕", "第六幕", "条件余波", "结局", "结局余波"]
    deck_rows.sort(key=lambda row: stages.index(row[0]))
    records = [row for _, row in deck_rows]
    for loc in data["locations"]:
        key = loc["id"]
        folder = MAPS[key]
        body = f'<p>{esc(loc["hint_zh"])} {esc(loc["hint2_zh"])}</p>'
        body += image(f"art/80_maps/{folder}/map_night.png", loc["zh"] + " 夜景", "cg")
        body += f'<p><a href="../../godot_project/art/80_maps/{folder}/map.png">查看日景</a> · <a href="../../godot_project/{quote(loc["scene"].removeprefix("res://"))}">场景文件</a></p>'
        records.append(record(loc["zh"], "地图", "地图 / 夜景与日景", body, f"map-{key}"))

    for mate in data["mates"]:
        if mate["id"] == "none":
            continue
        ident = mate["id"]
        portrait_name = {"ivan": "Ivan", "gulya": "Gulya", "pavel": "Pavel", "ash": "Ash",
                         "anna": "Anna", "zakhar": "Zakhar", "yelena": "Yelena"}.get(ident, "")
        path = f"art/10_characters/portraits/PRT_{portrait_name}_Calm.png"
        body = image(path, mate["zh"], "portrait") if (PROJECT / path).is_file() else ""
        body += f'<p>{esc(mate["lock_zh"])}</p>'
        records.append(record(mate["zh"], "伙伴", "伙伴档案", body, f"mate-{ident}"))

    for name, portrait in CAST_PORTRAITS.items():
        links = []
        for index, deck in enumerate(data["decks"]):
            ident = deck["id"]
            if name in SCENES[ident][2].split("、"):
                links.append(f'<li><a href="#deck-{ident}-{index + 1}">{esc(TITLES[ident])} {esc(deck["variant"])}</a></li>')
        body = image(f"art/10_characters/portraits/PRT_{portrait}_Calm.png", name, "portrait")
        if links:
            body += "<ul>" + "".join(links) + "</ul>"
        records.append(record(name, "人物", "人物立绘与相关演出", body, f"cast-{portrait}"))

    hud = (PROJECT / "scripts/CampaignHUD.gd").read_text(encoding="utf-8")
    shaft = hud.split("func _build_choice_modal()", 1)[1].split("\nfunc ", 1)[0]
    pairs = re.findall(r'_tr\(\s*("(?:[^"\\]|\\.)*"),\s*("(?:[^"\\]|\\.)*")\s*\)', shaft)
    body = "".join(bilingual(json.loads(zh), json.loads(en)) for zh, en in pairs)
    records.append(record("暖气井回退者", "现场对白", "夜潜 / 旧版遭遇面板", body, "heating-shaft"))

    for key, bark in data["barks"].items():
        body = image("art/10_characters/portraits/PRT_OSK_Concept.png", "清杀队头像", "portrait")
        body += "".join(bilingual(line["zh"], line["en"]) for line in bark["lines"])
        records.append(record(bark["speaker_zh"], "战斗喊话", "夜潜 / 清杀队", body, f"bark-{key}"))
    for evt in data["events"]:
        body = bilingual(evt["zh"], evt["en"]) + choices(evt["choices"])
        records.append(record(evt["title"], "随机遭遇", "运行时事件资源 / 触发地点随遭遇规则", body, f'event-{evt["id"]}'))
    for key, scene in literary.items():
        title = scene.get("title_zh") or scene.get("title") or key
        body = dialogue(scene["lines"])
        body += '<details class="translation"><summary>English</summary>'
        body += "".join(f'<p>{esc(line.get("en"))}</p>' for line in scene["lines"] if line.get("en"))
        body += "</details>"
        body += f'<p class="caption">{esc(scene.get("choices_markdown"))}</p>'
        records.append(record(title, "文学剧本", f"{key} / 文学底稿（可与战役对白对照）", body, f"script-{key}"))

    audit = (OUT / "z6-audit.md").read_text(encoding="utf-8")
    cells = [line.strip("| ").split(" | ") for line in audit.splitlines() if line.startswith("| ")]
    audit_table = '<table><thead><tr>' + "".join(f"<th>{esc(cell)}</th>" for cell in cells[0]) + "</tr></thead><tbody>"
    for row in cells[2:]:
        audit_table += "<tr>" + "".join(f"<td>{esc(cell)}</td>" for cell in row) + "</tr>"
    audit_table += "</tbody></table>"

    page = (ROOT / "godot_project/tools/story_archive_template.html").read_text(encoding="utf-8")
    page_count = sum(len(deck["pages"]) for deck in data["decks"] if deck["group"] != "战役对白")
    page_count += sum("followup" in choice for deck in data["decks"] for p in deck["pages"] for choice in p.get("choices", []))
    counts = f'{page_count} 页幻灯（含分支） · {len(locations)} 张战役地图 · {len(literary)} 场文学底稿'
    replacements = {"COUNTS": counts, "AUDIT": audit_table, "RECORDS": "\n".join(records)}
    output = re.sub(r"@@(COUNTS|AUDIT|RECORDS)@@", lambda match: replacements[match[1]], page)
    (OUT / "index.html").write_text(output, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path, help="JSON exported by Godot")
    main(parser.parse_args().export)
