import urllib.request,struct,zlib,pathlib,json
meta=json.load(urllib.request.urlopen('https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable', timeout=30))
asset=next(a for a in meta['assets'] if a['name']=='Godot_v4.7.2-stable_export_templates.tpz')
url=asset['browser_download_url']
# Fetch only ZIP central directory and selected members, rather than all platform templates.
def read_range(start,end):
 req=urllib.request.Request(url,headers={'Range':f'bytes={start}-{end}','User-Agent':'dlut-campus-build'})
 with urllib.request.urlopen(req,timeout=60) as r:
  if r.status != 206: raise RuntimeError('Server did not honor byte range')
  return r.read()
size=asset['size']; tail=read_range(size-65536,size-1)
pos=tail.rfind(b'PK\x05\x06'); e=struct.unpack_from('<4s4H2LH',tail,pos)
cd=read_range(e[6],e[6]+e[5]-1); p=0
out=pathlib.Path.home()/'Library/Application Support/Godot/export_templates/4.7.2.stable';out.mkdir(parents=True,exist_ok=True)
while p<len(cd):
 h=struct.unpack_from('<4s6H3L5H2L',cd,p)
 name=cd[p+46:p+46+h[10]].decode();p+=46+h[10]+h[11]+h[12]
 if name.split('/')[-1] not in ('web_nothreads_release.zip','web_nothreads_debug.zip','version.txt'): continue
 print('Downloading',name,h[8],flush=True)
 local=read_range(h[16],h[16]+29);lh=struct.unpack('<4s5H3L2H',local)
 start=h[16]+30+lh[9]+lh[10];raw=read_range(start,start+h[8]-1)
 data=zlib.decompress(raw,-15) if h[4]==8 else raw
 assert len(data)==h[9] and zlib.crc32(data)==h[7]
 (out/name.split('/')[-1]).write_bytes(data)
 print('Installed',name,len(data),flush=True)
print('Done',flush=True)
