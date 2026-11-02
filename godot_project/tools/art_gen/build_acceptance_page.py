"""build_acceptance_page.py — 把 docs/ui/verify/ 里的验收图做成可以点开看的网页。

做两件事：
1. 生成网页用的缩图（JPEG，长边 1600，`docs/ui/verify/web/`），原 PNG 保持不动；
2. 生成两个页面：
   - `docs/ui/acceptance.html`：图片走相对路径，给静态服务器（8080 预览）用；
   - `docs/ui/acceptance_standalone.html`：图片内嵌成 base64，单文件，离线双击也能看。

用法（在仓库根目录或任意目录）：
    python3 godot_project/tools/art_gen/build_acceptance_page.py
"""
from __future__ import annotations

import base64
import io
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
VERIFY = os.path.join(REPO, "docs", "ui", "verify")
WEB = os.path.join(VERIFY, "web")
OUT = os.path.join(REPO, "docs", "ui")

# file, 关卡标签, 场景文件, 区域, 尺寸标签, 中文验收点[], 英文验收点[], 分组
SHEETS = [
    dict(file="yard_grey.png", level="L03 · ШИРОКАЯ КОЛЕЯ · 宽轨货场",
         scene="res://scenes/night_explore.tscn", area="整关 48×40 m · 中性光",
         zh=["五层赫鲁晓夫楼立面 + 亮窗、配电箱、告示板、钠路灯、铁网、扳道房、水塔是否连成一条街",
             "角色是否踩在雪地上、比例对不对（1 m = 64 px）",
             "警戒线 / 铁网 / 轨道三层纵深有没有把画面压平"],
         en=["Does the block facade + lit windows + fuse box + notice board + sodium lamps + fence read as one street?",
             "Are actors standing on snow at the right scale (1 m = 64 px)?",
             "Do fence / tracks / yard keep three layers of depth?"],
         group="level"),
    dict(file="yard_night.png", level="L03 · ШИРОКАЯ КОЛЕЯ · 宽轨货场",
         scene="res://scenes/night_explore.tscn", area="整关 · 夜色",
         zh=["CanvasModulate 冷调是否压得住，暗部有没有糊死",
             "钠灯黄色光斑半径是否合理，两处油桶火有没有烧掉细节",
             "雪面高光是否过曝"],
         en=["Does the CanvasModulate night grade hold, or do shadows crush?",
             "Are sodium lamp pools a believable radius, and do braziers blow out detail?",
             "Is snow highlight clipping?"],
         group="level"),
    dict(file="marshalling_grey.png", level="L04 · ЗАПАДНЫЙ СОРТИРОВОЧНЫЙ ПАРК · 西调车场",
         scene="res://scenes/night_marshalling.tscn", area="整关 44×36 m · 中性光",
         zh=["砖砌调度楼、站台雨棚、驼峰线、四节车皮、水塔的空间关系",
             "三件新道具（沙袋 33.0, 9.2 / 弹药箱 24.2, 5.6 / 枪架 12.4, 4.1 m）是否落在车站逻辑位置上",
             "站台边缘与轨道是否有可走的通道"],
         en=["Brick dispatch hall, canopy, hump tracks, boxcars, water tower — do they read in the right order?",
             "Do the three new props sit where a station would actually keep them?",
             "Is there a walkable lane along the platform edge?"],
         group="level"),
    dict(file="marshalling_night.png", level="L04 · ЗАПАДНЫЙ СОРТИРОВОЧНЫЙ ПАРК · 西调车场",
         scene="res://scenes/night_marshalling.tscn", area="整关 · 夜色",
         zh=["站台灯 / 调度楼窗光 / 油桶火三套光源是否互相打架",
             "车皮侧面在夜色里还能不能看出体积",
             "雪被灯照到的边缘是否过曝"],
         en=["Do platform lamps, window light and braziers fight each other?",
             "Can you still read boxcar volume in the dark?",
             "Do lit snow edges clip?"],
         group="level"),
    dict(file="manor_grey.png", level="L05 · СОСНОВАЯ УСАДЬА · 松林庄园",
         scene="res://scenes/night_manor.tscn", area="整关 46×38 m · 中性光",
         zh=["庄园主楼立面、车库卷帘门（黄黑警示条）、松林、长蒸汽管、庄园铁门",
             "这关要比货场「有钱」：砖石 / 铁艺 / 涂装的级差够不够",
             "庄园车道那条深色沥青带边缘是否生硬"],
         en=["Manor facade, garage roller door (hazard stripes), pine belt, steam pipe, iron gate",
             "This level must read richer than the freight yard — is the material tiering enough?",
             "Is the dark driveway edge too hard?"],
         group="level"),
    dict(file="manor_night.png", level="L05 · СОСНОВАЯ УСАДЬА · 松林庄园",
         scene="res://scenes/night_manor.tscn", area="整关 · 夜色",
         zh=["最暗的一关：松林会不会把玩家整个吃掉",
             "两处火盆是否给出可用的导航锚点",
             "瞭望塔探照灯位置与地面光斑"],
         en=["Darkest level: do the pines swallow the player?",
             "Do the two braziers work as navigation anchors?",
             "Watchtower searchlight position vs its ground pool"],
         group="level"),
    dict(file="outpost_marshalling.png", level="L04 · 哨位特写",
         scene="res://scenes/night_marshalling.tscn", area="三个新哨位 2× · 沙袋 / 弹药箱 / 枪架",
         zh=["虚线框 = 精灵本体外框；十字 = 落地锚点（碰撞、遮蔽都按锚点算）",
             "沙袋 (33.0, 9.2 m)：低掩体，只挡视线不挡子弹",
             "弹药箱 (24.2, 5.6 m)：必出步枪弹；枪架 (12.4, 4.1 m)：只剩一把撬棍"],
         en=["Dashed box = sprite bounds; crosshair = ground anchor (collision & occlusion use it)",
             "Sandbags (33.0, 9.2 m): low cover, hides you but does not stop bullets",
             "Ammo box (24.2, 5.6 m): guaranteed rifle rounds; rack (12.4, 4.1 m): one crowbar left"],
         group="crop"),
    dict(file="outpost_manor.png", level="L05 · 哨位特写",
         scene="res://scenes/night_manor.tscn", area="三个新哨位 2× · 沙袋 / 弹药箱 / 枪架",
         zh=["沙袋 (27.0, 12.6 m)：与停着的叉车互为掩体",
             "弹药箱 (21.0, 6.2 m)：卫兵哨位；枪架 (9.2, 4.2 m)：409 批托盘旁",
             "有没有穿帮：压在雪脊上、堵死必经路线、和托盘挤在一起"],
         en=["Sandbags (27.0, 12.6 m): pairs with the parked forklift",
             "Ammo box (21.0, 6.2 m): guard post; rack (9.2, 4.2 m): beside the Batch-409 pallet",
             "Clipping: sunk into snow ridges, blocking the only route, jammed against the pallet"],
         group="crop"),
    dict(file="combat_readout.png", level="战斗读数 · L03–L05 通用",
         scene="godot_project/scripts/night/Arsenal.gd", area="俯视 1 m = 14 px",
         zh=["撬棍扇形 ±49° / 1.9 m：够不够「贴身才有用」",
             "噪声圈 ТТ-33 26 m / 锯短 38 m / 莫辛 44 m：一枪就把 80% 半径内的巡逻拽过来，是不是太狠",
             "命中半径 0.40 / 0.46 / 0.52 m 与左下数值表是否和 Arsenal.gd 对得上"],
         en=["Crowbar cone ±49° at 1.9 m — is it intimate enough?",
             "Noise rings 26 / 38 / 44 m pull every patrol inside 80% — too punishing?",
             "Hit radii 0.40 / 0.46 / 0.52 m and the stat table must match Arsenal.gd"],
         group="read"),
]

