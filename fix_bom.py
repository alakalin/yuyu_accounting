import os

def remove_bom_and_check(filepath):
    with open(filepath, 'rb') as f:
        raw = f.read()
    
    # Check for UTF-8 BOM
    if raw.startswith(b'\xef\xbb\xbf'):
        raw = raw[3:]
        print(f"Removed BOM from {filepath}")
        
    try:
        dec = raw.decode('utf-8')
    except UnicodeDecodeError:
        dec = raw.decode('gbk')
        print(f"Converted strictly GBK -> UTF-8: {filepath}")
        
    with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
        f.write(dec)

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            remove_bom_and_check(os.path.join(root, file))
