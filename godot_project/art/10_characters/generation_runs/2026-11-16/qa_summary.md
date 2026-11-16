# 角色美术批次质检记录

## 资源清单

- `tools/art_gen/verify_assets.py`：PASS，255 项资源、14 份关卡 manifest、136 个声明键。
- 动态情绪路径识别 16 项；`PRT_%s_%s.png` 模板覆盖了本轮新增的 Wry/Sad 资源。
- 剩余 5 个孤儿资源均为原项目已有的默认胸像文件：`PRT_Aleksei.png`、`PRT_Anna.png`、`PRT_Chernov.png`、`PRT_Fyodor.png`、`PRT_Ivan.png`。静态代码没有引用这些无后缀名称。
- 伙伴导出均保留了旧画布尺寸和脚底线：人类 72×112、y=110；阿什 96×80、y=79。八个 `partner-atlas.json` 的 warnings 均为空。
- 没有运行 Godot 场景或 `check_chars.py`；本批静态验证不代表引擎内运行测试。

## 动作图自动质检非通过项

以下结果来自本批保留的 `sheet_qc_raw`、`sheet_qc_walk`、`sheet_qc_walk_profile` JSON。帧格裁切和 alpha 清理在记录后完成；最终动作表已作目视检查，但没有重新执行机器动作 QA，因此仍保留这些标记。

### Aleksei

- `sheet_qc_raw` WARN：`safe_frame=36`（阈值 0）；`faint_specks`：`floor_px=91760`、`detached_components=69`（阈值 0）。
- `sheet_qc_walk` WARN：`torso_drift=5.51`（阈值 2.0）；`seam=1.84`（阈值 1.5）。
- `sheet_qc_walk_profile` WARN：`torso_drift=5.65`（阈值 2.0）。

### HalfHuman

- `sheet_qc_raw` WARN：`boundary_band=26`、`safe_frame=36`（阈值均为 0）；`faint_specks`：`floor_px=104381`、`detached_components=76`（阈值 0）。
- `sheet_qc_walk` WARN：`near_duplicates=[5,6]`（阈值 0.95）；`torso_drift=5.89`（阈值 2.0）；`seam=1.71`（阈值 1.5）。
- `sheet_qc_walk_profile` WARN：`near_duplicates=[2,7]`（阈值 0.95）；`torso_drift=2.28`（阈值 2.0）；`seam=2.4`（阈值 1.5）。

### OSK

- `sheet_qc_raw` FAIL：`cross_cell_components=3`、`cross_cell_visible=3`（阈值均为 0）。WARN：`boundary_band=1087`、`safe_frame=36`；`faint_specks`：`floor_px=153172`、`detached_components=49`（阈值均为 0）。
- `sheet_qc_walk` FAIL：`leg_alternation=[near,near,near,near,near,near,near,near]`，阈值为半周期前后应交替领腿。
- `sheet_qc_walk_profile` FAIL：`leg_alternation=[unclear,near,near,near,near,near,near,near]`，同上。WARN：`torso_drift=2.37`（阈值 2.0）；`seam=1.95`（阈值 1.5）。该检测依赖远侧肢体比近侧暗一档；OSK 的灰色衣物近远色差不足，结果需结合已保存的帧预览人工判断。

### Rabid

- `sheet_qc_raw` FAIL：`cross_cell_components=5`、`cross_cell_visible=5`（阈值均为 0）。WARN：`boundary_band=357`、`safe_frame=36`；`faint_specks`：`floor_px=214478`、`detached_components=96`（阈值均为 0）。
- `sheet_qc_walk` WARN：`near_duplicates=[0,7]`（阈值 0.95）；`torso_drift=2.42`（阈值 2.0）；`seam=2.15`（阈值 1.5）。
- `sheet_qc_walk_profile` FAIL：`identity_head_ratio` 第 4、5 帧分别为 `1.08`、`1.06`，阈值 `[0.95,1.05]`。WARN：`leg_alternation=[near,far,far,unclear,near,near,near,near]`（阈值为半周期前后应交替领腿）；`torso_drift=4.97`（阈值 2.0）；`seam=1.71`（阈值 1.5）。

## 工具路由诊断

- 本批使用的 Codex `image_gen` host image 路由为 READY。
- 视频生成路由为 NONE，因此使用静帧动作图板与确定性切图；没有声称使用图生视频。
- `doctor.json` WARN：PATH 中另有 Windows Store 的 Python；FFmpeg 是开发构建，不能确认版本 ≥5.1。
- `doctor.json` MISSING：`resvg-py`、OpenAI/Gemini/xAI/BytePlus/fal API 密钥和 Grok Build CLI。这些未用于本批图像生成或导出。
