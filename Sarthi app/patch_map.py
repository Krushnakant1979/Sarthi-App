import re
import sys

path = r'c:\Users\krush\Sarthi\Sarthi app\lib\features\map\presentation\map_home_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 0. Add import
if 'cloud_firestore.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';")

# 1. Update FareBreakdown variables
content = re.sub(r'int\? _bikeFare;', 'FareBreakdown? _bikeFare;', content)
content = re.sub(r'int\? _autoFare;', 'FareBreakdown? _autoFare;', content)
content = re.sub(r'int\? _parcelFare;', 'FareBreakdown? _parcelFare;', content)
content = re.sub(r'int\? _cabFare;', 'FareBreakdown? _cabFare;', content)

# 2. Update currentFare getter (Lines 987, 1039, 1142)
ternary = r"_vehicleType == 'auto' \? _autoFare! : _vehicleType == 'parcel' \? _parcelFare! : _vehicleType == 'cab' \? _cabFare! : _bikeFare!"
content = re.sub(ternary, r"(_vehicleType == 'auto' ? _autoFare! : _vehicleType == 'parcel' ? _parcelFare! : _vehicleType == 'cab' ? _cabFare! : _bikeFare!).finalFare.toInt()", content)

ternary2 = r"_vehicleType == 'bike' \? _bikeFare! : _vehicleType == 'auto' \? _autoFare! : _vehicleType == 'parcel' \? _parcelFare! : _cabFare!"
content = re.sub(ternary2, r"(_vehicleType == 'bike' ? _bikeFare! : _vehicleType == 'auto' ? _autoFare! : _vehicleType == 'parcel' ? _parcelFare! : _cabFare!).finalFare.toInt()", content)

# 3. _buildVehicleOption definition
build_veh_old = '''  Widget _buildVehicleOption(
    String type,
    String title,
    IconData icon,
    int fare,
  ) {
    final isSelected = _vehicleType == type;
    return InkWell(
      onTap: () => setState(() => _vehicleType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.colors.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.rapidoYellow
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? context.colors.primary : const Color(0xFF6B7280),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(_durationSeconds! / 60).round()} min • ${(_distanceMeters! / 1000).toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₹$fare',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? context.colors.primary : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }'''

build_veh_new = '''  Widget _buildVehicleOption(
    String type,
    String title,
    IconData icon,
    FareBreakdown fare,
  ) {
    final isSelected = _vehicleType == type;
    return InkWell(
      onTap: () => setState(() => _vehicleType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.colors.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.rapidoYellow
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? context.colors.primary : const Color(0xFF6B7280),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(_durationSeconds! / 60).round()} min • ${(_distanceMeters! / 1000).toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                  if (fare.surgeMultiplier > 1.0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'High demand pricing applied',
                      style: TextStyle(
                        color: context.colors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '₹${fare.finalFare.toInt()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? context.colors.primary : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }'''

if build_veh_old in content:
    content = content.replace(build_veh_old, build_veh_new)
else:
    print('Failed to replace _buildVehicleOption')

# 4. Update createRideRequest 
# In map_home_screen.dart:
create_ride_pattern = r'''                    final finalFare = _vehicleType == 'auto'
                        \? _autoFare!
                        : _vehicleType == 'parcel'
                            \? _parcelFare!
                            : _vehicleType == 'cab'
                                \? _cabFare!
                                : _bikeFare!;
                    
                    final discountedFare = \(finalFare - \(_discountAmount \?\? 0\)\)\.toInt\(\)\.clamp\(0, 999999\);'''

create_ride_replace = r'''                    final currentFareObj = _vehicleType == 'auto'
                        ? _autoFare!
                        : _vehicleType == 'parcel'
                            ? _parcelFare!
                            : _vehicleType == 'cab'
                                ? _cabFare!
                                : _bikeFare!;
                    
                    final discountedFare = (currentFareObj.finalFare.toInt() - (_discountAmount ?? 0)).toInt().clamp(0, 999999);'''
content = re.sub(create_ride_pattern, create_ride_replace, content)

content = re.sub(r'(discountAmount: _discountAmount,)', r'\1\n                      fareBreakdown: currentFareObj.toMap(),', content)


# 5. Update FareCalculator calls
calc_old = r'''            _bikeFare = FareCalculator\.calculateFare\(
              _distanceMeters!, _durationSeconds!,
              baseFare: \(bikeRules\?\['baseFare'\] \?\? 15\)\.toDouble\(\),
              perKm: \(bikeRules\?\['perKm'\] \?\? 5\)\.toDouble\(\),
              perMin: \(bikeRules\?\['perMin'\] \?\? 1\)\.toDouble\(\),
            \);
            _autoFare = FareCalculator\.calculateFare\(
              _distanceMeters!, _durationSeconds!,
              baseFare: \(autoRules\?\['baseFare'\] \?\? 20\)\.toDouble\(\),
              perKm: \(autoRules\?\['perKm'\] \?\? 8\)\.toDouble\(\),
              perMin: \(autoRules\?\['perMin'\] \?\? 2\)\.toDouble\(\),
            \);
            _parcelFare = FareCalculator\.calculateFare\(
              _distanceMeters!, _durationSeconds!,
              baseFare: \(parcelRules\?\['baseFare'\] \?\? 20\)\.toDouble\(\),
              perKm: \(parcelRules\?\['perKm'\] \?\? 6\)\.toDouble\(\),
              perMin: \(parcelRules\?\['perMin'\] \?\? 1.5\)\.toDouble\(\),
            \);
            final cabRules = ref\.read\(fareRulesProvider\('cab'\)\)\.value;
            _cabFare = FareCalculator\.calculateFare\(
              _distanceMeters!, _durationSeconds!,
              baseFare: \(cabRules\?\['baseFare'\] \?\? 30\)\.toDouble\(\),
              perKm: \(cabRules\?\['perKm'\] \?\? 10\)\.toDouble\(\),
              perMin: \(cabRules\?\['perMin'\] \?\? 2.5\)\.toDouble\(\),
            \);'''

calc_new = '''            FareBreakdown getFare(Map<String, dynamic>? rules) {
              return FareCalculator.calculateFare(
                _distanceMeters!, _durationSeconds!,
                baseFare: (rules?['baseFare'] ?? 15).toDouble(),
                includedDistanceKm: (rules?['includedDistance'] ?? 3).toDouble(),
                ratePerKm: (rules?['perKm'] ?? 5).toDouble(),
                ratePerMinute: (rules?['perMin'] ?? 1).toDouble(),
                minimumFare: (rules?['minimumFare'] ?? 15).toDouble(),
                dynamicPricingEnabled: rules?['dynamicPricingEnabled'] ?? false,
                surgeMultiplier: (rules?['surgeMultiplier'] ?? 1.0).toDouble(),
                surgeEndTime: (rules?['surgeEndTime'] as Timestamp?)?.toDate(),
              );
            }
            
            _bikeFare = getFare(bikeRules);
            _autoFare = getFare(autoRules);
            _parcelFare = getFare(parcelRules);
            final cabRules = ref.read(fareRulesProvider('cab')).value;
            _cabFare = getFare(cabRules);'''

content = re.sub(calc_old, calc_new, content)

# Write back
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
