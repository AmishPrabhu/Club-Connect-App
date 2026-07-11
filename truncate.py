import sys
path = 'e:/Club Connect Flutter/lib/src/screens/dashboard_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

end_index = -1
for i, line in enumerate(lines):
    if 'String _stripMarkdown(String markdown)' in line:
        end_index = i
        break

if end_index != -1:
    # Find the closing brace of _stripMarkdown
    # it's about 10 lines down
    for i in range(end_index, len(lines)):
        if 'return text.trim();' in lines[i]:
            final_index = i + 1
            break
    else:
        final_index = len(lines)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines[:final_index + 1])
    print('Truncated successfully')
else:
    print('Not found')
