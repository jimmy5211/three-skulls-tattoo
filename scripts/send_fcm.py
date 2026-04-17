import json
import os
import urllib.request
import google.auth.transport.requests
from google.oauth2 import service_account

sa_info = json.loads(os.environ['FCM_SA_JSON'])
creds = service_account.Credentials.from_service_account_info(
    sa_info,
    scopes=['https://www.googleapis.com/auth/firebase.messaging']
)
creds.refresh(google.auth.transport.requests.Request())

version = '1.0.' + os.environ['RUN_NUMBER']
download_url = (
    'https://github.com/jimmy5211/three-skulls-tattoo/releases/download/'
    f'v{version}/app-release.apk'
)

# Leer notas de versión
try:
    with open('RELEASE_NOTES.md', 'r') as f:
        lines = [l.strip().lstrip('- ').strip()
                 for l in f.read().split('\n')
                 if l.strip().startswith('-')]
    notes = ' • '.join(lines[:4]) if lines else 'Mejoras y bug fixes'
except:
    notes = 'Mejoras y bug fixes'

body = json.dumps({
    'message': {
        'topic': 'updates',
        'notification': {
            'title': f'💀 Three Skulls {version} disponible',
            'body': notes[:100],
        },
        # data: disponible aunque la app esté cerrada
        'data': {
            'version': version,
            'downloadUrl': download_url,
            'notes': notes,
            'type': 'update',
        },
        'android': {
            'priority': 'HIGH',
            'notification': {'click_action': 'FLUTTER_NOTIFICATION_CLICK'},
        }
    }
}).encode('utf-8')

req = urllib.request.Request(
    'https://fcm.googleapis.com/v1/projects/three-skulls-tattoo-e4099/messages:send',
    data=body,
    headers={
        'Authorization': 'Bearer ' + creds.token,
        'Content-Type': 'application/json',
    }
)
resp = urllib.request.urlopen(req)
print(f'FCM sent: {resp.status} | version: {version}')
