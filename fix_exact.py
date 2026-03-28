import os

filepath = r'lib\views\statistics\statistics_screen.dart'
with open(filepath, 'rb') as f:
    raw = f.read()

# Try to decode
try:
    decoded = raw.decode('gbk')
    print('Was GBK')
except:
    decoded = raw.decode('utf-8')
    print('Was UTF-8')

# Rewrite clean UTF-8
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(decoded)
print('Fixed encoding for statistics_screen.dart')

# Do the same for all dart files just in case
for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fp = os.path.join(root, file)
            with open(fp, 'rb') as f:
                r = f.read()
            try:
                dec = r.decode('gbk')
            except:
                dec = r.decode('utf-8')
            with open(fp, 'w', encoding='utf-8') as f:
                f.write(dec)

