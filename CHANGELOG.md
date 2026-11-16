# Changelog

本文件按**时间倒序**记录**已核实**的提交。提交号、日期与标题均取自本仓库 `git log --format="%h | %ad | %s" --date=short`，未核实的改动不写入。当前分支 `feat/nav-and-save-recovery`，HEAD `63709eb`。

> **版本口径（取舍待用户复核）**
> - **构建版本 `4.0.0`**：唯一真源是 `godot_project/project.godot` 的 `config/version="4.0.0"`。对外发布、商店页、补丁说明一律以此为准。
> - **内容规格 `v4.2`**：README 顶部历史标题曾把 `v4.2` 标为 Definitive Master（仓库标题），实为 `docs/` 下策划案、总剧本、美术风格参考等**文档与原型的内容规格版本**，并非构建版本号，也不代表已发布的可执行版本。本轮**保留 v4.2 作为内容规格标签**，不粗暴删除；README / index.html 已改为并列标注「构建 4.0.0 · 内容规格 v4.2」。该定位最终由用户拍板（见末尾「待用户决策」）。
> - **历史规格标签 `v4.0`**：`index.html` 与原型沙盘标题中的「v4.0 诺沃斯克-17 设定」，以及 `project.godot` 的 `config/name="Year of Z: Iron Winter (v4.0 Novorsk-17)"`，均为早期内容规格 / 命名遗留，**不是构建版本**。本轮未改动 `project.godot`（该文件在工作区存在未提交的 CRLF 假修改，属禁改范围）。
> - 当前仓库**无 git tag**、**无 CI**、**无 LICENSE**、**无导出预设**。

---

## [Unreleased] — 待补 · 本轮进行中

> 本轮 P0 修复（版本口径统一、CHANGELOG 建立、Quick Push 安全化、音色口径修正、外层进度报告归档提示）**尚未提交**。待改动被核实并提交后，再按实际提交号与日期补写本节；**不预写未发生的改动**。

---

## 2026-11-12

### `63709eb` — Merge pull request #19 `fix/osk-facing-story-name`
- 合并内实际改动：`199f1a7` `fix: OSK facing unwind + story speaker name plate`
- 摘要：OSK 朝向归一化 + 剧情说话人名字牌。当前分支 HEAD。

### `71141b6` — Merge pull request #18 `arena/4aea8af2-year-of-z-iron-winter`
- 合并内实际改动：`5c20c41` `feat: onboarding, story slides, save slots, CG set, Soviet relics with dialogue`
- 摘要：新手引导、剧情幻灯片、存档槽、CG 图集、苏联遗物与对话。

---

## 2026-11-11

- `f2456ca` — `fix: correct hand in opening scene`（开场场景手部修正）
- `8e2a91f` — `feat: add prologue and improve night visibility`（序章 + 夜间可见度）
- `4cb08d4` — `fix(night): clear the play field — dock the briefing card, pad the camera`（简报卡停靠 / 镜头留白）
- `be66f97` — `fix(save): keep a validated backup and report real save failures`（存档备份恢复与真实失败上报）
- `2242885` — `feat(night): shared grid pathfinding so enemies walk around obstacles`（共享网格寻路）

> 更早的提交（含 `d53f179` 及 PR #17 / #16 / #15 / #14 系列）请以 `git log --oneline` 为准，本文件不作推测性补写。

---

## 测试结论记录基线（非永久有效）

| 项 | 值 |
| --- | --- |
| 基线提交 | `63709eb`（分支 `feat/nav-and-save-recovery`） |
| 执行日期 | 2026-11-12 |
| 执行命令 | `python godot_project/tools/run_tests.py` |
| 该次结果 | 14 套 / 1683 通过 / 0 失败 / 0 脚本错误 |
| 性质 | **本地实跑，非 CI**（当前仓库无 CI 配置） |

> 上表仅为**该基线在该日期的一次记录**，不保证对后续任何提交成立。每次发布前须重跑，并以 `godot_project/tests/logs/` 或 CI 产物为准。依据：`docs/zh/项目架构评估与下一阶段实施计划_2026-11-11.md` §8.3「自动测试结果记录基线提交与执行日期，避免永久写死『全部通过』的结论」。

---

## 待用户决策（本文件不替用户拍板）

1. **v4.2 的定位**：保留为「内容 / 文档规格版本」（本轮默认取舍）／改名／废弃？若废弃，README 顶部与 `docs/` 内 v4.2 标签需一并清理。
2. **LICENSE 类型**：仓库当前无 LICENSE 文件。需用户自行选定许可证并授权创建；本轮**不创建、不推荐任何具体类型**。
3. **是否打首个 git tag**：当前 `git tag -l` 为空。是否以构建版本 `4.0.0` 在 `63709eb` 打首个 tag，需用户批准（打 tag 属高影响动作，须人工审批）。

---

## 发布门控备注

- 上述改动均为文档 / 引导口径修正，**未执行** `git add` / `commit` / `push` / `tag`。
- 推送、打 tag、发布包、热修与回滚均属高影响动作，须人工审批后执行；`push_to_github.sh` 仅推送当前分支到已配置的 origin。
