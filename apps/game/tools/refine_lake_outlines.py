"""Bounded, photo-reviewed shoreline interpolation; source vertices remain archived."""
import hashlib
import json
import math

from prepare_osm_world import valid_ring


def refine(points, profile):
    def unit(vector):
        length = math.hypot(*vector)
        return [v / length for v in vector] if length else [0.0, 0.0]

    def tangent(index):
        a, b, c = points[index - 1], points[index], points[(index + 1) % len(points)]
        incoming = unit([b[k] - a[k] for k in (0, 1)])
        outgoing = unit([c[k] - b[k] for k in (0, 1)])
        return unit([incoming[k] + outgoing[k] for k in (0, 1)])

    result = []
    for i, a in enumerate(points):
        b = points[(i + 1) % len(points)]
        length = math.dist(a, b)
        direction = unit([b[k] - a[k] for k in (0, 1)])
        handles = []
        for index, endpoint, sign in [(i, a, 1), ((i + 1) % len(points), b, -1)]:
            t = tangent(index)
            across = abs(t[0] * direction[1] - t[1] * direction[0])
            reach = min(length / 3, profile['max_deviation_m'] / max(across, 1e-9))
            handles.append([endpoint[k] + sign * reach * t[k] for k in (0, 1)])
        c, d = handles
        # The derivative is a convex combination of three control-edge vectors.
        steps = math.ceil(3 * max(math.dist(a, c), math.dist(c, d), math.dist(d, b)) / profile['max_segment_m'])
        for j in range(steps):
            t = j / steps
            result.append([round((1-t)**3*a[k] + 3*(1-t)**2*t*c[k] + 3*(1-t)*t*t*d[k] + t**3*b[k], 4) for k in (0, 1)])
    if not valid_ring(result):
        raise ValueError('Refined lake outline self-intersects')
    return result


def apply(features, profile):
    for selection in profile['lakes']:
        feature = next(f for f in features if f['id'] == selection['feature_id'])
        source = feature['points']
        digest = hashlib.sha256(json.dumps(source, separators=(',', ':')).encode()).hexdigest()
        review = selection['outline_refinement']
        if feature['osm_id'] != selection['osm_id'] or feature['osm_version'] != review['osm_version'] or digest != review['source_sha256']:
            raise ValueError('Lake source changed; review shoreline interpolation')
        feature['source_outline'] = source
        feature['points'] = refine(source, review)
        feature['geometry_status'] = 'photo-reviewed-bounded-curve; not surveyed'
        feature['outline_refinement'] = dict(review, source='references/eda/terrain/lake-shores.json')
