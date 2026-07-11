import re

files = [
    r"e:\Club Connect Flutter\lib\src\screens\dashboard_screen.dart",
    r"e:\Club Connect Flutter\lib\src\screens\user_dashboard_screen.dart"
]

for file_path in files:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    old_len = len(content)

    # 1. Container backgrounds
    content = re.sub(r'color:\s*Colors\.white,(\s*borderRadius)', r'color: Theme.of(context).cardColor,\1', content)
    content = re.sub(r'color:\s*Colors\.white,(\s*boxShadow)', r'color: Theme.of(context).cardColor,\1', content)
    content = re.sub(r'fillColor:\s*Colors\.white,', r'fillColor: Theme.of(context).cardColor,', content)
    
    # 2. Text colors
    # Be careful not to replace text on colored buttons. But looking at the code, they use white text on colored buttons. 
    # If they use black text somewhere, it's usually on a white background.
    content = re.sub(r'color:\s*Colors\.black(,|(?=\)))', r'color: AppTheme.textColor(context)\1', content)
    
    # 3. Grey backgrounds 
    content = re.sub(r'color:\s*Colors\.grey\.shade100,', r'color: AppTheme.surfaceBg(context),', content)
    
    print(f"File {file_path}: length changed from {old_len} to {len(content)}")

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
