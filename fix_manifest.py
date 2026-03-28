import re

filepath = 'android/app/src/main/AndroidManifest.xml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the broken string
content = re.sub(r'android:label=".*?"', 'android:label="yuyu_记账"', content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed Manifest via Python')
