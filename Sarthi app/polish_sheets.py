import re

def polish_map_home():
    filepath = 'lib/features/map/presentation/map_home_screen.dart'
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update ValueNotifier
    content = content.replace("ValueNotifier<double> _sheetExtent = ValueNotifier(0.32);", "ValueNotifier<double> _sheetExtent = ValueNotifier(0.45);")
    
    # 2. Update jumpTo to animateTo
    old_jump = r'_sheetController\.jumpTo\(targetFraction\);'
    new_jump = '_sheetController.animateTo(targetFraction, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);'
    content = re.sub(old_jump, new_jump, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def polish_captain_map():
    filepath = 'lib/features/captain/presentation/captain_map_screen.dart'
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update ValueNotifier
    content = content.replace("ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0.35);", "ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0.45);")
    
    # 2. Update jumpTo to animateTo
    old_jump = r'_sheetController\.jumpTo\(targetFraction\);'
    new_jump = '_sheetController.animateTo(targetFraction, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);'
    content = re.sub(old_jump, new_jump, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    polish_map_home()
    polish_captain_map()
    print("Polish applied")