GROUPS = [("level", "01 · 三关整图 / Full levels"),
          ("crop", "02 · 哨位特写 / Outpost close-ups"),
          ("read", "03 · 战斗读数 / Combat readout")]


def thumb(path: str, long_edge: int = 1600) -> bytes:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    k = min(1.0, long_edge / max(w, h))
    if k < 1.0:
        im = im.resize((int(w * k), int(h * k)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=84, optimize=True, progressive=True)
    return buf.getvalue()


def b64(data: bytes) -> str:
    return "data:image/jpeg;base64," + base64.b64encode(data).decode("ascii")


def build(standalone: bool) -> str:
    cards = []
    for gid, gtitle in GROUPS:
        items = [s for s in SHEETS if s["group"] == gid]
        cards.append(f'<h2 id="{gid}">{gtitle}</h2>\n<section class="grid">')
        for s in items:
            src_png = os.path.join(VERIFY, s["file"])
            src_jpg = os.path.join(WEB, s["file"].replace(".png", ".jpg"))
            if standalone:
                src = b64(thumb(src_png))
            else:
                src = "verify/web/" + os.path.basename(src_jpg)
            w, h = Image.open(src_png).size
            checks = "".join(f"<li>{c}</li>" for c in s["zh"])
            checks_en = "".join(f"<li>{c}</li>" for c in s["en"])
            cards.append(f'''  <article class="card">
    <header>
      <span class="chip">{s['level']}</span>
      <span class="meta mono">{w}×{h}</span>
    </header>
    <a class="shot" href="verify/{s['file']}" target="_blank" rel="noopener">
      <img loading="lazy" src="{src}" alt="{s['file']}">
    </a>
    <div class="sub mono">{s['scene']}</div>
    <div class="sub dim">{s['area']} · {s['file']}</div>
    <div class="checks">
      <ul>{checks}</ul>
      <ul class="en">{checks_en}</ul>
    </div>
  </article>''')
        cards.append("</section>")

    nav = "".join(f'<a href="#{g}">{t}</a>' for g, t in GROUPS)
    note = ("单文件离线版 / standalone: 图片已内嵌 base64，可以直接把这个 HTML 发给别人或双击打开。"
            if standalone else
            "在线版 / served: 图片走相对路径，原尺寸 PNG 点图可看。")
    return f'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>YEAR OF Z · 验收图 / Acceptance Sheets</title>
<style>
  :root{{--ink:#070809;--iron:#121618;--plate:#1b2023;--steel:#343c3f;--steel-lit:#4a5457;
        --bone:#d8d1bf;--bone-dim:#8c8578;--ash:#6b6560;--ochre:#c8a257;--blood:#8c1c14;
        --signal:#d9a326;--frost:#8fb4c4;--crt:#63d18a}}
  *{{box-sizing:border-box}}
  body{{margin:0;background:var(--ink);color:var(--bone);
       font:15px/1.65 -apple-system,"Segoe UI","Noto Sans SC","PingFang SC",sans-serif}}
  a{{color:var(--ochre)}}
  .mono{{font-family:"Cascadia Mono",Consolas,"DejaVu Sans Mono",monospace}}
  .wrap{{max-width:1180px;margin:0 auto;padding:0 20px 80px}}
  .mast{{border-bottom:2px solid var(--steel);padding:26px 0 14px;margin-bottom:6px}}
  .kicker{{font:11px/1.6 "Cascadia Mono",Consolas,monospace;letter-spacing:.16em;color:var(--bone-dim)}}
  h1{{font-size:26px;margin:6px 0 6px;letter-spacing:.02em}}
  .lede{{color:var(--bone-dim);font-size:13px;max-width:78ch;margin:0 0 12px}}
  .warn{{border-left:3px solid var(--signal);padding:8px 12px;background:#15181a;
        color:#c9c2b0;font-size:12.5px;margin:12px 0 0}}
  nav{{position:sticky;top:0;z-index:5;background:rgba(7,8,9,.94);backdrop-filter:blur(6px);
       border-bottom:1px solid var(--steel);display:flex;gap:8px;flex-wrap:wrap;padding:10px 0;margin-bottom:8px}}
  nav a{{font:12px/1 "Cascadia Mono",Consolas,monospace;text-decoration:none;color:var(--bone-dim);
        border:1px solid var(--steel);padding:7px 10px}}
  nav a:hover{{color:var(--bone);border-color:var(--ochre)}}
  h2{{font-size:15px;letter-spacing:.1em;color:var(--ochre);text-transform:uppercase;
      margin:38px 0 12px;border-bottom:1px solid var(--steel);padding-bottom:8px}}
  .grid{{display:grid;gap:18px}}
  .card{{background:var(--plate);border:1px solid var(--steel);padding:14px 14px 12px}}
  .card header{{display:flex;align-items:baseline;justify-content:space-between;gap:12px;margin-bottom:10px}}
  .chip{{font:12px/1 "Cascadia Mono",Consolas,monospace;color:#0b0d0e;background:var(--ochre);
        padding:6px 9px;letter-spacing:.04em}}
  .meta{{font-size:11px;color:var(--ash)}}
  .shot{{display:block;line-height:0;border:1px solid var(--steel-lit);margin-bottom:10px;background:#0b0d0e}}
  .shot img{{width:100%;display:block}}
  .sub{{font-size:11.5px;color:var(--frost);margin-top:-2px}}
  .sub.dim{{color:var(--ash)}}
  .checks{{display:grid;grid-template-columns:1fr;gap:2px;margin-top:10px;
          border-top:1px dashed var(--steel);padding-top:9px}}
  @media(min-width:900px){{.checks{{grid-template-columns:1fr 1fr;gap:0 22px}}}}
  .checks ul{{margin:0;padding-left:16px;font-size:12.5px;color:#c0b9a7}}
  .checks ul.en{{color:var(--bone-dim);font-size:12px}}
  .checks li{{margin:2px 0}}
  footer{{margin-top:46px;border-top:2px solid var(--steel);padding-top:16px;
         font-size:12px;color:var(--bone-dim)}}
  .pill{{display:inline-block;border:1px solid var(--steel-lit);padding:3px 8px;margin:3px 6px 3px 0;
        font:11px/1.4 "Cascadia Mono",Consolas,monospace;color:var(--bone-dim)}}
</style>
</head>
<body>
<div class="wrap">
  <div class="mast">
    <div class="kicker">YEAR OF Z · IRON WINTER — ACCEPTANCE SHEETS</div>
    <h1>验收图 / Acceptance Sheets</h1>
    <p class="lede">
      9 张图，每张都标了它属于哪个场景。整关图看美术与摆位，特写看三件新哨位道具，
      读数图看战斗手感是否成立。逐张说明也写在 <span class="mono">docs/ui/verify/README.md</span>。
    </p>
    <div class="warn">
      ⚠️ 这些不是引擎截图：沙箱里没有 Godot，图片由
      <span class="mono">tools/art_gen/render_preview.py</span> 直接读 <span class="mono">.tscn</span>
      复合成画面 —— 位置、层级、夜色、补光与游戏一致；shader、粒子、HUD、动画中间帧不在图上。
      战斗手感（后坐、命中反馈、音效）仍然只是静态验证。
    </div>
    <div style="margin-top:12px">{note}</div>
  </div>
  <nav>{nav}<a href="soviet_ui_board.html">04 · 界面板 / UI board</a>
    <a href="verify/README.md">README.md</a></nav>
  {''.join(cards)}
  <footer>
    <div class="pill">1 m = 64 px</div><div class="pill">地面纵向 ×0.62</div>
    <div class="pill">1080p 目标</div><div class="pill">Godot 4.7.2</div>
    <p>重新生成：<span class="mono">python3 godot_project/tools/art_gen/render_preview.py</span>
       出图 · <span class="mono">python3 godot_project/tools/art_gen/build_acceptance_page.py</span>
       出页面。</p>
    <p>仍然没美术化的场景：<span class="mono">gym.tscn / main.tscn / campaign.tscn / event_demo.tscn</span>
       —— 还是 <span class="mono">_draw()</span> 灰盒，下一批处理。</p>
  </footer>
</div>
</body>
</html>
'''


def main() -> None:
    os.makedirs(WEB, exist_ok=True)
    for s in SHEETS:
        src = os.path.join(VERIFY, s["file"])
        dst = os.path.join(WEB, s["file"].replace(".png", ".jpg"))
        data = thumb(src)
        with open(dst, "wb") as f:
            f.write(data)
        print(f"  web {os.path.basename(dst):28s} {len(data)/1024:7.0f} KB")

    page = build(standalone=False)
    with open(os.path.join(OUT, "acceptance.html"), "w", encoding="utf-8") as f:
        f.write(page)
    print("  ->", os.path.join(OUT, "acceptance.html"), f"{len(page)/1024:.0f} KB")

    solo = build(standalone=True)
    with open(os.path.join(OUT, "acceptance_standalone.html"), "w", encoding="utf-8") as f:
        f.write(solo)
    print("  ->", os.path.join(OUT, "acceptance_standalone.html"), f"{len(solo)/1024/1024:.1f} MB")


if __name__ == "__main__":
    main()
