"""Flatten the archived official SVG paths for offline Godot stone/hedge geometry.
Requires fontTools (already used by the project font tooling). No bitmap tracing.
"""
from pathlib import Path
import json, math, xml.etree.ElementTree as ET
from fontTools.svgLib.path import parse_path
from fontTools.pens.basePen import BasePen
ROOT=Path(__file__).resolve().parents[3]
class OutlinePen(BasePen):
    def __init__(self): super().__init__(None); self.rings=[]; self.current=[]
    def _moveTo(self,p): self.current=[list(p)]
    def _lineTo(self,p): self.current.append(list(p))
    def _curveToOne(self,a,b,c):
        p=self._getCurrentPoint()
        n=max(2,math.ceil((math.dist(p,a)+math.dist(a,b)+math.dist(b,c))/.45))
        for i in range(1,n+1):
            t=i/n;u=1-t
            self.current.append([u**3*p[k]+3*u*u*t*a[k]+3*u*t*t*b[k]+t**3*c[k] for k in range(2)])
    def _qCurveToOne(self,a,b):
        p=self._getCurrentPoint();self._curveToOne(tuple(p[k]+2/3*(a[k]-p[k]) for k in range(2)),tuple(b[k]+2/3*(a[k]-b[k]) for k in range(2)),b)
    def _closePath(self):
        if len(self.current)>2:
            if math.dist(self.current[0],self.current[-1])<1e-6:self.current.pop()
            self.rings.append([[round(x,5),round(y,5)] for x,y in self.current])
        self.current=[]
    def _endPath(self): self._closePath()
def build():
    paths=list(ET.parse(ROOT/'references/eda/structures/xiang-plaza/official-logo.svg').getroot().iter('{http://www.w3.org/2000/svg}path'))
    all_rings=[]
    for e in paths:
        pen=OutlinePen();parse_path(e.attrib['d'],pen)
        area=lambda r:sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(r,r[1:]+r[:1]))
        if pen.rings and area(max(pen.rings,key=lambda r:abs(area(r))))<0:
            for ring in pen.rings:ring.reverse()
        all_rings.append(pen.rings)
    result={'source':'https://www.dlut.edu.cn/images/logo.svg','letters':[r for group in all_rings[:12] for r in group],'emblem':[all_rings[40][i] for i in [10,33,40]]}
    target=ROOT/'apps/game/assets/campuses/eda/data/xiang_identity.json'
    target.write_text(json.dumps(result,separators=(',',':'))+'\n',encoding='utf8')
    return result
if __name__=='__main__':build()
