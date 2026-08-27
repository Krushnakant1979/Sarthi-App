import re

filepath = 'pubspec.yaml'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

if 'assets/images/' not in content:
    content = re.sub(r'  assets:\n    - \.env\n', r'  assets:\n    - .env\n    - assets/images/\n', content)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Added assets/images/ to pubspec.yaml")
else:
    print("assets/images/ already in pubspec.yaml")
