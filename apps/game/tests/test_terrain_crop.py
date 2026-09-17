"""Optional Rasterio backend checks; run with the offline GIS tool environment."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import prepare_terrain


@unittest.skipUnless(importlib.util.find_spec("rasterio"), "Offline Rasterio dependency not installed")
class TerrainCropTests(unittest.TestCase):
    def source(self, directory, *, nodata=False, crs="EPSG:4326"):
        import numpy as np
        import rasterio
        from rasterio.transform import from_origin
        values = np.arange(30, dtype="float32").reshape(5, 6) + np.float32(0.1)
        if nodata:
            values[2, 2] = -9999
        tile = directory / "source.tif"
        with rasterio.open(tile, "w", driver="GTiff", width=6, height=5, count=1,
                           dtype="float32", crs=crs, nodata=-9999,
                           transform=from_origin(10, 50, 0.25, 0.25)) as output:
            output.write(values, 1)
            output.update_tags(AREA_OR_POINT="Point")
        config = {"dataset":"synthetic", "retrieved":"2026-09-17", "acquisition":"synthetic",
                  "license":{}, "attribution":"synthetic", "liability_notice":"synthetic",
                  "campuses":{"panjin":{"file":tile.name, "url":"unused",
                      "sha256":hashlib.sha256(tile.read_bytes()).hexdigest(),
                      "bbox_wgs84":[10.3,49.1,10.95,49.65]}}}
        return config, values

    def test_original_float32_samples_and_point_pixel_centers(self):
        import numpy as np
        import rasterio
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            config, values = self.source(directory)
            output = directory / "crop"
            prepare_terrain.build("panjin", config, directory, output, "rasterio")
            grid = json.loads((output / "heightfield.json").read_text(encoding="utf-8"))
            self.assertEqual((grid["width"], grid["height"]), (3, 3))
            self.assertEqual(grid["sample_origin_lon_lat"], [10.375,49.625])
            np.testing.assert_array_equal(grid["rows_north_to_south"], values[1:4,1:4])
            with rasterio.open(output / "surface-dem.tif") as crop:
                np.testing.assert_array_equal(crop.read(1), values[1:4,1:4])
                self.assertEqual(crop.tags()["AREA_OR_POINT"], "Point")
                self.assertEqual(tuple(crop.transform.to_gdal()), (10.25,0.25,0.0,49.75,0.0,-0.25))

    def test_nodata_is_rejected_instead_of_becoming_terrain(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            config, _ = self.source(directory, nodata=True)
            with self.assertRaisesRegex(ValueError, "invalid elevation grid"):
                prepare_terrain.build("panjin", config, directory, directory / "crop", "rasterio")
            self.assertFalse((directory / "crop/heightfield.json").exists())

    def test_non_wgs84_source_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            config, _ = self.source(directory, crs="EPSG:3857")
            with self.assertRaisesRegex(ValueError, "WGS84 DSM"):
                prepare_terrain.build("panjin", config, directory, directory / "crop", "rasterio")


if __name__ == "__main__":
    unittest.main()
