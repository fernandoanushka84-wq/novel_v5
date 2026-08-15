import urllib.request, json, sys
url='http://127.0.0.1:8000/api/bootstrap'
try:
    with urllib.request.urlopen(url, timeout=15) as r:
        data = json.load(r)
except Exception as e:
    print('ERROR', e)
    sys.exit(1)
print('keys:', sorted(list(data.keys())))
print('menu_sections:', len(data.get('menu_sections', [])))
print('achievements:', len(data.get('achievements', [])))
print('reading_lists in profile:', len(data.get('profile', {}).get('reading_lists', [])))
# Print first few menu_sections and achievements for verification
print('sample menu_sections:', data.get('menu_sections')[:5])
print('sample achievements:', data.get('achievements')[:5])
