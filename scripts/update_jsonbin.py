import json
import os
import urllib.request

# Leer RELEASE_NOTES.md
with open('RELEASE_NOTES.md', 'r') as f:
    content = f.read()

# Extraer líneas con guión
lines = [l.strip().lstrip('- ').strip() 
         for l in content.split('\n') 
         if l.strip().startswith('-')]

version = '1.0.' + os.environ['RUN_NUMBER']
version_code = 1000 + int(os.environ['RUN_NUMBER'])
download_url = (
    'https://github.com/jimmy5211/three-skulls-tattoo/releases/download/'
    f'v{version}/app-release.apk'
)

payload = json.dumps({
    'version': version,
    'versionCode': version_code,
    'downloadUrl': download_url,
    'mandatory': False,
    'releaseNotes': lines
}).encode('utf-8')

req = urllib.request.Request(
    'https://api.jsonbin.io/v3/b/69b8b65eaa77b81da9ef4f41',
    data=payload,
    method='PUT',
    headers={
        'Content-Type': 'application/json',
        'X-Master-Key': os.environ['JSONBIN_API_KEY'],
    }
)
resp = urllib.request.urlopen(req)
print('JSONBin updated:', resp.status, '| version:', version)
print('Notes:', lines)
