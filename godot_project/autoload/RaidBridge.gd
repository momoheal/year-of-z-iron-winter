extends Node
## RaidBridge.gd — 战役 ↔ 节点化夜潜场景之间的数据桥（P1）。
##
## 战役层 CampaignSim 是 RefCounted，挂在 campaign.tscn 节点下；一旦
## change_scene_to_file 切到 night_explore.tscn，campaign.tscn 被 free，sim 随之销毁。
## 本 autoload 常驻，出发去「带 scene 字段」的地点（如 yard）时：
##   1. CampaignSim.depart() 扣物、建 RaidSim 数据容器、组装 cfg 后，调 begin(self, cfg)；
##   2. Campaign._process 检测 pending_scene，切到 night_explore.tscn；
##   3. night 场景 _ready 读 cfg 初始化背包 / 体温 / 天亮倒计时；
##   4. night 结束时把结果填进 RaidBridge.sim.raid 的字段，调 sim.finish_raid(reason)；
##   5. change_scene_to_file 回 campaign.tscn；
##   6. Campaign._ready 检测 active，调 take_sim() 取回原 sim（不 new 新档），
##      phase 已是 "report"，HUD 直接渲染结算。
##
## F2 单独跑 night_explore.tscn 时 active=false，night 场景走自带的灰盒默认值。

# 持有中的 CampaignSim（RefCounted，不被场景释放）
var sim = null
# 出发时组装的 cfg（loc/day/seed/left/mate/pack_max/weapon/load/cold/danger/time/glasses/night）
var cfg: Dictionary = {}
# 是否正在跨场景携带一次夜潜
var active := false


func begin(p_sim, p_cfg: Dictionary) -> void:
	## 出发去场景化地点：常驻 sim 与 cfg，等 night 结束回收。
	sim = p_sim
	cfg = p_cfg.duplicate(true)
	active = true


func take_sim():
	## 回 campaign.tscn 时调用：取回原 sim 并解除携带。
	## 返回 null 表示没有携带中的夜潜（新游戏 / 从标题进入）。
	var out = sim
	sim = null
	cfg = {}
	active = false
	return out


func clear() -> void:
	## 异常路径兜底（如 night 场景崩溃、玩家强退）。
	sim = null
	cfg = {}
	active = false
