import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/design/tokens.dart';
import '../../../rides/data/ride_repository.dart';

class OffersBottomSheet extends StatefulWidget {
  final int currentFare;
  final String? currentlyAppliedCode;

  const OffersBottomSheet({
    super.key,
    required this.currentFare,
    this.currentlyAppliedCode,
  });

  @override
  State<OffersBottomSheet> createState() => _OffersBottomSheetState();
}

class _OffersBottomSheetState extends State<OffersBottomSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  Future<void> _fetchOffers() async {
    try {
      final offers = await RideRepository().getActiveOffers();
      if (mounted) {
        setState(() {
          _offers = offers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyOffer(Map<String, dynamic> offer) {
    // Check min amount
    final minAmount = (offer['minAmount'] as num?)?.toInt() ?? 0;
    if (widget.currentFare < minAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: context.colors.error, content: Text('Minimum ride value of ₹$minAmount not met.')),
      );
      return;
    }

    // Check expiry
    if (offer['expiryDate'] is Timestamp) {
      final expiry = (offer['expiryDate'] as Timestamp).toDate();
      if (expiry.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: context.colors.error, content: Text('This offer has expired.')),
        );
        return;
      }
    }

    // Calculate discount
    double discount = 0;
    final value = (offer['value'] as num?)?.toDouble() ?? 0;
    if (offer['type'] == 'flat') {
      discount = value;
    } else if (offer['type'] == 'percent') {
      discount = (widget.currentFare * value) / 100;
      // Optional: add max discount cap if stored in offer
      final maxDisc = (offer['maxDiscount'] as num?)?.toDouble();
      if (maxDisc != null && discount > maxDisc) discount = maxDisc;
    }

    Navigator.pop(context, {
      'code': offer['code'],
      'discountAmount': discount,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Apply Coupon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.colors.primary)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: context.colors.textMuted),
                  style: IconButton.styleFrom(backgroundColor: context.colors.background),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (_loading)
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: context.colors.rapidoYellow)),
            )
          else if (_offers.isEmpty)
            Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No offers available right now.', style: TextStyle(color: context.colors.textMuted))),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _offers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final offer = _offers[index];
                  final isFlat = offer['type'] == 'flat';
                  final valStr = isFlat ? '₹${offer['value']}' : '${offer['value']}%';
                  final minAmount = (offer['minAmount'] as num?)?.toInt() ?? 0;
                  final isEligible = widget.currentFare >= minAmount;
                  final isApplied = widget.currentlyAppliedCode == offer['code'];

                  return Opacity(
                    opacity: isEligible ? 1.0 : 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isApplied ? context.colors.success.withValues(alpha: 0.1) : context.colors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isApplied ? context.colors.success : context.colors.cardBorder),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: isApplied ? context.colors.success.withValues(alpha: 0.2) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.local_offer_rounded, color: isApplied ? context.colors.success : context.colors.rapidoYellow, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(offer['code']?.toString() ?? '---', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.colors.primary)),
                                    const SizedBox(width: 8),
                                    Text('$valStr OFF', style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.success, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(offer['description']?.toString() ?? '', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
                                if (!isEligible)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Add ₹${minAmount - widget.currentFare} more to unlock', style: TextStyle(color: context.colors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (isApplied)
                            Icon(Icons.check_circle_rounded, color: context.colors.success, size: 28)
                          else
                            TextButton(
                              onPressed: isEligible ? () => _applyOffer(offer) : null,
                              style: TextButton.styleFrom(
                                backgroundColor: isEligible ? context.colors.rapidoYellow : context.colors.cardBorder,
                                foregroundColor: isEligible ? Colors.black : context.colors.textMuted,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
          if (widget.currentlyAppliedCode != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: TextButton(
                onPressed: () => Navigator.pop(context, {'remove': true}),
                style: TextButton.styleFrom(foregroundColor: context.colors.error),
                child: const Text('Remove applied coupon', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
