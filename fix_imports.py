import glob
import os

files = glob.glob(r'e:\Club Connect Flutter\lib\src\screens\*.dart') + glob.glob(r'e:\Club Connect Flutter\lib\src\widgets\*.dart')

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    if 'AppTheme' in content and 'theme/app_theme.dart' not in content:
        content = "import 'package:club_connect_flutter/src/theme/app_theme.dart';\n" + content
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print('Fixed import in ' + os.path.basename(f))
