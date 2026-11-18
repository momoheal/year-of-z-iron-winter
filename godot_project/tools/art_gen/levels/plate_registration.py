"""Register level geometry to the 624 × 351 reference view of each painted map.

Each prop box runs from its upper left to its lower right. The physical origin
and default interaction point sit at the middle of its lower edge.
"""
import json
from pathlib import Path

REGISTRATIONS = json.loads(Path(__file__).with_name("plate_registration.json").read_text(encoding="utf-8"))

def register(level):
    entry = REGISTRATIONS[level["META"]["id"]]
    def world(x, y):
        return round(x * level["W"] / 624, 4), round(y * level["H"] / 351, 4)

    level["PLATE_CAMERA"] = True
    level["FACADE_BASE_Y"] = world(0, entry["north"])[1]
    level["PLATE_WALLS"] = [(name, *world(*box[:2]), *world(*box[2:]))
                            for name, box in entry.get("walls", {}).items()]
    level["SPAWN"] = world(*entry["spawn"])
    level["EXIT"] = world(*entry["exit"])
    if "fence" in entry:
        y, left, right = entry["fence"]
        level["FENCE_Y"] = world(0, y)[1]
        level["FENCE_GAP"] = (world(left, 0)[0], world(right, 0)[0])
    for prop in level["PROPS"]:
        box = entry["props"].get(prop["id"])
        if prop["id"] in entry.get("placed", {}):
            prop["pos"] = world(*entry["placed"][prop["id"]])
        if not box:
            continue
        x0, y0, x1, y1 = box
        old = prop["pos"]
        prop.update(pos=world((x0+x1)/2, y1), fp=world(x1-x0, y1-y0), baked=True)
        if prop.get("cont"):
            prop["reach"] = (0, 0.65)
        if prop["id"] in entry.get("reach", {}):
            x, y = world(*entry["reach"][prop["id"]])
            prop["reach"] = (x - prop["pos"][0], y - prop["pos"][1])
        for key, pos in level["LIGHTS"].items():
            if tuple(pos) == tuple(old):
                level["LIGHTS"][key] = prop["pos"]
        if prop["id"] == "Watchtower" and level.get("SEARCHLIGHT"):
            level["SEARCHLIGHT"]["pos"] = prop["pos"]
    for patrol in level["PATROLS"]:
        if patrol["id"] in entry.get("patrols", {}):
            patrol["pts"] = [world(*xy) for xy in entry["patrols"][patrol["id"]]]
    for actor in level["RABIDS"] + level["HALFS"]:
        if actor["id"] in entry.get("actors", {}):
            actor["home" if "home" in actor else "pos"] = world(*entry["actors"][actor["id"]])

    actors = entry.get("actors", {})
    market = level.get("MARKET")
    if market:
        for name, key in (("Market", "pos"), ("Trader", "trader")):
            if name in actors:
                market[key] = world(*actors[name])
    residents = market.get("survivors", []) if market else level.get("SURVIVORS", [])
    for i, pos in enumerate(residents):
        name = f"Survivor_{i}"
        if name in actors:
            residents[i] = (*world(*actors[name]), *pos[2:])
