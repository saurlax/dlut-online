"""Geometry regressions for the baked background/campus interface (no GIS deps)."""
import json
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]


def area(ring):
    return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1])))/2


class SurroundingsTests(unittest.TestCase):
    def test_background_hole_and_shared_edge_samples(self):
        for campus in ('lingshui', 'eda', 'panjin'):
            with self.subTest(campus=campus):
                directory = ROOT/f'apps/game/assets/campuses/{campus}/data'
                background = json.loads((directory/'surroundings.json').read_text())
                terrain = json.loads((directory/'terrain.json').read_text())
                source = json.loads((ROOT/f'references/{campus}/terrain/surroundings-source.json').read_text(encoding='utf-8'))
                self.assertEqual(source['absolute_y_offset_egm2008_m'], terrain['absolute_y_offset_egm2008_m'])
                flat = background['vertices']
                vertices = [flat[i:i+3] for i in range(0,len(flat),3)]
                self.assertTrue(all(math.isfinite(v) for v in flat))
                xmin,zmin,xmax,zmax = background['campus_rect']
                lookup = {(round(x,3),round(z,3)):y for x,y,z in vertices}
                for r in range(terrain['height']):
                    for c in range(terrain['width']):
                        if r not in (0,terrain['height']-1) and c not in (0,terrain['width']-1):continue
                        x,z=xmin+c*terrain['step_m'],zmin+r*terrain['step_m']
                        self.assertAlmostEqual(lookup[round(x,3),round(z,3)],terrain['rows'][r][c],places=3)
                ids=background['indices']
                for i in range(0,len(ids),3):
                    tri=[vertices[v] for v in ids[i:i+3]]
                    x,z=sum(p[0] for p in tri)/3,sum(p[2] for p in tri)/3
                    self.assertFalse(xmin+0.001<x<xmax-0.001 and zmin+0.001<z<zmax-0.001)
                self.assertTrue(all(b['osm_id'] and b['height_source'] and b['roof'] for b in background['buildings']))
                for building in background['buildings']:
                    expected=area(building['outer'])-sum(area(hole) for hole in building['holes'])
                    self.assertAlmostEqual(sum(area(tri) for tri in building['roof']),expected,places=3,
                                           msg=building['osm_id']+' roof must preserve courtyard holes')


if __name__ == '__main__':
    unittest.main()
