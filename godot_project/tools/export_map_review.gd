extends SceneTree
## Snapshot of the actual loaded campaign levels for the offline map review.
const Data := preload("res://scripts/CampaignData.gd")
var items: Array
var bounds: Vector2

func _initialize():
	export_maps.call_deferred()

func point(p: Vector2) -> Array:
	return [snappedf(624*p.x/bounds.x,0.01),snappedf(351*p.y/bounds.y,0.01)]

func mark(kind: String, title: String, position: Vector2, note := "") -> Dictionary:
	var row := {"kind":kind,"title":title,"p":point(position),"note":note}
	items.append(row)
	return row

func export_maps():
	var result := []
	for loc in Data.LOCS:
		if loc.get("scene","") == "": continue
		var s = load(loc.scene).instantiate()
		root.add_child(s)
		items = []
		bounds = s.map_bounds_px
		var start: Vector2 = s.get_node("Markers/Spawn").position
		mark("通行","出生点",start)
		mark("通行","撤离口",s.exit_px)
		for actor in s.rabids+s.halfs+s.survivors:
			var role := "幸存者"
			if actor in s.rabids: role="感染者"
			if actor in s.halfs: role="回退半人"
			mark("人物",str(actor.name),actor.position,role)
		for guard in s.soldiers:
			mark("人物",str(guard.name),guard.position,"清杀队")
			var line = mark("巡逻",str(guard.name),guard.position,str(guard.mode))
			line["stops"]=[]
			line["path"]=[]
			for wp in guard.route: line.stops.append(point(wp))
			for i in range(guard.route.size() if guard.mode=="loop" else guard.route.size()-1):
				var a:Vector2=guard.route[i]
				var b:Vector2=guard.route[(i+1)%guard.route.size()]
				line.path.append(point(a))
				if not s.nav.line_clear(a,b):
					for wp in s.nav.path_px(a,b): line.path.append(point(wp))
				line.path.append(point(b))
		for obj in s.containers:
			mark("物资",str(obj.name),s.interact_point(obj),str(obj.get_meta("guaranteed","")) if obj.has_meta("guaranteed") else str(obj.get_meta("container","")))
		for m in s.markets: mark("人物",str(m.name),m.position,"交易摊位")
		for l in s.landmarks:
			var row=mark("剧情",l.name,s._m_px(l.pos),l.get("note",""))
			row["radius"]=point(Vector2(l.radius*64,l.radius*39.68))
			row["trigger"]=l.get("story_trigger","")
			row["requires"]=l.get("requires_flag","")
		for e in s.beats.get("mechanisms",[]):
			var obj=s.get_node_or_null(e.get("node",""))
			if obj: mark("机关",e.label,obj.position,e.get("prompt",""))
		for e in s.beat_events:
			if e.has("pos"): mark("机关",e.kind,s._m_px(e.pos),"环境节拍")
			if e.has("lane"):
				for y in [e.lane,e.lane_alt]:
					var row=mark("机关","驼峰溜放线",s._m_px([e.from,y]),"周期性行车")
					row["path"]=[point(s._m_px([e.from,y])),point(s._m_px([e.to,y]))]
		for n in s.monuments.items:
			var poster := str(n.id).begins_with("poster_")
			var art: Dictionary = s.monuments.POSTERS.get(n.kind,{}) if poster else s.monuments.KINDS.get(n.kind,s.monuments.PROPS.get(n.kind,{}))
			var line: Array = art.get("lines",{}).get("self",[])
			var text := str(line[1]) if line.size()>1 else "靠近后触发环境对白"
			mark("贴画" if poster else "纪念物",str(art.get("zh",n.kind)),n.pos,text)
		var grid=[]
		for y in s.nav.size.y:
			var line=""
			for x in s.nav.size.x: line+=("." if s.nav.walkable(Vector2i(x,y)) else "#")
			grid.append(line)
		var beat: Dictionary=Data.STORY.get(loc.get("story",""),{})
		result.append({"id":loc.id,"name":loc.zh,"img":s.map_art_day.resource_path,"night":s.map_art_night.resource_path,
			"marks":items,"grid":grid,"cell":point(s.nav.CELL),"goal":s.prize,"brief":s.beats.get("brief",[]),
			"story":beat.get("title_zh",""),"choices":beat.get("choices",[]),"req":loc.get("req_flag","")})
		root.remove_child(s)
		s.free()
	var file=FileAccess.open(OS.get_environment("MAP_REVIEW_JSON"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	print("EXPORTED ",result.size()," maps")
	quit()
