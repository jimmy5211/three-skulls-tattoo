# Script simple: lee RELEASE_NOTES.md y imprime JSON array
import json

with open('RELEASE_NOTES.md', 'r') as f:
    content = f.read()

lines = [
    l.strip().lstrip('- ').strip()
    for l in content.split('\n')
    if l.strip().startswith('-')
]

print(json.dumps(lines))
