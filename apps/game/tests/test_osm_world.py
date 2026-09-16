"""Offline source regressions for geometry and datum migration, no game startup."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import osm_world as osm
from prepare_osm_world import build, scope, inside
from prepare_osm_terrain import Elevation
from prepare_osm_identities import build as identities
from refine_osm_footprints import refine


class OSMWorldTests(unittest.TestCase):
    def test_information_refinement_preserves_osm_exterior_and_raw_record(self):
        record=next(r for r in build('eda')['areas'] if r['osm_id']=='way/1422474847')
        result=refine('eda',record)
        self.assertNotIn('original_polygons',record)
        old=record['polygons'][0]['outer'];new=result['polygons'][0]['outer']
        self.assertEqual(len(new),12)
        for a,b in zip(old,[new[i] for i in (0,5,6,11)]):
            for x,y in zip(a,b):self.assertAlmostEqual(x,y,places=7)
        self.assertLess(result['area_m2'],record['area_m2'])
        for indexes in ((1,2,3,4),(7,8,9,10)):
            center=[sum(new[j][i] for j in indexes)/4 for i in (0,1)]
            self.assertTrue(inside(center,old))
            self.assertFalse(inside(center,new))
        record['version']+=1
        with self.assertRaisesRegex(ValueError,'version changed'):refine('eda',record)

    def test_identity_import_retains_missing_and_outside_buildings(self):
        data=identities('lingshui')
        records={r['official_id']:r for r in data['buildings']}
        self.assertEqual(records['77456']['status'],'matched')
        self.assertEqual(records['77456']['osm_candidates'][0]['osm_id'],'way/1384296476')
        self.assertEqual(records['77456']['osm_candidates'][0]['scope'],'outside')
        self.assertEqual(records['77490']['status'],'matched')
        self.assertEqual(records['77490']['osm_candidates'][0]['osm_id'],'way/1383545735')
        self.assertEqual(records['2554118']['status'],'missing')
        self.assertEqual(len(records),209)

    def test_shared_official_identity_retains_both_osm_buildings(self):
        data=identities('eda')
        records={r['official_id']:r for r in data['buildings']}
        self.assertEqual({r['osm_id'] for r in records['2304982']['osm_candidates']},
                         {'way/375541049','way/1381473266'})
        self.assertEqual(records['77914']['osm_candidates'][0]['osm_id'],'way/1422474847')
        self.assertEqual(records['77943']['status'],'missing')

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
