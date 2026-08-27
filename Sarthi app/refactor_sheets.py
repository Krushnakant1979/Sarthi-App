import re

def process_file(filepath, methods, is_map_home=False):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add measure_size import
    if "import '../../../core/utils/measure_size.dart';" not in content:
        content = content.replace("import 'package:flutter_riverpod/flutter_riverpod.dart';", 
                                  "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../../core/utils/measure_size.dart';")

    # 2. Fix build callers
    if is_map_home:
        # map_home_screen.dart callers
        content = re.sub(r'_buildSearchingContent\(context, ref, rideId, scrollController\)', r'_buildSearchingContent(context, ref, rideId)', content)
        content = re.sub(r'_buildCaptainFoundContent\(\s*context, otp, fare, displayState, scrollController\)', r'_buildCaptainFoundContent(context, otp, fare, displayState)', content)
        content = re.sub(r'_buildInProgressContent\(context, scrollController\)', r'_buildInProgressContent(context)', content)
        content = re.sub(r'_buildCompletedContent\(\s*context, ref, fare, scrollController\)', r'_buildCompletedContent(context, ref, fare)', content)
        content = re.sub(r'_buildSelectedContent\(\s*context, ref, scrollController\)', r'_buildSelectedContent(context, ref)', content)
        content = re.sub(r'_buildDefaultContent\(context, ref, scrollController\)', r'_buildDefaultContent(context, ref)', content)
    else:
        # captain_map_screen.dart callers
        content = re.sub(r'_buildActiveRideSheet\(\s*context, ref, scrollController, activeRide,?\s*\)', r'_buildActiveRideSheet(context, ref, activeRide)', content)
        content = re.sub(r'_buildOfflineSheet\(scrollController\)', r'_buildOfflineSheet()', content)
        content = re.sub(r'_buildSearchingSheet\(scrollController\)', r'_buildSearchingSheet()', content)
        content = re.sub(r'_buildIncomingRequestSheet\(\s*context,\s*ref,\s*scrollController,\s*nearbyRequests\.first,?\s*\)', r'_buildIncomingRequestSheet(context, ref, nearbyRequests.first)', content)
        content = re.sub(r'_buildIncomingRequestSheet\(\s*context,\s*ref,\s*_sheetScrollController,\s*activeRequest,?\s*\)', r'_buildIncomingRequestSheet(context, ref, activeRequest)', content)
        content = re.sub(r'_buildActiveRideSheet\(\s*context,\s*ref,\s*_sheetScrollController,\s*activeRide,?\s*\)', r'_buildActiveRideSheet(context, ref, activeRide)', content)
        content = re.sub(r'_buildOfflineSheet\(_sheetScrollController\)', r'_buildOfflineSheet()', content)
        content = re.sub(r'_buildSearchingSheet\(context, ref, _sheetScrollController\)', r'_buildSearchingSheet(context, ref)', content)

    # 3. Replace AnimatedSwitcher wrapper
    if is_map_home:
        # map_home_screen.dart wrapper
        old_wrapper_regex = r'child:\s*SizedBox\(\s*key:\s*ValueKey\(displayState\),\s*width:\s*double\.infinity,\s*child:\s*stateContent,\s*\)'
        new_wrapper = '''child: KeyedSubtree(
                                key: ValueKey(displayState),
                                child: SingleChildScrollView(
                                  controller: scrollController,
                                  physics: const ClampingScrollPhysics(),
                                  child: MeasureSize(
                                    onChange: (size) {
                                      if (_sheetController.isAttached) {
                                        final screenHeight = MediaQuery.of(context).size.height;
                                        final targetFraction = ((size.height + 24) / screenHeight).clamp(0.15, 0.95);
                                        _sheetController.jumpTo(targetFraction);
                                      }
                                    },
                                    child: stateContent,
                                  ),
                                ),
                              )'''
        content = re.sub(old_wrapper_regex, new_wrapper, content)
        # reduce duration
        content = re.sub(r'duration: const Duration\(milliseconds: 300\),', r'duration: const Duration(milliseconds: 100),', content)
    else:
        # captain_map_screen.dart wrapper
        old_wrapper_regex = r'child:\s*KeyedSubtree\(\s*key:\s*ValueKey\(stateKey\),\s*child:\s*sheetContent,\s*\)'
        new_wrapper = '''child: KeyedSubtree(
                        key: ValueKey(stateKey),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          child: MeasureSize(
                            onChange: (size) {
                              if (_sheetController.isAttached) {
                                final screenHeight = MediaQuery.of(context).size.height;
                                final targetFraction = ((size.height + 24) / screenHeight).clamp(0.15, 0.95);
                                _sheetController.jumpTo(targetFraction);
                              }
                            },
                            child: sheetContent,
                          ),
                        ),
                      )'''
        content = re.sub(old_wrapper_regex, new_wrapper, content)
        # reduce duration
        content = re.sub(r'duration: const Duration\(milliseconds: 280\),', r'duration: const Duration(milliseconds: 100),', content)


    # 4. Refactor methods
    for method in methods:
        # Match signature and ListView setup up to `children: [`
        sig_regex = r'(Widget\s+' + method + r'\s*\([^)]*?)(?:,\s*)?(?:ScrollController\s+[a-zA-Z0-9_]+)(?:,\s*)?([^)]*\)\s*\{)'
        
        def replacer(m):
            args1 = m.group(1).strip()
            args2 = m.group(2).strip()
            if args1.endswith('(') and args2.startswith(')'):
                return args1 + args2
            if args1.endswith('('):
                return args1 + args2
            if args2.startswith(')'):
                return args1 + args2
            return args1 + ', ' + args2

        content = re.sub(sig_regex, replacer, content, count=1)

        # Now replace ListView with Padding
        method_idx = content.find(f'Widget {method}')
        if method_idx == -1:
            print(f"Could not find method {method}")
            continue

        listview_start_idx = content.find('return ListView(', method_idx)
        if listview_start_idx == -1:
            print(f"Could not find return ListView in {method}")
            continue

        children_idx = content.find('children: [', listview_start_idx)
        
        listview_block = content[listview_start_idx:children_idx + len('children: [')]
        
        # Extract padding if exists (now correctly grabs up to closing parenthesis)
        padding_match = re.search(r'padding:\s*(const\s*EdgeInsets\.[^\)]+\)),', listview_block)
        padding_str = padding_match.group(1) if padding_match else "const EdgeInsets.only(bottom: 24)"

        new_block = f'''return Padding(
      padding: {padding_str},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        
        content = content[:listview_start_idx] + new_block + content[children_idx + len('children: ['):]

        # Fix closing bracket
        next_method_idx = content.find('  Widget _build', listview_start_idx + 100)
        if next_method_idx == -1:
            next_method_idx = len(content)

        method_body = content[listview_start_idx:next_method_idx]
        
        old_closing_regex = r'\s*\],\s*\n\s*\);\s*\n\s*\}'
        
        matches = list(re.finditer(old_closing_regex, method_body))
        if matches:
            last_match = matches[-1]
            method_body = method_body[:last_match.start()] + '''
        ],
      ),
    );
  }''' + method_body[last_match.end():]
            
            content = content[:listview_start_idx] + method_body + content[next_method_idx:]
        else:
            print(f"Could not find closing bracket for {method}")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Processing map_home_screen.dart...")
process_file(
    'lib/features/map/presentation/map_home_screen.dart',
    ['_buildDefaultContent', '_buildSelectedContent', '_buildSearchingContent', '_buildCaptainFoundContent', '_buildInProgressContent', '_buildCompletedContent'],
    is_map_home=True
)

print("Processing captain_map_screen.dart...")
process_file(
    'lib/features/captain/presentation/captain_map_screen.dart',
    ['_buildOfflineSheet', '_buildSearchingSheet', '_buildIncomingRequestSheet', '_buildActiveRideSheet'],
    is_map_home=False
)
print("Done!")
