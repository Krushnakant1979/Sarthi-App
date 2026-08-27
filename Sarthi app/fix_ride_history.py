import re

def process_ride_history(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove _scrollController
    content = re.sub(r'  final _scrollController = ScrollController\(\);\n\n  @override\n  void initState\(\) \{\n    super\.initState\(\);\n    _scrollController\.addListener\(_onScroll\);\n  \}\n\n  @override\n  void dispose\(\) \{\n    _scrollController\.dispose\(\);\n    super\.dispose\(\);\n  \}\n\n  void _onScroll\(\) \{\n    if \(_scrollController\.position\.pixels >=\n        _scrollController\.position\.maxScrollExtent - 200\) \{\n      ref\.read\(paginatedRideHistoryProvider\.notifier\)\.loadMore\(\);\n    \}\n  \}\n', '', content)

    # 2. Add NotificationListener
    build_start = content.find('  Widget build(BuildContext context) {')
    
    old_scaffold_regex = r'    return Scaffold\(\n      backgroundColor: AppColors\.backgroundLight,\n      appBar: AppBar\([\s\S]*?body: Column\(\n        children: \[\n          // Date Filter Row\n          Container\('
    
    # We will replace from `return Scaffold(` down to the start of `Expanded(`
    
    content = re.sub(r'controller: _scrollController,', '', content)
    
    # We will use Python scripting to make this safer
    return content

print("Use multi replace tool instead for safer targeted replacement")
