import sys

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fix character encodings
    content = content.replace('â‚¹', '?')
    content = content.replace('â€¢', '�')
    content = content.replace('â€�', '�')
    content = content.replace('â� €', '-')
    content = content.replace('•', '�')
    content = content.replace('₹', '?')
    
    # Fix price color to be black
    content = content.replace(
        "Text('?" + "$" + "amount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary)),",
        "Text('?" + "$" + "amount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print('Done replacing.')

fix_file(r'e:\Krushna\rapido_app\lib\features\map\presentation\map_home_screen.dart')
