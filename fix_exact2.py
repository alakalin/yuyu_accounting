import os

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fp = os.path.join(root, file)
            with open(fp, 'rb') as f:
                raw = f.read()
            
            try:
                # If it can be interpreted as GBK but not UTF-8, then it's messy.
                # Actually, check if it's valid UTF-8 first:
                try:
                    dec = raw.decode('utf-8')
                    # Already valid UTF-8
                except UnicodeDecodeError:
                    dec = raw.decode('gbk')
                    print(f"Converted GBK to UTF-8: {fp}")
            except Exception as e:
                print(f"Error on {fp}: {e}")
                continue
                
            # Write back as UTF-8 (no BOM)
            with open(fp, 'w', encoding='utf-8') as f:
                f.write(dec)
            
print("All files processed.")
