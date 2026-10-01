import zipfile
import re

def dump_methods():
    jar_path = r'c:\Users\krush\Sarthi\Sarthi app\android\app\libs\aar_unzipped\classes.jar'
    with zipfile.ZipFile(jar_path, 'r') as z:
        for name in z.namelist():
            if 'OlaMap.class' in name or 'OlaMarkerOptions' in name:
                data = z.read(name)
                # Extract all readable ascii strings >= 4 chars
                strings = re.findall(b'[a-zA-Z0-9_]{4,}', data)
                print(f"--- {name} ---")
                print(set([s.decode('ascii') for s in strings]))

if __name__ == '__main__':
    dump_methods()
