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
body = json.dumps({
    'message': {
        'topic': 'updates',
        'notification': {
            'title': '💀 Three Skulls ' + version + ' disponible',
            'body': 'Nueva versión lista. Toca para actualizar.'
        },
        'android': {'priority': 'HIGH'}
    }
}).encode('utf-8')

req = urllib.request.Request(
    'https://fcm.googleapis.com/v1/projects/three-skulls-tattoo-e4099/messages:send',
    data=body,
    headers={
        'Authorization': 'Bearer ' + creds.token,
        'Content-Type': 'application/json'
    }
)
resp = urllib.request.urlopen(req)
print('FCM enviado:', resp.status)
