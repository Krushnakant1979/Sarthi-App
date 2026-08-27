import re

def fix_map_home():
    filepath = 'lib/features/map/presentation/map_home_screen.dart'
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add _isNavVisible state
    if "bool _isNavVisible = true;" not in content:
        content = content.replace("  int _selectedNavIndex = 0;\n", "  int _selectedNavIndex = 0;\n  bool _isNavVisible = true;\n")

    # 2. Add NotificationListener to Stack
    old_body = r'      body: Stack\(\n        children: \[\n          IndexedStack\('
    new_body = r'''      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.forward) {
            if (!_isNavVisible) setState(() => _isNavVisible = true);
          } else if (notification.direction == ScrollDirection.reverse) {
            if (_isNavVisible) setState(() => _isNavVisible = false);
          }
          return false;
        },
        child: Stack(
          children: [
            IndexedStack('''
    content = re.sub(old_body, new_body, content)
    
    # 3. Add closing bracket for NotificationListener
    # We find the end of Stack (it's right before `    );` and `  }` of build method)
    # The build method ends like this:
    #         ],
    #       ),
    #     );
    #   }
    
    # Let's use a safer approach for closing bracket:
    # Actually, we can just replace the bottom positioning
    old_bottom = r'''          if \(_selectedNavIndex != 0 \|\| _destination == null\)\n            Positioned\(\n              bottom: 32,\n              left: 24,\n              right: 24,\n              child: _buildFloatingNavBar\(\),\n            \),\n        \],\n      \),\n    \);'''
    new_bottom = '''          if (_selectedNavIndex != 0 || _destination == null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: _isNavVisible ? 32 : -100,
              left: 24,
              right: 24,
              child: _buildFloatingNavBar(),
            ),
        ],
      ),
      ),
    );'''
    content = re.sub(old_bottom, new_bottom, content)

    # 4. We need to add ScrollDirection import if it's missing
    if "import 'package:flutter/rendering.dart';" not in content:
        content = "import 'package:flutter/rendering.dart';\n" + content

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)


def fix_ride_history():
    filepath = 'lib/features/rides/presentation/ride_history_screen.dart'
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Remove _scrollController entirely
    content = re.sub(r'  final _scrollController = ScrollController\(\);\n\n  @override\n  void initState\(\) \{\n    super\.initState\(\);\n    _scrollController\.addListener\(_onScroll\);\n  \}\n\n  @override\n  void dispose\(\) \{\n    _scrollController\.dispose\(\);\n    super\.dispose\(\);\n  \}\n\n  void _onScroll\(\) \{\n    if \(_scrollController\.position\.pixels >=\n        _scrollController\.position\.maxScrollExtent - 200\) \{\n      ref\.read\(paginatedRideHistoryProvider\.notifier\)\.loadMore\(\);\n    \}\n  \}\n', '', content)
    
    # Replace body with NestedScrollView
    old_scaffold = r'''    return Scaffold\(
      backgroundColor: AppColors\.backgroundLight,
      appBar: AppBar\(
        centerTitle: true,
        backgroundColor: AppColors\.rapidoYellow,
        foregroundColor: AppColors\.primary,
        leading: IconButton\(
          icon: const Icon\(Icons\.arrow_back_ios_new_rounded, size: 20\),
          onPressed: \(\) \{
            if \(Navigator\.canPop\(context\)\) \{
              Navigator\.pop\(context\);
            \} else if \(widget\.onBack != null\) \{
              widget\.onBack!\(\);
            \}
          \},
        \),
        title: const Text\(
          'Ride History',
          style: TextStyle\(fontWeight: FontWeight\.w700\),
        \),
        elevation: 0,
      \),
      body: Column\(
        children: \[
          // Date Filter Row
          Container\(
            color: Colors\.white,
            padding: const EdgeInsets\.fromLTRB\(16, 12, 16, 0\),
            child: Row\('''
            
    new_scaffold = '''    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              centerTitle: true,
              backgroundColor: AppColors.rapidoYellow,
              foregroundColor: AppColors.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else if (widget.onBack != null) {
                    widget.onBack!();
                  }
                },
              ),
              title: const Text(
                'Ride History',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(101),
                child: Column(
                  children: [
                    // Date Filter Row
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row('''
                      
    content = re.sub(old_scaffold, new_scaffold, content)

    # Now replace the transition from filters to list
    old_transition = r'''          const Divider\(height: 1, color: AppColors\.divider\),
          // List View
          Expanded\(
            child: Builder\('''
            
    new_transition = '''                    const Divider(height: 1, color: AppColors.divider),
                  ],
                ),
              ),
            ),
          ];
        },
        body: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
              ref.read(paginatedRideHistoryProvider.notifier).loadMore();
            }
            return false;
          },
          child: Builder('''
    content = re.sub(old_transition, new_transition, content)
    
    # Remove controller from ListView.builder
    content = re.sub(r'                  controller: _scrollController,\n', '', content)
    
    # Fix the closing brackets for the Builder. We replaced `Expanded(` with `NotificationListener(...`
    # We need to remove the closing brackets for the Column, which were `        ],\n      ),\n    );`
    # The end of build method was:
    #                 );
    #               },
    #             ),
    #           ),
    #         ],
    #       ),
    #     );
    #   }
    
    old_end = r'''                \);\n              \},\n            \),\n          \),\n        \],\n      \),\n    \);'''
    new_end = r'''                );
              },
            ),
        ),
      ),
    );'''
    content = re.sub(old_end, new_end, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    fix_map_home()
    fix_ride_history()
    print("Done")
