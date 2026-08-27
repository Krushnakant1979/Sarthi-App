import sys
import re

path_map = r'c:\Users\krush\rapido-app\lib\features\map\presentation\map_home_screen.dart'
with open(path_map, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _cabFare variable
content = content.replace('int? _parcelFare;', 'int? _parcelFare;\n  int? _cabFare;')

# 2. Add to condition
content = content.replace('_bikeFare != null && _autoFare != null && _parcelFare != null', '_bikeFare != null && _autoFare != null && _parcelFare != null && _cabFare != null')

# 3. Add to null assignments
content = content.replace('_bikeFare = null; _autoFare = null; _parcelFare = null;', '_bikeFare = null; _autoFare = null; _parcelFare = null; _cabFare = null;')

# 4. Add UI option
ui_to_find = """            _buildVehicleOption(
              'parcel',
              'Send a Parcel',
              Icons.local_shipping_rounded,
              _parcelFare!,
            ),"""
ui_to_replace = ui_to_find + """
            const SizedBox(height: 8),
            _buildVehicleOption(
              'cab',
              'RapidGo Cab',
              Icons.directions_car_rounded,
              _cabFare!,
            ),"""
content = content.replace(ui_to_find, ui_to_replace)

# 5. Fix ternary operators
ternary1 = "_vehicleType == 'bike' ? _bikeFare! : _vehicleType == 'auto' ? _autoFare! : _parcelFare!"
ternary1_replace = "_vehicleType == 'bike' ? _bikeFare! : _vehicleType == 'auto' ? _autoFare! : _vehicleType == 'parcel' ? _parcelFare! : _cabFare!"
content = content.replace(ternary1, ternary1_replace)

# Another ternary might exist:
ternary2 = """                      : _vehicleType == 'parcel'
                          ? _parcelFare!
                          : 0,"""
ternary2_replace = """                      : _vehicleType == 'parcel'
                          ? _parcelFare!
                          : _vehicleType == 'cab' ? _cabFare! : 0,"""
content = content.replace(ternary2, ternary2_replace)

# 6. Add fare calculation logic
calc_to_find = """            _parcelFare = FareCalculator.calculateFare(
              baseFare: (parcelRules?['baseFare'] ?? 20).toDouble(),
              perKm: (parcelRules?['perKm'] ?? 6).toDouble(),
              perMin: (parcelRules?['perMin'] ?? 1.5).toDouble(),
            );"""
calc_to_replace = calc_to_find + """
            
            final cabRules = ref.read(fareRulesProvider('cab')).value;
            _cabFare = FareCalculator.calculateFare(
              baseFare: (cabRules?['baseFare'] ?? 60).toDouble(),
              perKm: (cabRules?['perKm'] ?? 15).toDouble(),
              perMin: (cabRules?['perMin'] ?? 2.5).toDouble(),
            );"""
content = content.replace(calc_to_find, calc_to_replace)

with open(path_map, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done modifying map_home_screen.dart')

# 7. Modify admin_dashboard_screen.dart
path_admin = r'c:\Users\krush\rapido-app\lib\features\admin\presentation\admin_dashboard_screen.dart'
with open(path_admin, 'r', encoding='utf-8') as f:
    admin_content = f.read()

admin_ui_find = """        const _FareEditorCard(vehicleType: 'parcel', label: 'Parcel', icon: Icons.local_shipping_rounded),"""
admin_ui_replace = admin_ui_find + """
        const SizedBox(height: 16),
        const _FareEditorCard(vehicleType: 'cab', label: 'Cab', icon: Icons.directions_car_rounded),"""
admin_content = admin_content.replace(admin_ui_find, admin_ui_replace)

with open(path_admin, 'w', encoding='utf-8') as f:
    f.write(admin_content)
print('Done modifying admin_dashboard_screen.dart')
