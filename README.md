# Year of Z: Iron Winter · Z年纪事：凛冬铁轨

[![CI](https://github.com/momoheal/year-of-z-iron-winter/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/momoheal/year-of-z-iron-winter/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)

**一款正在开发中的 2.5D 潜行生存叙事游戏。**<br>
A 2.5D stealth-survival narrative game in active development.

故事发生在极寒封锁中的西伯利亚铁路城诺沃斯克-17。货运调度员阿列克谢一边为母亲寻找透析液，一边追查筛查后失踪的妹妹拉娜。白天的配给与抉择会影响夜间行动；夜里，玩家需要在暴风雪、感染者与内务部清杀队之间寻找补给、证据和出路。

Set in the quarantined rail town of Novorsk-17, the game follows freight dispatcher Aleksei as he searches for dialysis supplies for his mother and traces his missing sister through transfer records. Daytime choices shape nighttime raids, where supplies, evidence, and a way forward must be found in the snow.

**项目状态：** 仓库当前包含可运行的 Godot 战役原型、剧情与美术资料。它仍在开发中，不代表已发布的正式成品。<br>
**Status:** The repository contains a runnable Godot campaign prototype and its story and art materials. The game is still in development.

## 当前玩法

- 75° 斜俯视视角下的战役地图与夜间潜行探索。
- 在寒冷、能见度、噪声、体力和物资压力下规划行动。
- 搜集配给、药品、档案与可核对的证据。
- 通过对话和任务选择影响同伴关系、救援结果与结局。
- 中文与英文剧情文本，以及可回看的剧情幻灯和结局演出。

## 开始运行

需要 Godot 4.7.2。项目主场景是战役地图。

1. 在 Godot 编辑器中打开 godot_project/project.godot 并运行项目，或在仓库根目录执行：

    godot --path godot_project

## 运行冒烟检查

需要 Python 3 和 Godot 4.7.2。检查脚本会先导入项目资源，再运行所有 Godot smoke suites。Windows 可运行仓库根目录的 run_tests.bat。

    python -m pip install -r requirements.txt
    python godot_project/tools/run_tests.py

只运行名称匹配的套件：

    python godot_project/tools/run_tests.py campaign night_level

GitHub Actions 会在 push 和 pull request 时检查美术资源清单并运行 headless smoke suites。查看 [CI 工作流](.github/workflows/ci.yml)。

## 剧情与制作资料

- [全量文学剧本（中文，含剧透）](docs/zh/Z年纪事_全量文学剧本_去AI重排整合版.md)
- [游戏总策划案 GDD](docs/zh/Z年纪事_游戏总策划案_GDD.md)
- [剧情档案与台词审计网页](https://momoheal.github.io/year-of-z-iron-winter/deliverables/story_review/)
- [剧情档案网页源文件](deliverables/story_review/index.html)
- [最新剧情分镜 PPT（v9）](deliverables/story_review/剧情触发过场分镜_剧情修订版_v9.pptx)
- [夜潜地图设计图册](夜潜地图设计图册.html)
- [HTML 项目入口页](index.html)

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| godot_project/scenes | 战役、地图与夜间任务场景 |
| godot_project/scripts | 战役状态、夜间探索、界面与剧情演出 |
| godot_project/data | 游戏内剧情与数据 |
| godot_project/art | 游戏美术资源及生成来源记录 |
| godot_project/tests | Godot headless smoke suites |
| godot_project/tools | 测试运行、资源检查与剧情档案导出工具 |
| docs/zh、docs/en | 中文与英文设计文档 |
| deliverables/story_review | 剧情审阅材料、台词稿与分镜 |
| prototypes | 早期交互原型 |

<details>
<summary>剧透：真结局与零划痕奖励</summary>

收集到真相且划痕少于 5，可进入真结局分支。母亲仍在、且阿列克谢没有选择背叛路线时进入真结局 α；其他符合真结局条件的情况进入真结局 β。划痕为 0 时，结局演出会追加奖励对话与分镜。

</details>

## 许可

仓库许可为 Apache License 2.0，详见 [LICENSE](LICENSE)。
