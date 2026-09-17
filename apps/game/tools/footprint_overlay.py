"""Preview acquired OSM bounds on official lm30 tiles; no geometry changes.

Run footprint_consensus.py first, then this tool with --serve --download.
Only visible tiles are requested; --download authorizes cache misses.
"""
import argparse
import hashlib
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import json
import math
from pathlib import Path
import re
import urllib.request
from datetime import datetime, timezone

from footprint_review import ROOT, project


def build(output):
    data=json.loads((ROOT/'.local/footprint-consensus/normalized-bounds.json').read_text(encoding='utf-8'))
    samples=json.loads((ROOT/'.local/footprint-consensus/candidate-bounds.json').read_text(encoding='utf-8'))['results']
    campuses={}
    for campus in ('lingshui','eda','panjin'):
        sample=next(r for r in samples if r['campus']==campus)
        alignment=sample['initial_alignment']
        shift=alignment['shift_lon_lat']
        records=[]
        for r in data['records']:
            if r['campus']!=campus: continue
            rings=r['bound'].get('rings',[{'role':'outer','points':r['bound'].get('points',[])}])
            paths=[]
            for ring in rings:
                points=[project(p['x']+(shift[0] if r['source']=='osm' else 0),
                                p['y']+(shift[1] if r['source']=='osm' else 0),19) for p in ring['points']]
                paths.append({'role':ring['role'],'points':points})
            records.append({'id':r['id'],'source':r['source'],'name':r.get('name') or r.get('tags',{}).get('name',''),
                            'valid':r['valid'],'url':r['source_url'],'paths':paths})
        center=sample['pixel_origin']
        lat=sample['bound']['points'][0]['y']
        campuses[campus]={'records':records,'center':center,'alignment':alignment,
                          'meters_per_pixel':math.cos(math.radians(lat))*2*math.pi*6378137/(256*2**19)}
    output.mkdir(parents=True,exist_ok=True)
    payload=json.dumps(campuses,ensure_ascii=False).replace('<','\\u003c')
    template=Path(__file__).with_suffix('.html').read_text(encoding='utf-8')
    (output/'index.html').write_text(template.replace('__DATA__',payload),encoding='utf-8')


def serve(output,port,download):
    cache=output/'tiles'; cache.mkdir(exist_ok=True)
    class Handler(SimpleHTTPRequestHandler):
        def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(output),**kwargs)
        def do_GET(self):
            match=re.fullmatch(r'/tiles/(1[6-9])/(\d+)/(\d+)\.png',self.path)
            if not match:return super().do_GET()
            z,x,y=map(int,match.groups())
            if not (0<=x<2**z and 0<=y<2**z):return self.send_error(400)
            path=cache/f'{z}-{x}-{y}.png'
            try:
                if not path.exists():
                    if not download:return self.send_error(404,'Not cached; enable --download')
                    url=f'http://map.dlut.edu.cn/map?lyrs=lm30&x={x}&y={y}&z={z}'
                    with urllib.request.urlopen(url,timeout=60) as response:body=response.read()
                    if not (body.startswith(b'\x89PNG') or body.startswith(b'\xff\xd8')):
                        raise ValueError('Unexpected tile content')
                    path.write_bytes(body)
                    path.with_suffix('.json').write_text(json.dumps({'url':url,'retrieved':datetime.now(timezone.utc).isoformat(),
                        'sha256':hashlib.sha256(body).hexdigest()}),encoding='utf-8')
                body=path.read_bytes()
                self.send_response(200);self.send_header('Content-Type','image/png' if body.startswith(b'\x89PNG') else 'image/jpeg')
                self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
            except (OSError,ValueError) as error:self.send_error(502,str(error))
        def log_message(self,*args):pass
    print(f'http://127.0.0.1:{port}/',flush=True)
    ThreadingHTTPServer(('127.0.0.1',port),Handler).serve_forever()


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=ROOT/'.local/footprint-overlay')
    p.add_argument('--port',type=int,default=8772)
    p.add_argument('--serve',action='store_true');p.add_argument('--download',action='store_true')
    args=p.parse_args();build(args.output)
    if args.serve:serve(args.output,args.port,args.download)
