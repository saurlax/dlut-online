"""Offline source regressions for geometry and datum migration, no game startup."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import osm_world as osm
from prepare_osm_world import build, scope
from prepare_osm_terrain import Elevation


class OSMWorldTests(unittest.TestCase):
    def test_courtyards_are_not_filled(self):
        _,nodes,ways,relations=osm.archive('eda')
        rings=osm.relation_rings(relations['3123051'],ways,nodes)
        self.assertEqual([r['role'] for r in rings],['outer','inner','inner'])

    def test_conflicting_information_building_names_are_not_averaged(self):
        data=build('eda')
        conflict=next(c for c in data['identity_conflicts'] if '信息楼' in c['name'])
        self.assertEqual(set(conflict['osm_ids']),{'relation/19052855','way/1422474847'})
        records={r['osm_id']:r for r in data['areas']}
        self.assertLess(records['relation/19052855']['area_m2'],110)
        self.assertGreater(records['way/1422474847']['area_m2'],6000)
        self.assertNotIn('way/1076344097',records)

    def test_concave_boundary_does_not_admit_outside_segment(self):
        boundary=[[0,0],[10,0],[10,10],[8,10],[8,2],[7,2],[7,10],[0,10]]
        self.assertEqual(scope([[1,5],[9,5]],boundary,False),'boundary-crossing')

    def test_elevation_uses_identical_geographic_points(self):
        for campus in ('lingshui','eda'):
            terrain=Elevation(campus)
            _,nodes,ways,_=osm.archive(campus)
            for lon,lat in osm.way_coordinates(ways[osm.frame(campus)['boundary_way']],nodes):
                x,z=osm.local(campus,lon,lat)
                actual=terrain.sample(x,z)
                self.assertAlmostEqual(actual,terrain.sample_geographic(lon,lat),places=8)
                restored=osm.geographic(campus,x,z)
                self.assertAlmostEqual(restored[0],lon,places=10)
                self.assertAlmostEqual(restored[1],lat,places=10)


if __name__=='__main__':
    unittest.main()
