import 'package:flutter/material.dart';
import 'package:sarthi_app/core/design/tokens.dart';
import 'package:sarthi_app/features/user/rides/domain/fare_calculator.dart';
import 'drag_handle.dart';

class SelectedBottomSheet extends StatelessWidget {
  final String vehicleType;
  final FareBreakdown? autoFare;
  final FareBreakdown? parcelFare;
  final FareBreakdown? cabFare;
  final FareBreakdown? bikeFare;
  final int? discountAmount;
  final String? appliedOfferCode;
  final bool isFetchingRoute;
  final int? durationSeconds;
  final int? distanceMeters;
  final Map<String, dynamic> destination;
  final String paymentMethod;
  final ValueChanged<String> onVehicleTypeChanged;
  final VoidCallback onOfferTap;
  final VoidCallback onPaymentTap;
  final VoidCallback onConfirmRide;

  const SelectedBottomSheet({
    super.key,
    required this.vehicleType,
    this.autoFare,
    this.parcelFare,
    this.cabFare,
    this.bikeFare,
    this.discountAmount,
    this.appliedOfferCode,
    required this.isFetchingRoute,
    this.durationSeconds,
    this.distanceMeters,
    required this.destination,
    required this.paymentMethod,
    required this.onVehicleTypeChanged,
    required this.onOfferTap,
    required this.onPaymentTap,
    required this.onConfirmRide,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    
    final selectedServiceLabel = switch (vehicleType) {
      'auto' => 'Auto Rickshaw',
      'parcel' => 'Parcel',
      'cab' => 'Cab',
      _ => 'Bike',
    };
    final selectedFare = switch (vehicleType) {
      'auto' => autoFare,
      'parcel' => parcelFare,
      'cab' => cabFare,
      _ => bikeFare,
    };
    final payableFare =
        ((selectedFare?.finalFare.toInt() ?? 0) - (discountAmount ?? 0))
            .toInt()
            .clamp(0, 999999);

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 22 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DragHandle(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHOOSE YOUR RIDE',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.25,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ride your way',
                      style: TextStyle(
                        color: Color(0xFF0B2545),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isFetchingRoute &&
                  durationSeconds != null &&
                  distanceMeters != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        size: 14,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${(durationSeconds! / 60).round()} min • ${(distanceMeters! / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9EEF5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.colors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.circle,
                    color: context.colors.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DROP-OFF',
                        style: TextStyle(
                          color: Color(0xFF8A94A6),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        destination['description'] ?? 'Destination',
                        style: const TextStyle(
                          color: Color(0xFF25364D),
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (isFetchingRoute)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (bikeFare != null &&
              autoFare != null &&
              parcelFare != null &&
              cabFare != null) ...[
            Container(
              height: 238,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Scrollbar(
                  thickness: 4,
                  radius: const Radius.circular(8),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildVehicleOption(
                          context,
                          'bike',
                          'Bike',
                          Icons.electric_moped_rounded,
                          bikeFare!,
                        ),
                        const SizedBox(height: 6),
                        _buildVehicleOption(
                          context,
                          'auto',
                          'Auto Rickshaw',
                          Icons.local_taxi_rounded,
                          autoFare!,
                        ),
                        const SizedBox(height: 6),
                        _buildVehicleOption(
                          context,
                          'parcel',
                          'Send a Parcel',
                          Icons.local_shipping_rounded,
                          parcelFare!,
                        ),
                        const SizedBox(height: 6),
                        _buildVehicleOption(
                          context,
                          'cab',
                          'Cab',
                          Icons.directions_car_rounded,
                          cabFare!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOfferTap,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: appliedOfferCode != null
                            ? const Color(0xFFEAFBF3)
                            : const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: appliedOfferCode != null
                              ? const Color(0xFFBDEDD5)
                              : const Color(0xFFE8EDF4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: appliedOfferCode != null
                                  ? const Color(0xFF16A36A)
                                  : const Color(0xFFFFE575),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.local_offer_rounded,
                              color: appliedOfferCode != null
                                  ? Colors.white
                                  : const Color(0xFF0B2545),
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              appliedOfferCode != null
                                  ? '$appliedOfferCode Applied (-₹${discountAmount?.toInt()})'
                                  : 'Offer',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: appliedOfferCode != null
                                    ? const Color(0xFF10B981)
                                    : context.colors.primary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: appliedOfferCode != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6B7280),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: onPaymentTap,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8EDF4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F8EF),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.payments_rounded,
                              color: Color(0xFF0E9F62),
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              paymentMethod,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF6B7280),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                minimumSize: const Size(double.infinity, 54),
                elevation: 5,
                shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.38),
              ),
              onPressed: onConfirmRide,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_rounded, size: 17),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm $selectedServiceLabel',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹$payableFare',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleOption(
    BuildContext context,
    String type,
    String title,
    IconData icon,
    FareBreakdown fare,
  ) {
    final isSelected = vehicleType == type;
    final serviceNote = switch (type) {
      'auto' => 'Everyday city ride',
      'parcel' => 'Quick doorstep delivery',
      'cab' => 'Extra space and comfort',
      _ => 'Fast and affordable',
    };
    return InkWell(
      onTap: () => onVehicleTypeChanged(type),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFE9EEF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    serviceNote,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fare.finalFare.toInt()}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                if (fare.discount > 0)
                  Text(
                    '₹${fare.baseFare.toInt()}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
