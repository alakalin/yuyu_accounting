import os

def convert_to_utf8(filepath):
    # Try reading as utf-8 first
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        # If it succeeds, rewrite just in case, but usually not needed
    except UnicodeDecodeError:
        # If it fails, read as gbk
        try:
            with open(filepath, 'r', encoding='gbk') as f:
                content = f.read()
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f'Converted {filepath} from gbk to utf-8')
        except Exception as e:
            print(f'Failed to convert {filepath}: {e}')

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            convert_to_utf8(os.path.join(root, file))
