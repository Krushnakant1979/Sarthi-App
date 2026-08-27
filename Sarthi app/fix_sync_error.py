import re

def fix_map_home():
    filepath = 'lib/features/map/presentation/map_home_screen.dart'
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the NotificationListener and wrap setState in Future.microtask
    old_listener = r'''        onNotification: \(notification\) \{
          if \(notification\.direction == ScrollDirection\.forward\) \{
            if \(!_isNavVisible\) setState\(\(\) => _isNavVisible = true\);
          \} else if \(notification\.direction == ScrollDirection\.reverse\) \{
            if \(_isNavVisible\) setState\(\(\) => _isNavVisible = false\);
          \}
          return false;
        \},'''
        
    new_listener = '''        onNotification: (notification) {
          if (notification.direction == ScrollDirection.forward) {
            if (!_isNavVisible) {
              Future.microtask(() {
                if (mounted) setState(() => _isNavVisible = true);
              });
            }
          } else if (notification.direction == ScrollDirection.reverse) {
            if (_isNavVisible) {
              Future.microtask(() {
                if (mounted) setState(() => _isNavVisible = false);
              });
            }
          }
          return false;
        },'''
        
    content = re.sub(old_listener, new_listener, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_ride_history():
    filepath = 'lib/features/rides/presentation/ride_history_screen.dart'
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    old_listener = r'''          onNotification: \(ScrollNotification scrollInfo\) \{
            if \(scrollInfo\.metrics\.pixels >=
                scrollInfo\.metrics\.maxScrollExtent - 200\) \{
              ref\.read\(paginatedRideHistoryProvider\.notifier\)\.loadMore\(\);
            \}
            return false;
          \},'''
          
    new_listener = '''          onNotification: (ScrollNotification scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
              Future.microtask(() {
                ref.read(paginatedRideHistoryProvider.notifier).loadMore();
              });
            }
            return false;
          },'''
          
    content = re.sub(old_listener, new_listener, content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    fix_map_home()
    fix_ride_history()
    print("Fixed synchronous state updates")
