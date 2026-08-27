import re

filepath = 'lib/features/rides/presentation/ride_history_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the NestedScrollView with CustomScrollView
old_scroll_code = r'''      body: NestedScrollView\(
        headerSliverBuilder: \(context, innerBoxIsScrolled\) \{
          return \[
(.*?)
          \];
        \},
        body: NotificationListener<ScrollNotification>\(
          onNotification: \(ScrollNotification scrollInfo\) \{
            if \(scrollInfo\.metrics\.pixels >=
                scrollInfo\.metrics\.maxScrollExtent - 200\) \{
              Future\.microtask\(\(\) \{
                ref\.read\(paginatedRideHistoryProvider\.notifier\)\.loadMore\(\);
              \}\);
            \}
            return false;
          \},
          child: Builder\(
              builder: \(context\) \{
                if \(historyState\.rides\.isEmpty\) \{
                  if \(historyState\.isLoading\) \{
                    return const Center\(child: CircularProgressIndicator\(\)\);
                  \}
                  if \(historyState\.error != null\) \{
                    return Center\(
                      child: Column\(
                        mainAxisSize: MainAxisSize\.min,
                        children: \[
                          const Icon\(Icons\.error_outline, color: AppColors\.error, size: 48\),
                          const SizedBox\(height: 12\),
                          Text\(
                            'Could not load rides:\\n\$\{historyState\.error\}',
                            textAlign: TextAlign\.center,
                            style: const TextStyle\(color: Color\(0xFF6B7280\)\),
                          \),
                          const SizedBox\(height: 16\),
                          ElevatedButton\(
                            onPressed: \(\) => ref\.read\(paginatedRideHistoryProvider\.notifier\)\.refresh\(\),
                            child: const Text\('Retry'\),
                          \)
                        \],
                      \),
                    \);
                  \}
                  return _buildEmpty\(context\);
                \}

                if \(displayedRides\.isEmpty\) \{
                  return _buildEmpty\(context\);
                \}

                return ListView\.builder\(
                  padding: const EdgeInsets\.fromLTRB\(16, 16, 16, 96\),
                  itemCount: displayedRides\.length \+ \(historyState\.hasMore \? 1 : 0\),
                  itemBuilder: \(context, index\) \{
                    if \(index == displayedRides\.length\) \{
                      return const Padding\(
                        padding: EdgeInsets\.symmetric\(vertical: 24\),
                        child: Center\(child: CircularProgressIndicator\(\)\),
                      \);
                    \}
                    return _RideCard\(ride: displayedRides\[index\]\);
                  \},
                \);
              \},
            \),
        \),
      \),'''

new_scroll_code = '''      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 200) {
            Future.microtask(() {
              ref.read(paginatedRideHistoryProvider.notifier).loadMore();
            });
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
\\1
            Builder(
              builder: (context) {
                if (historyState.rides.isEmpty) {
                  if (historyState.isLoading) {
                    return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                  }
                  if (historyState.error != null) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load rides:\\n${historyState.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.read(paginatedRideHistoryProvider.notifier).refresh(),
                              child: const Text('Retry'),
                            )
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverFillRemaining(child: _buildEmpty(context));
                }

                if (displayedRides.isEmpty) {
                  return SliverFillRemaining(child: _buildEmpty(context));
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == displayedRides.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _RideCard(ride: displayedRides[index]);
                      },
                      childCount: displayedRides.length + (historyState.hasMore ? 1 : 0),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),'''

content = re.sub(old_scroll_code, new_scroll_code, content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied CustomScrollView refactor!")
