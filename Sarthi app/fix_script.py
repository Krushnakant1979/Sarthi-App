import os

def fix_map_home_screen():
    path = 'lib/features/map/presentation/map_home_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add import
    content = content.replace(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../../core/utils/measure_size.dart';"
    )

    # 2. Update AnimatedSwitcher duration and child
    old_switcher = '''                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                FadeTransition(opacity: animation, child: child),
                              layoutBuilder: (currentChild, previousChildren) => Stack(
                                alignment: Alignment.topCenter,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              ),
                              child: SizedBox(
                                key: ValueKey(displayState),
                                width: double.infinity,
                                child: stateContent,
                              ),
                            );'''
    new_switcher = '''                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 100),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                FadeTransition(opacity: animation, child: child),
                              layoutBuilder: (currentChild, previousChildren) => Stack(
                                alignment: Alignment.topCenter,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              ),
                              child: KeyedSubtree(
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
                              ),
                            );'''
    content = content.replace(old_switcher, new_switcher)

    # 3. Update all builder calls
    content = content.replace(
        '''                            if (displayState == 'searching') {
                              stateContent = _buildSearchingContent(
                                context, ref, rideId, scrollController);
                            } else if (displayState == 'accepted' ||
                                displayState == 'arriving' ||
                                displayState == 'arrived') {
                              stateContent = _buildCaptainFoundContent(
                                context, otp, fare, displayState, scrollController);
                            } else if (displayState == 'in_progress') {
                              stateContent = _buildInProgressContent(context, scrollController);
                            } else if (displayState == 'completed') {
                              stateContent = _buildCompletedContent(
                                context, ref, fare, scrollController);
                            } else if (displayState == 'selected' &&
                                _destination != null) {
                              stateContent = _buildSelectedContent(
                                context, ref, scrollController);
                            } else {
                              stateContent = _buildDefaultContent(context, ref, scrollController);
                            }''',
        '''                            if (displayState == 'searching') {
                              stateContent = _buildSearchingContent(context, ref, rideId);
                            } else if (displayState == 'accepted' ||
                                displayState == 'arriving' ||
                                displayState == 'arrived') {
                              stateContent = _buildCaptainFoundContent(context, otp, fare, displayState);
                            } else if (displayState == 'in_progress') {
                              stateContent = _buildInProgressContent(context);
                            } else if (displayState == 'completed') {
                              stateContent = _buildCompletedContent(context, ref, fare);
                            } else if (displayState == 'selected' &&
                                _destination != null) {
                              stateContent = _buildSelectedContent(context, ref);
                            } else {
                              stateContent = _buildDefaultContent(context, ref);
                            }'''
    )

    # 4. Replace ListView with Padding > Column in all methods, and fix signatures
    replacements = [
        # _buildDefaultContent
        (
            '''  Widget _buildDefaultContent(BuildContext context, WidgetRef ref, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 24),
      children: [''',
            '''  Widget _buildDefaultContent(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        ),
        # _buildSelectedContent
        (
            '''  Widget _buildSelectedContent(BuildContext context, WidgetRef ref, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [''',
            '''  Widget _buildSelectedContent(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        ),
        # _buildSearchingContent
        (
            '''  Widget _buildSearchingContent(BuildContext context, WidgetRef ref, String? rideId, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [''',
            '''  Widget _buildSearchingContent(BuildContext context, WidgetRef ref, String? rideId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        ),
        # _buildCaptainFoundContent
        (
            '''  Widget _buildCaptainFoundContent(BuildContext context, dynamic otp, dynamic fare, String status, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [''',
            '''  Widget _buildCaptainFoundContent(BuildContext context, dynamic otp, dynamic fare, String status) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        ),
        # _buildInProgressContent
        (
            '''  Widget _buildInProgressContent(BuildContext context, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [''',
            '''  Widget _buildInProgressContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        ),
        # _buildCompletedContent
        (
            '''  Widget _buildCompletedContent(BuildContext context, WidgetRef ref, dynamic fare, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [''',
            '''  Widget _buildCompletedContent(BuildContext context, WidgetRef ref, dynamic fare) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        )
    ]

    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
        
    # 5. Fix closing brackets!
    # Because each of these 6 methods now uses Padding > Column instead of ListView,
    # we need to replace their ending `      ],\n    );\n  }` with `        ],\n      ),\n    );\n  }`
    
    methods = ['_buildDefaultContent', '_buildSelectedContent', '_buildSearchingContent', '_buildCaptainFoundContent', '_buildInProgressContent', '_buildCompletedContent']
    
    for method in methods:
        start_idx = content.find(f'  Widget {method}')
        if start_idx == -1: continue
        
        # find the end of this method (look for next `  Widget _build` or end of class)
        next_method = content.find('  Widget _build', start_idx + 20)
        if next_method == -1: next_method = len(content)
        
        # We need to find the last occurrence of `      ],\n    );\n  }` within this slice
        method_body = content[start_idx:next_method]
        
        # Replace the final return closing
        old_close1 = '      ],\n    );\n  }\n\n'
        old_close2 = '      ],\n    );\n  }\n'
        old_close3 = '      ],\n    );\n  }'
        
        new_close = '        ],\n      ),\n    );\n  }'
        
        if method_body.endswith(old_close1):
            method_body = method_body[:-len(old_close1)] + new_close + '\n\n'
        elif method_body.endswith(old_close2):
            method_body = method_body[:-len(old_close2)] + new_close + '\n'
        elif method_body.endswith(old_close3):
            method_body = method_body[:-len(old_close3)] + new_close
            
        content = content[:start_idx] + method_body + content[next_method:]

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)


def fix_captain_map_screen():
    path = 'lib/features/captain/presentation/captain_map_screen.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Add import
    content = content.replace(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../../core/utils/measure_size.dart';"
    )

    # 2. Update AnimatedSwitcher duration and child
    old_switcher = '''                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      child: SizedBox(
                        key: ValueKey(bottomSheetState),
                        width: double.infinity,
                        child: sheetContent,
                      ),
                    );'''
    new_switcher = '''                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 100),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(bottomSheetState),
                        child: SingleChildScrollView(
                          controller: _sheetScrollController,
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
                      ),
                    );'''
    content = content.replace(old_switcher, new_switcher)

    # 3. Update all builder calls
    content = content.replace(
        '''                    if (bottomSheetState == 'offline') {
                      sheetContent = _buildOfflineSheet(context, _sheetScrollController);
                    } else if (bottomSheetState == 'searching') {
                      sheetContent = _buildSearchingSheet(context, ref, _sheetScrollController);
                    } else if (bottomSheetState == 'incoming_request' && activeRequest != null) {
                      sheetContent = _buildIncomingRequestSheet(context, ref, _sheetScrollController, activeRequest);
                    } else if (bottomSheetState == 'active_ride' && activeRide != null) {
                      sheetContent = _buildActiveRideSheet(context, ref, _sheetScrollController, activeRide);
                    }''',
        '''                    if (bottomSheetState == 'offline') {
                      sheetContent = _buildOfflineSheet(context);
                    } else if (bottomSheetState == 'searching') {
                      sheetContent = _buildSearchingSheet(context, ref);
                    } else if (bottomSheetState == 'incoming_request' && activeRequest != null) {
                      sheetContent = _buildIncomingRequestSheet(context, ref, activeRequest);
                    } else if (bottomSheetState == 'active_ride' && activeRide != null) {
                      sheetContent = _buildActiveRideSheet(context, ref, activeRide);
                    }'''
    )

    # 4. Replace ListView with Padding > Column in all methods, and fix signatures
    replacements = [
        # _buildOfflineSheet
        (
            '''  Widget _buildOfflineSheet(BuildContext context, ScrollController controller) {
    return ListView(
      controller: controller,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [''',
            '''  Widget _buildOfflineSheet(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        ),
        # _buildSearchingSheet
        (
            '''  Widget _buildSearchingSheet(BuildContext context, WidgetRef ref, ScrollController controller) {
    return ListView(
      controller: controller,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [''',
            '''  Widget _buildSearchingSheet(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        ),
        # _buildIncomingRequestSheet
        (
            '''  Widget _buildIncomingRequestSheet(
    BuildContext context,
    WidgetRef ref,
    ScrollController controller,
    Map<String, dynamic> request,
  ) {
    return ListView(
      controller: controller,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [''',
            '''  Widget _buildIncomingRequestSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        ),
        # _buildActiveRideSheet
        (
            '''  Widget _buildActiveRideSheet(
    BuildContext context,
    WidgetRef ref,
    ScrollController controller,
    Map<String, dynamic> activeRide,
  ) {
    final status = activeRide['status'] as String;
    final rider = activeRide['rider'] as Map?;
    final dest = activeRide['destinationName']?.toString() ?? 'Destination';
    
    final isHeadingToPickup = status == 'accepted' || status == 'arriving';
    final pickup = activeRide['pickup'] as Map?;
    final targetAddress = isHeadingToPickup
        ? (pickup == null
            ? 'User pickup location'
            : pickup['address']?.toString() ?? 'User pickup location')
        : dest;
    final etaMinutes = _navigationDurationSeconds == null
        ? null
        : (_navigationDurationSeconds! / 60).ceil();
    final navigationKm = _navigationDistanceMeters == null
        ? null
        : (_navigationDistanceMeters! / 1000).toStringAsFixed(1);

    return ListView(
      controller: controller,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [''',
            '''  Widget _buildActiveRideSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> activeRide,
  ) {
    final status = activeRide['status'] as String;
    final rider = activeRide['rider'] as Map?;
    final dest = activeRide['destinationName']?.toString() ?? 'Destination';
    
    final isHeadingToPickup = status == 'accepted' || status == 'arriving';
    final pickup = activeRide['pickup'] as Map?;
    final targetAddress = isHeadingToPickup
        ? (pickup == null
            ? 'User pickup location'
            : pickup['address']?.toString() ?? 'User pickup location')
        : dest;
    final etaMinutes = _navigationDurationSeconds == null
        ? null
        : (_navigationDurationSeconds! / 60).ceil();
    final navigationKm = _navigationDistanceMeters == null
        ? null
        : (_navigationDistanceMeters! / 1000).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: ['''
        )
    ]

    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
        
    # 5. Fix closing brackets!
    methods = ['_buildOfflineSheet', '_buildSearchingSheet', '_buildIncomingRequestSheet', '_buildActiveRideSheet']
    
    for method in methods:
        start_idx = content.find(f'  Widget {method}')
        if start_idx == -1: continue
        
        # find the end of this method (look for next `  Widget _build` or end of class)
        next_method = content.find('  Widget _build', start_idx + 20)
        if next_method == -1: next_method = len(content)
        
        # We need to find the last occurrence of `      ],\n    );\n  }` within this slice
        method_body = content[start_idx:next_method]
        
        # Replace the final return closing
        old_close1 = '      ],\n    );\n  }\n\n'
        old_close2 = '      ],\n    );\n  }\n'
        old_close3 = '      ],\n    );\n  }'
        
        new_close = '        ],\n      ),\n    );\n  }'
        
        if method_body.endswith(old_close1):
            method_body = method_body[:-len(old_close1)] + new_close + '\n\n'
        elif method_body.endswith(old_close2):
            method_body = method_body[:-len(old_close2)] + new_close + '\n'
        elif method_body.endswith(old_close3):
            method_body = method_body[:-len(old_close3)] + new_close
            
        content = content[:start_idx] + method_body + content[next_method:]

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

fix_map_home_screen()
fix_captain_map_screen()
