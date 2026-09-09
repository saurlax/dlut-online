extends RefCounted

const CAMPUSES := {
	"lingshui": {"title":"凌水主校区", "scene":"res://scenes/campuses/lingshui.tscn", "manifest":"res://assets/campuses/lingshui/data/campus.json"},
	"eda": {"title":"开发区校区", "scene":"res://scenes/campuses/eda.tscn", "manifest":"res://assets/campuses/eda/data/campus.json", "roads":"res://assets/campuses/eda/data/roads.json"},
	"panjin": {"title":"盘锦校区", "scene":"res://scenes/campuses/panjin.tscn"},
}
static var arriving := false
static var started := false
