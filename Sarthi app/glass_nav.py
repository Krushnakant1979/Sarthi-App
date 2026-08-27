import re

filepath = 'lib/features/map/presentation/map_home_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import 'dart:ui' if not present
if "import 'dart:ui';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:ui';")

# Replace _buildFloatingNavBar
old_nav = r'''  Widget _buildFloatingNavBar\(\) \{
    return Container\(
      padding: const EdgeInsets\.all\(3\),
      decoration: BoxDecoration\(
        color: Colors\.white,
        borderRadius: BorderRadius\.circular\(40\),
        boxShadow: \[
          BoxShadow\(color: Colors\.black\.withValues\(alpha: 0\.05\), blurRadius: 20, offset: const Offset\(0, 10\)\)
        \],
        border: Border\.all\(color: Colors\.black\.withValues\(alpha: 0\.05\)\),
      \),
      child: Row\('''

new_nav = '''  Widget _buildFloatingNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row('''

content = re.sub(old_nav, new_nav, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated map_home_screen nav bar with glassmorphism.")
