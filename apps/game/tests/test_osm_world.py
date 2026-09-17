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
    def test_nonbuilding_reference_retains_source_and_rejects_changed_evidence(self):
        import copy
        from prepare_lingshui import retain_nonbuilding_references
        feature = {'id':'poi','part':0,'kind':'building','facade':{},
                   'points':[[10,10],[20,10],[20,20]],
                   'reference_points':[[0,0],[10,0],[10,10]],
                   'geometry_status':'legacy-silhouette-pending-replacement'}
        spec = {'id':'poi','part':0,'reference_type':'traffic-counter',
                'source':'public-source','expected_reference_points':feature['reference_points']}
        actual = copy.deepcopy(feature)
        retain_nonbuilding_references([actual],[spec])
        self.assertEqual(actual['kind'],'reference')
        self.assertEqual(actual['points'],feature['points'])
        self.assertEqual(actual['reference_points'],feature['reference_points'])
        for change in [{'osm_id':'way/1'},{'facade':{'windows':1}},
                       {'reference_points':[[0,0],[11,0],[10,10]]},
                       {'geometry_status':'osm-source-outline'}]:
            actual = {**copy.deepcopy(feature),**change}
            before = copy.deepcopy(actual)
            with self.assertRaises(ValueError):
                retain_nonbuilding_references([actual],[spec])
            self.assertEqual(actual,before)
        with self.assertRaises(ValueError):
            retain_nonbuilding_references([copy.deepcopy(feature)],[spec,spec])

    def test_shared_compound_preserves_ids_and_rejects_new_member_geometry(self):
        import copy
        from prepare_lingshui import share_reviewed_building_geometry
        owner = {'id':'owner','part':0,'kind':'building','osm_id':'relation/1',
                 'osm_version':2,'points':[[0,0],[10,0],[10,10],[0,10]],
                 'holes':[[[2,2],[8,2],[8,8],[2,8]]]}
        member = {'id':'member','part':0,'kind':'building','facade':{},
                  'points':[[1,1],[9,1],[9,9]],'reference_points':[[0,0],[1,0],[1,1]],
                  'geometry_status':'legacy-silhouette-pending-replacement'}
        spec = {'id':'assembly','owner_id':'owner','owner_part':0,'osm_id':'relation/1',
                'osm_version':2,'outer_vertices':4,'hole_vertices':[4],
                'members':[{'id':'member','part':0}]}
        features = copy.deepcopy([owner,member])
        share_reviewed_building_geometry(features,[spec])
        self.assertEqual(features[0]['points'],owner['points'])
        self.assertEqual(features[0]['holes'],owner['holes'])
        self.assertEqual(features[0]['shared_official_ids'],['owner','member'])
        self.assertEqual(features[1]['reference_points'],member['reference_points'])
        self.assertEqual(features[1]['kind'],'reference')
        self.assertEqual(features[1]['shared_geometry'],{'id':'owner','part':0})
        for change in [{'facade':{'style':'photo_panels'}}, {'osm_id':'way/2'},
                       {'geometry_status':'photo-refined'}, {'holes':[[[0,0]]]}]:
            features = copy.deepcopy([owner,dict(member,**change)])
            before = copy.deepcopy(features)
            with self.assertRaisesRegex(ValueError,'member changed'):
                share_reviewed_building_geometry(features,[spec])
            self.assertEqual(features,before)
        for change in [{'osm_version':3}, {'hole_vertices':[]},
                       {'members':[{'id':'owner','part':0}]}]:
            features = copy.deepcopy([owner,member])
            with self.assertRaises(ValueError):
                share_reviewed_building_geometry(features,[dict(spec,**change)])
            self.assertEqual(features,[owner,member])

    def test_road_termination_requires_shared_node_and_versions(self):
        import copy
        import json
        from unittest.mock import patch
        import prepare_osm_roads as roads
        path = osm.ROOT/'references/eda/mapping/road-terminations.json'
        original_read = Path.read_text
        config = json.loads(original_read(path, encoding='utf-8'))
        for field, value in [('road_version', 999), ('building_version', 999), ('shared_node', '0')]:
            invalid = copy.deepcopy(config)
            invalid['terminations'][0][field] = value
            def read(candidate, *args, **kwargs):
                return json.dumps(invalid) if candidate == path else original_read(candidate, *args, **kwargs)
            with patch.object(Path, 'read_text', read), patch.object(Path, 'write_text') as write:
                with self.assertRaisesRegex(ValueError, 'shared building node'):
                    roads.build('eda')
                write.assert_not_called()

    def test_map_surface_requires_connected_versioned_closing_way(self):
        import copy
        import json
        from unittest.mock import patch
        import prepare_map_surfaces as surfaces
        path=osm.ROOT/'references/eda/mapping/ground-surfaces.json'
        original_read=Path.read_text
        config=json.loads(original_read(path,encoding='utf-8'))
        result=surfaces.build('eda')
        north=next(r for r in result if r['id']=='eda-comprehensive-north-court')
        self.assertEqual(north['osm_anchor_ways'],['1076344134','1076344135'])
        self.assertEqual(len(north['outer']),14)
        self.assertTrue(all(-330<p[0]<-270 and 260<p[1]<291 for p in north['outer']))
        self.assertIsNone(north['absolute_accuracy_m'])
        for closing,message in [({'way_id':'1076344135','version':999},'version changed'),
                                ({'way_id':'1076344136','version':1},'must join'),
                                (None,'closed OSM loop')]:
            invalid=copy.deepcopy(config)
            anchor=invalid['surfaces'][1]['osm_anchor']
            if closing is None: anchor.pop('closing_way')
            else: anchor['closing_way']=closing
            def read(candidate,*args,**kwargs):
                if candidate==path:return json.dumps(invalid)
                return original_read(candidate,*args,**kwargs)
            with patch.object(Path,'read_text',read):
                with self.assertRaisesRegex(ValueError,message):surfaces.build('eda')

    def test_relation_review_keeps_inner_ring_and_rejects_single_ring_draft(self):
        import copy
        import json
        from unittest.mock import patch
        import footprint_review as review
        config=json.loads(review.CONFIG.read_text(encoding='utf-8'))
        spec=next(c for c in config['cases'] if c.get('osm_relation_id')=='2898296')
        # Source relation is real; only tile bytes are replaced to keep this test offline.
        def tile(url,cache,download,image=False):
            self.assertTrue(image)
            return b'\x89PNG\r\n\x1a\n', {'url':url,'sha256':'tile-test'}
        with patch.object(review,'fetch',side_effect=tile):
            case=review.build_case(spec,config,Path('.'),False)
        self.assertTrue(case['read_only'])
        self.assertEqual(case['osm_id'],'relation/2898296')
        self.assertEqual(len(case['osm']['points']),8)
        self.assertEqual([len(h) for h in case['osm']['holes']],[4])
        expected=next(r for r in build('lingshui')['areas'] if r['osm_id']=='relation/2898296')
        for got,want in zip(case['osm']['raw_wgs84_holes'][0],expected['polygons'][0]['holes'][0]):
            self.assertEqual(osm.local('lingshui',*got),want)
        self.assertEqual(case['related_official'][0]['official_id'],'77419')
        saved={'status':'unverified-map-plane-draft','reference':'official-lm30-pixel-plane','cases':[copy.deepcopy(case)]}
        saved['cases'][0]['draft']={'status':'reference-only','points':[],'notes':'keep courtyard'}
        review.restore_drafts(saved,[case])
        self.assertEqual(case['draft']['status'],'reference-only')
        saved['cases'][0]['draft']={'status':'unverified','points':case['osm']['points'],'notes':'outer only'}
        with self.assertRaisesRegex(ValueError,'read-only'):review.restore_drafts(saved,[case])

    def test_generators_reject_legacy_or_mismatched_frame_before_writing(self):
        import json
        from unittest.mock import patch
        import prepare_osm_roads
        import prepare_terrain_preview
        original_read=Path.read_text
        for campus in ('lingshui','eda','panjin'):
            path=osm.ROOT/f'apps/game/assets/campuses/{campus}/data/campus.json'
            manifest=json.loads(original_read(path,encoding='utf-8'))
            for field,value in [('geographic_crs',None),('coordinate_frame','legacy-alignment'),('origin',[0,0])]:
                invalid=dict(manifest);invalid[field]=value
                def read(candidate,*args,**kwargs):
                    if candidate==path:return json.dumps(invalid)
                    return original_read(candidate,*args,**kwargs)
                generators=[prepare_osm_roads.build]
                if campus!='panjin':generators.append(prepare_terrain_preview.build)
                for generate in generators:
                    with self.subTest(campus=campus,field=field,generator=generate.__module__):
                        with patch.object(Path,'read_text',autospec=True,side_effect=read), patch.object(Path,'write_text',autospec=True) as write:
                            with self.assertRaisesRegex(ValueError,'shared WGS84 frame required'):
                                generate(campus)
                            write.assert_not_called()

    def test_deferred_identity_preserves_legacy_geometry_during_preparation(self):
        import contextlib
        import io
        import json
        from unittest.mock import patch
        import prepare_lingshui
        match=next(r for r in identities('lingshui')['buildings'] if r['official_id']=='2283256')
        self.assertEqual(match['status'],'matched')
        self.assertTrue(match['geometry_deferred'])
        self.assertEqual(match['osm_candidates'][0]['tags']['ref'],'东山锅炉房')
        self.assertEqual(match['osm_candidates'][0]['osm_id'],'way/233806536')
        written={}
        def capture(path,text,**kwargs):
            written[path]=text
            return len(text)
        with patch.object(Path,'write_text',autospec=True,side_effect=capture), contextlib.redirect_stdout(io.StringIO()):
            prepare_lingshui.main()
        generated=json.loads(written[prepare_lingshui.OUTPUT/'campus.json'])
        features={f['id']:f for f in generated['features']}
        self.assertNotIn('osm_id',features['2283256'])
        self.assertIn('reference_points',features['2283256'])
        self.assertEqual(features['2283256']['geometry_status'],'legacy-silhouette-pending-replacement')
        self.assertEqual(features['77443']['osm_id'],'way/219032067')
        square = features['17922962']
        expected = next(r for r in build('lingshui')['areas'] if r['osm_id']=='way/547582635')
        self.assertEqual(square['points'],expected['polygons'][0]['outer'])
        self.assertEqual(square['osm_version'],1)
        self.assertNotIn('reference_points',square)
        self.assertEqual(square['unmodeled_osm_ids'],['way/547582634'])
        self.assertIn('partial-osm-square',square['geometry_status'])

    def test_c_block_refinement_retains_anchors_and_narrow_connector(self):
        import json
        from refine_osm_footprints import similarity_map
        record=next(r for r in build('eda')['areas'] if r['osm_id']=='way/1422474849')
        result=refine('eda',record)
        spec=next(r for r in json.loads((osm.ROOT/'references/eda/mapping/footprint-refinements.json').read_text(encoding='utf-8'))['refinements'] if r['official_id']=='77927')
        old=record['polygons'][0]['outer'];new=result['polygons'][0]['outer']
        for a,b in zip([old[i] for i in (0,12)],[new[i] for i in (0,1)]):
            for x,y in zip(a,b):self.assertAlmostEqual(x,y,places=7)
        convert=similarity_map([a['pixel'] for a in spec['anchors']],[old[a['osm_vertex']] for a in spec['anchors']])
        import math
        north=[new[1][i]-new[0][i] for i in (0,1)]
        south=[new[2][i]-new[24][i] for i in (0,1)]
        self.assertLess(abs(north[0]*south[1]-north[1]*south[0]),1e-6)
        self.assertAlmostEqual(math.hypot(*south)/math.hypot(*north),159/160,places=8)
        self.assertEqual([r['osm_vertex'] for r in result['refinement']['check_anchor_residuals_m']],[11,5])
        self.assertIsNone(result['refinement']['absolute_accuracy_m'])
        with self.assertRaisesRegex(ValueError,'Degenerate'):similarity_map([[0,0],[0,0]],[[1,1],[2,2]])
        self.assertTrue(inside(convert([530,600]),new))
        self.assertFalse(inside(convert([490,600]),new))
        self.assertNotIn('original_polygons',record)

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
        self.assertEqual(records['29813247']['osm_candidates'][0]['osm_id'],'way/1384296479')
        self.assertEqual(records['83981']['status'],'missing')
        self.assertEqual(records['83981']['shared_geometry'],{'id':'77492','part':0})
        self.assertEqual(records['77423']['osm_candidates'][0]['osm_id'],'way/233806548')
        self.assertEqual(records['77423']['osm_candidates'][0]['osm_version'],2)
        self.assertEqual(records['77424']['status'],'missing')
        self.assertEqual(records['77425']['status'],'missing')
        self.assertEqual(records['77446']['osm_candidates'][0]['osm_id'],'way/233806513')
        self.assertEqual(records['77446']['osm_candidates'][0]['osm_version'],1)
        self.assertEqual(records['77443']['osm_candidates'][0]['osm_id'],'way/219032067')
        self.assertEqual(records['77444']['osm_candidates'][0]['osm_id'],'way/219032047')
        self.assertEqual(len(records),208)
        self.assertNotIn('81821',records) # Reviewed traffic-count POI, retained in the campus manifest.
        self.assertEqual(records['77419']['shared_geometry'],{'id':'77420','part':0})
        self.assertEqual(records['77419']['status'],'missing') # Independent partition is unresolved.

    def test_indoor_pool_is_retained_without_becoming_a_building(self):
        records={r['osm_id']:r for r in build('lingshui')['areas']}
        pool=records['way/233806517']
        self.assertEqual(pool['category'],'swimming-pool')
        self.assertEqual(pool['version'],3)
        self.assertEqual(pool['tags']['location'],'indoor')
        self.assertEqual(pool['tags']['leisure'],'swimming_pool')
        self.assertNotIn('building',pool['tags'])
        self.assertEqual(len(pool['polygons'][0]['outer']),4)
        combined=next(r for r in identities('lingshui')['buildings'] if r['official_id']=='77445')
        self.assertEqual({r['osm_id']:r['category'] for r in combined['osm_candidates']},
                         {'way/233806531':'building','way/233806517':'swimming-pool'})
        self.assertTrue(combined['geometry_review_required'])

    def test_shared_official_identity_retains_both_osm_buildings(self):
        data=identities('eda')
        records={r['official_id']:r for r in data['buildings']}
        self.assertEqual({r['osm_id'] for r in records['2304982']['osm_candidates']},
                         {'way/375541049','way/1381473266'})
        self.assertEqual(records['77914']['osm_candidates'][0]['osm_id'],'way/1422474847')
        self.assertEqual(records['77943']['status'],'matched')
        self.assertEqual(records['77943']['osm_candidates'][0]['osm_id'],'way/375541048')

    def test_dining_area_does_not_require_or_invent_building_tag(self):
        records={r['osm_id']:r for r in build('eda')['areas']}
        dining=records['way/375541048']
        self.assertEqual(dining['category'],'amenity-area')
        self.assertEqual(dining['tags']['amenity'],'restaurant')
        self.assertNotIn('building',dining['tags'])
        self.assertEqual(dining['version'],5)
        self.assertEqual(len(dining['polygons'][0]['outer']),19)

    def test_named_square_is_retained_without_building_or_highway_tags(self):
        records={r['osm_id']:r for r in build('eda')['areas']}
        square=records['way/1381503838']
        self.assertEqual(square['category'],'square')
        self.assertEqual(square['tags']['place'],'square')
        self.assertNotIn('building',square['tags'])
        self.assertNotIn('highway',square['tags'])
        self.assertEqual(square['version'],2)
        self.assertEqual(len(square['polygons'][0]['outer']),33)

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
