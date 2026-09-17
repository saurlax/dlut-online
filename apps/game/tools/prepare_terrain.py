"""Crop pinned Copernicus DSM samples without resampling (GDAL CLI or Rasterio)."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import struct
import tempfile
import urllib.request


ROOT = Path(__file__).resolve().parents[3]
CONFIG = ROOT / "references/shared/terrain/copernicus.json"


def run(*args):
    return subprocess.check_output([str(arg) for arg in args], text=True)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def raster_info(path, backend):
    if backend == "gdal":
        return json.loads(run("gdalinfo", "-json", path))
    import rasterio
    with rasterio.open(path) as source:
        if source.crs is None or source.crs.to_epsg() != 4326 or source.count != 1 or source.dtypes != ("float32",):
            raise ValueError("Expected one Float32 WGS84 DSM band")
        return {"geoTransform": list(source.transform.to_gdal()),
                "size": [source.width, source.height],
                "bands": [{"noDataValue": source.nodata}]}


def rasterio_crop(tile, crop, left, top, width, height):
    import rasterio
    from rasterio.windows import Window
    with rasterio.open(tile) as source:
        window = Window(left, top, width, height)
        values = source.read(1, window=window)
        transform = source.window_transform(window)
        profile = source.profile.copy()
        profile.update(driver="GTiff", width=width, height=height, transform=transform,
                       compress="DEFLATE", predictor=3)
        with rasterio.open(crop, "w", **profile) as output:
            output.write(values, 1)
            output.update_tags(**source.tags())
    with rasterio.open(crop) as output:
        if not (output.read(1) == values).all() or output.transform != transform:
            raise ValueError("Crop changed original samples or georeferencing")
    return [[*(transform * (column + 0.5, row + 0.5)), float(values[row, column])]
            for row in range(height) for column in range(width)]


def build(campus, config, cache, output, backend="gdal"):
    spec = config["campuses"][campus]
    tile = cache / spec["file"]
    if not tile.exists():
        cache.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(spec["url"], timeout=120) as response:
            content = response.read()
        if hashlib.sha256(content).hexdigest() != spec["sha256"]:
            raise ValueError(f"Source checksum mismatch: {campus}")
        tile.write_bytes(content)
    if digest(tile) != spec["sha256"]:
        raise ValueError(f"Source checksum mismatch: {tile}")
    info = raster_info(tile, backend)
    west, south, east, north = spec["bbox_wgs84"]
    x0, dx, rx, y0, ry, dy = info["geoTransform"]
    if rx != 0 or ry != 0 or dx <= 0 or dy >= 0:
        raise ValueError("Expected north-up geographic source")
    # Expand to the original pixel edges. Never interpolate or change sample values.
    left, top = math.floor((west - x0) / dx), math.floor((north - y0) / dy)
    right, bottom = math.ceil((east - x0) / dx), math.ceil((south - y0) / dy)
    width, height = right - left, bottom - top
    if not (0 <= left < right <= info["size"][0] and 0 <= top < bottom <= info["size"][1]):
        raise ValueError("Requested coverage is outside source")
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        crop = Path(temporary) / "surface-dem.tif"
        if backend == "rasterio":
            samples = rasterio_crop(tile, crop, left, top, width, height)
        else:
            run("gdal_translate", "-q", "-srcwin", left, top, width, height,
                "-co", "COMPRESS=DEFLATE", "-co", "PREDICTOR=3", tile, crop)
            lines = run("gdal_translate", "-q", "-of", "XYZ", crop, "/vsistdout/").splitlines()
            samples = [list(map(float, line.split())) for line in lines]
        cropped = raster_info(crop, backend)
        # XYZ prints decimal text; restore the exact source Float32 representation.
        for sample in samples:
            sample[2] = struct.unpack("f", struct.pack("f", sample[2]))[0]
        nodata = info["bands"][0].get("noDataValue")
        if nodata is not None:
            nodata = struct.unpack("f", struct.pack("f", float(nodata)))[0]
        if len(samples) != width * height or any(
            not math.isfinite(s[2]) or s[2] == nodata for s in samples
        ):
            raise ValueError("Incomplete or invalid elevation grid")
        transform = cropped["geoTransform"]
        for index, (lon, lat, _) in enumerate(samples):
            row, col = divmod(index, width)
            if abs(lon - (transform[0] + (col + 0.5) * dx)) > 1e-9 or abs(
                lat - (transform[3] + (row + 0.5) * dy)
            ) > 1e-9:
                raise ValueError("Unexpected sample orientation")
        origin_lon, origin_lat = samples[0][:2]
        values = [s[2] for s in samples]
        grid = {
            "schema_version": 1, "campus_id": campus, "surface_type": "DSM",
            "horizontal_crs": "EPSG:4326", "vertical_datum": "EGM2008",
            "height_unit": "m", "width": width, "height": height,
            "sample_origin_lon_lat": [origin_lon, origin_lat],
            "sample_step_lon_lat": [dx, dy],
            "local_frame": {
                "origin_lon_lat": [origin_lon, origin_lat],
                "x_east_step_m": dx * 111320 * math.cos(math.radians(origin_lat)),
                "z_south_step_m": -dy * 111320,
                "y_offset_m": 0,
                "description": "独立近似米制坐标，左上采样点为 X/Z 原点；Y 为 EGM2008 绝对高程，不是现有校园场景坐标。",
            },
            "rows_north_to_south": [values[i:i + width] for i in range(0, len(values), width)],
        }
        # Compact each row for manageable diffs while keeping Float32 values losslessly.
        header = json.dumps({k: v for k, v in grid.items() if k != "rows_north_to_south"}, ensure_ascii=False, indent=2)
        rows = ",\n".join("    " + json.dumps(row) for row in grid["rows_north_to_south"])
        (output / "heightfield.json").write_text(header[:-2] + ',\n  "rows_north_to_south": [\n' + rows + "\n  ]\n}\n", encoding="utf-8", newline="\n")
        (output / "surface-dem.tif").write_bytes(crop.read_bytes())
    if backend == "rasterio":
        import rasterio
        software = f"Rasterio {rasterio.__version__}, GDAL {rasterio.__gdal_version__}"
    else:
        software = run("gdalinfo", "--version").strip()
    source = {
        "schema_version": 1, "campus_id": campus, "dataset": config["dataset"],
        "source": spec, "retrieved": spec.get("retrieved", config["retrieved"]),
        "acquisition": config["acquisition"], "license": config["license"],
        "attribution": config["attribution"], "liability_notice": config["liability_notice"],
        "horizontal_crs": "EPSG:4326", "vertical_datum": "EGM2008", "unit": "m",
        "surface_type": "DSM", "nominal_resolution": "1 arcsecond (GLO-30)",
        "campus_accuracy": "未通过校内实测控制点核验；采样间距不等于测量精度。",
        "processing": "原始像素窗口裁剪及 JSON 无损转换；无重采样、平滑、去建筑、去树冠或垂直基准转换。",
        "source_pixel_window": [left, top, width, height],
        "pixel_edge_geotransform": transform,
        "statistics": {"samples": len(values), "missing_samples": 0, "minimum_m": min(values), "maximum_m": max(values)},
        "model_alignment": "源网格为WGS84，须由共享校区原点转换；禁止叠加旧官网经验平移。",
        "use": "离线原始DSM资料；运行过滤、地坪估计及精度边界见references/shared/terrain/basis.md。",
        "outputs": {name: {"sha256": digest(output / name)} for name in ("surface-dem.tif", "heightfield.json")},
        "generator": "apps/game/tools/prepare_terrain.py",
        "processing_software": software,
    }
    write_json(output / "source.json", source)
    print(f"{campus}: {width} x {height}, {min(values):.2f}–{max(values):.2f} m EGM2008")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campus", choices=["lingshui", "eda", "panjin", "all"], default="all")
    parser.add_argument("--backend", choices=["gdal", "rasterio"], default="gdal")
    parser.add_argument("--cache", type=Path, default=ROOT / ".local/terrain-research")
    parser.add_argument("--output-root", type=Path, default=ROOT / "references")
    args = parser.parse_args()
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    for campus in config["campuses"] if args.campus == "all" else [args.campus]:
        build(campus, config, args.cache.resolve(), args.output_root.resolve() / campus / "terrain", args.backend)


if __name__ == "__main__":
    main()
