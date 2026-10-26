"""Prepare a geographically registered map reference or quantize imagegen output."""
import argparse,json,math
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
MAP=ROOT/'apps/web/public/campuses/eda/map.json'
def main():
 p=argparse.ArgumentParser();p.add_argument('--generated',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 m=json.loads(MAP.read_text(encoding='utf-8'));size=(math.ceil(m['width']/10),math.ceil(m['height']/10));a.output.parent.mkdir(parents=True,exist_ok=True)
 if a.generated:
  image=Image.open(a.generated).convert('RGB').resize(size,Image.Resampling.NEAREST).quantize(colors=64,method=Image.Quantize.MAXCOVERAGE,dither=Image.Dither.NONE);image.save(a.output);return
 colors=['#c5bd94','#9bb96b','#5c925d','#548f9d','#a29b88','#d6c89d','#ba795f','#c6bf9e','#d7ceac','#b76b58','#7ba19a','#92ad65']
 native=Image.new('RGB',(m['width'],m['height']),colors[0]);pixels=native.load();i=0
 for count,material in zip(m['materialRuns'][::2],m['materialRuns'][1::2]):
  for index in range(i,i+count):pixels[index%m['width'],index//m['width']]=tuple(bytes.fromhex(colors[material][1:]))
  i+=count
 image=native.resize(size,Image.Resampling.NEAREST);d=ImageDraw.Draw(image)
 for b in m['buildings']:
  points=[(round(x/10),round(y/10)) for x,y in b['footprint']];d.polygon(points,fill='#ddd5bb',outline='#53677a')
  if b['style'] in ('information','academic'):d.line(points,fill='#487496',width=1)
 image.resize((size[0]*8,size[1]*8),Image.Resampling.NEAREST).save(a.output)
if __name__=='__main__':main()
