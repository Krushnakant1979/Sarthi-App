import re

filepath = 'lib/features/map/presentation/map_home_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Fix Glassmorphism Nav Bar Structure
old_nav = r'''  Widget _buildFloatingNavBar\(\) \{
    return ClipRRect\(
      borderRadius: BorderRadius\.circular\(40\),
      child: BackdropFilter\(
        filter: ImageFilter\.blur\(sigmaX: 12, sigmaY: 12\),
        child: Container\(
          padding: const EdgeInsets\.all\(3\),
          decoration: BoxDecoration\(
            color: Colors\.white\.withValues\(alpha: 0\.75\),
            borderRadius: BorderRadius\.circular\(40\),
            border: Border\.all\(color: Colors\.white\.withValues\(alpha: 0\.2\)\),
          \),
          child: Row\('''

new_nav = '''  Widget _buildFloatingNavBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Row('''

content = re.sub(old_nav, new_nav, content)

# 2. Fix 3D Icons
old_services = r'''            Wrap\(
              spacing: 24,
              runSpacing: 24,
              children: \[
                _buildNewServiceItem\(Icons\.electric_rickshaw_rounded, 'Auto'\),
                _buildNewServiceItem\(Icons\.local_taxi_rounded, 'Cab'\),
                _buildNewServiceItem\(Icons\.electric_moped_rounded, 'Bike'\),
              \],
            \),'''

new_services = '''            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildNewServiceItem('assets/images/auto.png', 'Auto'),
                _buildNewServiceItem('assets/images/cab.png', 'Cab'),
                _buildNewServiceItem('assets/images/bike.png', 'Bike'),
              ],
            ),'''
            
content = re.sub(old_services, new_services, content)

old_item_builder = r'''  Widget _buildNewServiceItem\(IconData icon, String label\) \{
    return Column\(
      mainAxisSize: MainAxisSize\.min,
      children: \[
        Container\(
          width: 80,
          height: 80,
          decoration: BoxDecoration\(
            color: const Color\(0xFFF3F4F6\),
            borderRadius: BorderRadius\.circular\(20\),
          \),
          child: Icon\(icon, size: 40, color: AppColors\.primary\),
        \),'''

new_item_builder = '''  Widget _buildNewServiceItem(String imagePath, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Image.asset(
              imagePath,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
            ),
          ),
        ),'''

content = re.sub(old_item_builder, new_item_builder, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied fixes for glass nav and 3D icons!")
