"""Generate fully synthetic demo data for the public repository.

Values are produced by a seeded PRNG from first principles: nothing here is
masked, offset, shuffled or otherwise derived from any real facility dataset.
"""
import csv, json, random, uuid, datetime, pathlib

rng = random.Random(20260814)          # fixed seed -> reproducible, not real
uid = lambda: str(uuid.UUID(int=rng.getrandbits(128), version=4))
OUT = pathlib.Path("demo_data")
OUT.mkdir(exist_ok=True)

SITE = "Government HQ Demo"

# ---------------------------------------------------------------- meters ----
METERS = [
    ("EM-001", "Main Incomer LV Panel 1", "electricity", "kwh",  "main",  "Building A"),
    ("EM-002", "Chiller Plant Feeder",    "electricity", "kwh",  "sub",   "Building A"),
    ("EM-003", "Building B Distribution", "electricity", "kwh",  "sub",   "Building B"),
    ("WM-001", "Main Potable Water",      "water",       "m3",   "main",  "Building A"),
    ("WM-002", "Irrigation Supply",       "water",       "m3",   "sub",   "Site Wide"),
    ("WM-003", "Building B Water",        "water",       "m3",   "sub",   "Building B"),
    ("BTU-001","Chilled Water Plant BTU", "cooling",     "gj",   "main",  "Building A"),
    ("BTU-002","AHU-01 Cooling Energy",   "cooling",     "gj",   "sub",   "Building A"),
    ("BTU-003","AHU-02 Cooling Energy",   "cooling",     "gj",   "sub",   "Building B"),
    ("GM-001", "Standby Generator Fuel",  "fuel",        "litre","main",  "Building A"),
]

with (OUT / "sample_meters_demo.csv").open("w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["site_name","meter_code","name_en","location","category_code",
                "unit_code","level","include_in_dashboard","is_active","notes"])
    for code, name, cat, unit, lvl, loc in METERS:
        w.writerow([SITE, code, name, loc, cat, unit, lvl, "true", "true",
                    "Synthetic demo meter - not a real asset"])

# -------------------------------------------------------------- readings ----
# Monotonic cumulative registers grown by a random daily delta per meter.
BASE = {"electricity": (400.0, 90.0), "water": (18.0, 5.0),
        "cooling": (25.0, 7.0), "fuel": (12.0, 4.0)}
START = datetime.date(2026, 1, 1)
DAYS = 60

rows = []
for code, name, cat, unit, lvl, loc in METERS:
    mean, spread = BASE[cat]
    register = float(rng.randrange(1000, 9000))
    for d in range(DAYS):
        day = START + datetime.timedelta(days=d)
        delta = max(0.0, rng.gauss(mean, spread))
        register += delta
        rows.append([SITE, code, day.isoformat(), f"{register:.1f}", unit, cat,
                     "synthetic_generator", "demo", d + 2,
                     "Synthetic demo reading"])

with (OUT / "sample_readings_demo.csv").open("w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["site_name","meter_code","reading_date","raw_value","unit_code",
                "category_code","source_file","source_sheet","source_row","note"])
    w.writerows(rows)

# ------------------------------------------------------- network snapshot ----
site_id, network_id, revision_id, view_id = uid(), uid(), uid(), uid()

NODES = [
    ("WM-001",  "meter", "Main Potable Water Meter",  "عداد المياه الرئيسي",   "main", "water"),
    ("WM-002",  "meter", "Irrigation Water Meter",    "عداد مياه الري",        "sub",  "water"),
    ("TANK-01", "tank",  "Building A Rooftop Tank",   "خزان سطح المبنى أ",     None,   "water"),
    ("TANK-02", "tank",  "Building B Rooftop Tank",   "خزان سطح المبنى ب",     None,   "water"),
    ("AHU-01",  "asset", "Air Handling Unit 01",      "وحدة مناولة الهواء ١",  None,   "cooling"),
    ("AHU-02",  "asset", "Air Handling Unit 02",      "وحدة مناولة الهواء ٢",  None,   "cooling"),
    ("BTU-001", "meter", "Chilled Water Plant BTU",   "عداد حرارة المياه المبردة", "main", "cooling"),
]

nodes, placements = [], []
for i, (code, atype, en, ar, role, service) in enumerate(NODES):
    node_id, asset_id = uid(), uid()
    port_out, port_in = uid(), uid()
    nodes.append({
        "asset_id": asset_id, "asset_type": atype, "code": code,
        "facility_area_id": None, "meter_role": role,
        "name_ar": ar, "name_en": en, "node_id": node_id,
        "ports": [
            {"id": port_in,  "direction": "in",  "node_id": node_id, "port_index": 0},
            {"id": port_out, "direction": "out", "node_id": node_id, "port_index": 1},
        ],
        "properties": {}, "ref_meter_id": asset_id if atype == "meter" else None,
        "ref_tank_id": asset_id if atype == "tank" else None,
        "service_type": service, "site_id": site_id,
    })
    placements.append({
        "collapsed": False, "height": None, "node_id": node_id,
        "pos_x": float(60 + (i % 4) * 220), "pos_y": float(80 + (i // 4) * 200),
        "revision_id": revision_id, "view_id": view_id, "width": None,
    })

LINKS = [(0, 2), (2, 4), (1, 3), (3, 5), (6, 4)]
connections = []
for a, b in LINKS:
    connections.append({
        "connection_kind": "supply",
        "from_node_id": nodes[a]["node_id"], "from_port_id": nodes[a]["ports"][1]["id"],
        "to_node_id": nodes[b]["node_id"],   "to_port_id":   nodes[b]["ports"][0]["id"],
        "id": uid(), "is_consumptive": True, "legacy_sync_status": "synced",
        "operating_mode": "normal", "properties": {}, "revision_id": revision_id,
    })

snapshot = {
    "connections": connections,
    "members": [{"site_id": site_id}],
    "network": {
        "category_id": uid(), "code": "demo-campus-overview",
        "draft_revision_id": revision_id, "id": network_id,
        "name_ar": "شبكة المرافق التجريبية", "name_en": "Demo Utility Network",
        "published_revision_id": None,
    },
    "nodes": nodes, "placements": placements,
    "revision": {
        "based_on_revision_id": None, "id": revision_id, "lock_version": 1,
        "network_id": network_id, "published_at": None, "status": "draft",
    },
    "status": "ok",
    "views": [{
        "code": "campus_overview", "facility_area_id": None, "id": view_id,
        "is_default": True, "name_ar": "نظرة عامة على المجمع",
        "name_en": "Campus overview", "view_kind": "campus_overview",
        "network_id": network_id,
    }],
}

(OUT / "demo_network_snapshot.json").write_text(
    json.dumps(snapshot, indent=2, ensure_ascii=False, sort_keys=True) + "\n")

print(f"meters   : {len(METERS)}")
print(f"readings : {len(rows)}")
print(f"nodes    : {len(nodes)}  connections: {len(connections)}")
