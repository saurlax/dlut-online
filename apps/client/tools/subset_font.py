"""Build the embedded UI font from an official Noto Sans SC source TTF.
Usage: python subset_font.py /path/to/NotoSansSC.ttf (requires fonttools).
"""
import sys
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset
root=Path(__file__).resolve().parents[1]
font=TTFont(sys.argv[1])
font=instantiateVariableFont(font,{'wght':400},inplace=True)
chars=''.join(chr(i) for i in range(32,127))
for p in list((root/'scripts').glob('*.gd'))+list((root/'assets/campuses').rglob('*.json')):
 chars+=p.read_text()
options=subset.Options();options.layout_features=['*']
subsetter=subset.Subsetter(options=options);subsetter.populate(text=chars);subsetter.subset(font)
for record in font['name'].names:
 if record.nameID in [1,4,6]:
  record.string=('CampusSans' if record.nameID==6 else 'Campus Sans').encode(record.getEncoding())
font.save(root/'assets/fonts/CampusSans.ttf')
print('Embedded font:',(root/'assets/fonts/CampusSans.ttf').stat().st_size,'bytes')
