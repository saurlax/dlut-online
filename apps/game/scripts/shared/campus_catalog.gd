extends RefCounted

const CAMPUSES := {
	"lingshui": {"title":"凌水主校区", "scene":"res://scenes/campuses/lingshui.tscn", "manifest":"res://assets/campuses/lingshui/data/campus.json", "roads":"res://assets/campuses/lingshui/data/osm_roads.json", "vegetation":"res://assets/campuses/lingshui/data/vegetation.json", "surroundings":"res://assets/campuses/lingshui/data/surroundings.json"},
	"eda": {"title":"开发区校区", "scene":"res://scenes/campuses/eda.tscn", "manifest":"res://assets/campuses/eda/data/campus.json", "roads":"res://assets/campuses/eda/data/osm_roads.json", "vegetation":"res://assets/campuses/eda/data/vegetation.json", "surroundings":"res://assets/campuses/eda/data/surroundings.json"},
	"panjin": {"title":"盘锦校区", "scene":"res://scenes/campuses/panjin.tscn", "manifest":"res://assets/campuses/panjin/data/campus.json", "roads":"res://assets/campuses/panjin/data/osm_roads.json", "vegetation":"res://assets/campuses/panjin/data/vegetation.json", "surroundings":"res://assets/campuses/panjin/data/surroundings.json"},
}
static var arriving := false
static var started := false
static var entry_requested := false
