"""Build and validate standalone ZIPs for the same five clients as Mailwright."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
VERSION='0.1.14'
FILES=['Localization.lua','Core.lua','API.lua','Eligibility.lua','Recipes.lua','Scan.lua','UI.lua','Options.lua','Bindings.xml','README.md','GUIDE.md','RELEASE_NOTES.md','LICENSE','TESTING.md','THIRD_PARTY_NOTICES.md','licenses/Molinari-MIT.txt']
CLIENTS=[('retail','Mainline'),('forever','Camelot'),('classic','Vanilla'),('mists','Mists'),('bcc','TBC')]
def artifact_name(flavor):
    suffix = "" if flavor == "retail" else "-" + flavor
    return f"ShatterBar-{VERSION}{suffix}.zip"


def build():
    dest=ROOT/'dist'/VERSION
    dest.mkdir(parents=True,exist_ok=True)
    metadata=[]
    for flavor,manifest in CLIENTS:
        entries={f'ShatterBar/{f}':(ROOT/f).read_bytes() for f in FILES}
        toc=(ROOT/f'ShatterBar_{manifest}.toc').read_bytes()
        for line in toc.decode('utf-8-sig').splitlines():
            if line.startswith('Data/'):
                entries['ShatterBar/'+line]=(ROOT/line).read_bytes()
        entries['ShatterBar/ShatterBar.toc']=toc
        entries[f'ShatterBar/ShatterBar_{manifest}.toc']=toc
        if flavor=='forever':
            entries['ShatterBar/FlavorForever.lua']=(ROOT/'FlavorForever.lua').read_bytes()
            entries['ShatterBar/ShatterBar_Mainline.toc']=toc
        for name,data in list(entries.items()):
            if name.endswith('.toc'):
                for line in data.decode('utf-8-sig').splitlines():
                    if line.strip() and not line.startswith('#'):
                        assert 'ShatterBar/'+line.strip() in entries, (flavor,line)
        out=dest/artifact_name(flavor)
        with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
            for name,data in sorted(entries.items()): z.writestr(name,data)
        with zipfile.ZipFile(out) as z:
            assert z.testzip() is None
            assert set(z.namelist())==set(entries)
            for name,data in entries.items(): assert z.read(name)==data
        metadata.append({'client':flavor,'file':out.name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
        print('PASS package',out.name)
    (dest/'checksums.json').write_text(json.dumps(metadata,indent=2)+'\n')
if __name__=='__main__': build()
