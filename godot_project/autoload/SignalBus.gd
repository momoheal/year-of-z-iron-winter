extends Node
## SignalBus.gd — 全局跨系统信号总线（数据驱动内容的统一通信层）。
##
## 各系统只在这里收发信号，不再直接持有彼此的节点引用，
## 从而把「场景 / 模拟 / UI / 数据 / 视听」彻底解耦。
## 领域专用的 autoload（LogbookManager / AcousticRippleBus）保持不变，
## 本总线负责通用的资源、事件、危机、流程、视听请求。

# ---------------------------------------------------------------------------
# 资源 / 指标
# ---------------------------------------------------------------------------
signal resource_changed(key: String, delta: int, total: int)
signal stat_changed(stat_id: String, value: float)
signal inventory_reset()

# ---------------------------------------------------------------------------
# 事件流（数据驱动的交互事件）
# ---------------------------------------------------------------------------
signal event_fired(event_id: String)
signal event_option_selected(event_id: String, option_id: String)
signal event_resolved(event_id: String, option_id: String, deltas)
signal event_log(text_zh: String, text_en: String)

# ---------------------------------------------------------------------------
# 危机
# ---------------------------------------------------------------------------
signal crisis_triggered(crisis_id: String)
signal crisis_averted(crisis_id: String)
signal crisis_escalated(crisis_id: String, level: int)

# ---------------------------------------------------------------------------
# 视听（UI 动作 -> 音频 / 镜头，不直接调用 Sfx 或 Camera）
# ---------------------------------------------------------------------------
signal sfx_requested(alias: String)
signal screen_shake_requested(intensity: float)
signal toast_requested(text_zh: String, text_en: String)

# ---------------------------------------------------------------------------
# 流程 / 阶段
# ---------------------------------------------------------------------------
signal phase_changed(phase_id: String)
signal day_advanced(day: int)
