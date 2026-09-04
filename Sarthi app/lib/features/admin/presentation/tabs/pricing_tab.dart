import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_providers.dart';
import '../admin_design.dart';
import '../admin_dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class PricingTab extends ConsumerStatefulWidget {
  const PricingTab({super.key});
  @override
  ConsumerState<PricingTab> createState() => PricingTabState();
}

class PricingTabState extends ConsumerState<PricingTab> {
  final formKey = GlobalKey<FormState>();

  // Fare Components
  final base = TextEditingController();
  final includedDistance = TextEditingController();
  final km = TextEditingController();
  final minute = TextEditingController();
  final minFare = TextEditingController();

  // Waiting Charges
  final freeWaitingTime = TextEditingController();
  final waitingChargePerMin = TextEditingController();

  // Dynamic Pricing
  bool dynamicPricingEnabled = false;
  final surgeMultiplier = TextEditingController();
  final surgeReason = TextEditingController();
  DateTime? surgeStartTime;
  DateTime? surgeEndTime;

  bool saving = false;
  String _vehicle = 'cab';

  Map<String, dynamic> _original = {};
  int _loadedVersion = -1;
  bool _conflictDetected = false;

  double previewDistance = 5.0;
  double previewDuration = 15.0;
  int previewWaitingMinutes = 5;

  @override
  void initState() {
    super.initState();
    final listeners = [
      base,
      includedDistance,
      km,
      minute,
      minFare,
      freeWaitingTime,
      waitingChargePerMin,
      surgeMultiplier,
      surgeReason,
    ];
    for (var controller in listeners) {
      controller.addListener(() => setState(() {}));
    }
  }

  void _populateForm(Map<String, dynamic>? data) {
    if (data == null) return;

    _original = {
      'base': data['baseFare'] ?? 15.0,
      'includedDistanceKm':
          data['includedDistanceKm'] ?? data['includedDistance'] ?? 3.0,
      'perKm': data['perKm'] ?? data['perKmFare'] ?? 5.0,
      'perMin': data['perMin'] ?? data['perMinuteFare'] ?? 1.0,
      'minimumFare': data['minimumFare'] ?? 15.0,
      'freeWaitingMinutes':
          data['freeWaitingMinutes'] ?? data['freeWaitingTime'] ?? 3.0,
      'waitingPerMin':
          data['waitingPerMin'] ?? data['waitingChargePerMin'] ?? 1.0,
      'surgeEnabled':
          data['surgeEnabled'] ?? data['dynamicPricingEnabled'] ?? false,
      'surgeMultiplier': data['surgeMultiplier'] ?? 1.0,
      'surgeReason': data['surgeReason'] ?? '',
      'surgeStartAt':
          (data['surgeStartAt'] as Timestamp?)?.toDate() ??
          (data['surgeStartTime'] as Timestamp?)?.toDate(),
      'surgeEndAt':
          (data['surgeEndAt'] as Timestamp?)?.toDate() ??
          (data['surgeEndTime'] as Timestamp?)?.toDate(),
      'pricingVersion': data['pricingVersion'] ?? 0,
    };

    _loadedVersion = _original['pricingVersion'] as int;
    _conflictDetected = false;

    base.text = _original['base'].toString();
    includedDistance.text = _original['includedDistanceKm'].toString();
    km.text = _original['perKm'].toString();
    minute.text = _original['perMin'].toString();
    minFare.text = _original['minimumFare'].toString();
    freeWaitingTime.text = _original['freeWaitingMinutes'].toString();
    waitingChargePerMin.text = _original['waitingPerMin'].toString();

    dynamicPricingEnabled = _original['surgeEnabled'];
    surgeMultiplier.text = _original['surgeMultiplier'].toString();
    surgeReason.text = _original['surgeReason'];
    surgeStartTime = _original['surgeStartAt'];
    surgeEndTime = _original['surgeEndAt'];

    setState(() {});
  }

  @override
  void dispose() {
    base.dispose();
    includedDistance.dispose();
    km.dispose();
    minute.dispose();
    minFare.dispose();
    freeWaitingTime.dispose();
    waitingChargePerMin.dispose();
    surgeMultiplier.dispose();
    surgeReason.dispose();
    super.dispose();
  }

  bool _hasChanges() {
    if (_original.isEmpty) return false;
    final b = double.tryParse(base.text) ?? 0.0;
    final id = double.tryParse(includedDistance.text) ?? 0.0;
    final k = double.tryParse(km.text) ?? 0.0;
    final m = double.tryParse(minute.text) ?? 0.0;
    final mf = double.tryParse(minFare.text) ?? 0.0;

    final fwt = double.tryParse(freeWaitingTime.text) ?? 0.0;
    final wcp = double.tryParse(waitingChargePerMin.text) ?? 0.0;

    final sm = double.tryParse(surgeMultiplier.text) ?? 1.0;
    final sr = surgeReason.text;

    return b != _original['base'] ||
        id != _original['includedDistanceKm'] ||
        k != _original['perKm'] ||
        m != _original['perMin'] ||
        mf != _original['minimumFare'] ||
        fwt != _original['freeWaitingMinutes'] ||
        wcp != _original['waitingPerMin'] ||
        dynamicPricingEnabled != _original['surgeEnabled'] ||
        sm != _original['surgeMultiplier'] ||
        sr != _original['surgeReason'] ||
        surgeStartTime != _original['surgeStartAt'] ||
        surgeEndTime != _original['surgeEndAt'];
  }

  String? _validateDouble(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n < 0) return 'Cannot be negative';
    if (n > 10000) return 'Value is too large';
    return null;
  }

  String? _validateSurge(String? v) {
    if (!dynamicPricingEnabled) return null;
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Enter a number (e.g. 1.5)';
    if (n < 1.0) return 'Surge must be at least 1.0';
    if (n > 5.0) return 'Surge is too large';
    return null;
  }

  String? _validateSurgeReason(String? v) {
    if (!dynamicPricingEnabled) return null;
    if (v == null || v.trim().isEmpty)
      return 'Reason required when dynamic pricing is on';
    return null;
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        surgeStartTime = dt;
      } else {
        surgeEndTime = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fareRulesAsync = ref.watch(fareRulesProvider(_vehicle));

    ref.listen<AsyncValue<Map<String, dynamic>?>>(fareRulesProvider(_vehicle), (
      previous,
      next,
    ) {
      if (next.hasValue && next.value != null) {
        final newVersion = next.value!['pricingVersion'] as int? ?? 0;
        if (_loadedVersion == -1) {
          // First load
          _populateForm(next.value!);
        } else if (newVersion > _loadedVersion) {
          // A change happened elsewhere!
          if (_hasChanges()) {
            setState(() => _conflictDetected = true);
          } else {
            _populateForm(next.value!);
          }
        }
      }
    });

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 180),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(),
                  SizedBox(height: 24),
                  _buildVehicleSelector(),
                  SizedBox(height: 24),
                  if (_conflictDetected) _buildConflictWarning(),
                  if (_conflictDetected) SizedBox(height: 24),

                  fareRulesAsync.when(
                    data: (data) {
                      if (_loadedVersion == -1 && data != null) {
                        // Waiting for listen to catch it, or just populate directly if missed
                        Future.microtask(() => _populateForm(data));
                        return Center(child: CircularProgressIndicator());
                      }
                      return Column(
                        children: [
                          _buildFareForm(),
                          SizedBox(height: 24),
                          _buildWaitingChargesForm(),
                          SizedBox(height: 24),
                          _buildDynamicPricingForm(),
                          SizedBox(height: 24),
                          _buildLivePreview(),
                        ],
                      );
                    },
                    loading: () => Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ]),
              ),
            ),
          ],
        ),
        if (fareRulesAsync.hasValue)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStickyBottomBar(),
          ),
      ],
    );
  }

  Widget _buildConflictWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: context.colors.error, size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fare rules were updated from another admin platform.',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: context.colors.error,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Reload the latest values before saving to prevent overwriting.',
                  style: GoogleFonts.inter(
                    color: context.colors.error.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              final latest = ref.read(fareRulesProvider(_vehicle)).value;
              _populateForm(latest);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text('Reload'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2748), Color(0xFF143963)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2748).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.adminAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.colors.adminAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: context.colors.adminAccent,
              size: 20,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Fare Configuration',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Tooltip(
                      message:
                          'Fares are calculated as: Max(Min Fare, Base Fare + Extra Km Charge + Time Charge)',
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: context.colors.adminAccent,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Changes apply immediately to new ride estimates.',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 9,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector() {
    final options = [
      {'id': 'auto', 'label': 'Auto', 'icon': Icons.electric_rickshaw_rounded},
      {'id': 'cab', 'label': 'Cab', 'icon': Icons.local_taxi_rounded},
      {'id': 'bike', 'label': 'Bike', 'icon': Icons.motorcycle_rounded},
      {'id': 'parcel', 'label': 'Parcel', 'icon': Icons.local_shipping_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.colors.cardBorder,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _vehicle == opt['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_vehicle != opt['id']) {
                  setState(() {
                    _vehicle = opt['id'] as String;
                    _loadedVersion =
                        -1; // reset version to trigger reload on next frame
                    _conflictDetected = false;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colors.adminAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opt['icon'] as IconData,
                      size: 14,
                      color: isSelected
                          ? const Color(0xFF0B2748)
                          : context.colors.textMuted,
                    ),
                    SizedBox(width: 4),
                    Text(
                      opt['label'] as String,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: isSelected
                            ? const Color(0xFF0B2748)
                            : context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFareForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fare Components',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12),
            FareField(
              controller: base,
              label: 'Base Fare',
              unit: '₹',
              icon: Icons.flag_rounded,
              validator: _validateDouble,
            ),
            SizedBox(height: 12),
            FareField(
              controller: includedDistance,
              label: 'Included Distance',
              unit: 'km',
              icon: Icons.map_rounded,
              validator: _validateDouble,
            ),
            SizedBox(height: 12),
            FareField(
              controller: km,
              label: 'Rate per Extra Km',
              unit: '₹/km',
              icon: Icons.route_rounded,
              validator: _validateDouble,
            ),
            SizedBox(height: 12),
            FareField(
              controller: minute,
              label: 'Rate per Minute',
              unit: '₹/min',
              icon: Icons.schedule_rounded,
              validator: _validateDouble,
            ),
            SizedBox(height: 12),
            FareField(
              controller: minFare,
              label: 'Minimum Fare',
              unit: '₹',
              icon: Icons.money_rounded,
              validator: _validateDouble,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingChargesForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waiting Charges',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12),
          FareField(
            controller: freeWaitingTime,
            label: 'Free Waiting Time',
            unit: 'min',
            icon: Icons.timer_outlined,
            validator: _validateDouble,
          ),
          SizedBox(height: 12),
          FareField(
            controller: waitingChargePerMin,
            label: 'Charge After Free Time',
            unit: '₹/min',
            icon: Icons.hourglass_bottom_rounded,
            validator: _validateDouble,
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicPricingForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dynamicPricingEnabled
              ? context.colors.adminAccent
              : context.colors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dynamic Pricing',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Switch(
                value: dynamicPricingEnabled,
                onChanged: (v) => setState(() => dynamicPricingEnabled = v),
                activeThumbColor: context.colors.adminAccent,
                activeTrackColor: context.colors.adminAccent.withValues(
                  alpha: 0.3,
                ),
              ),
            ],
          ),
          if (dynamicPricingEnabled) ...[
            SizedBox(height: 16),
            FareField(
              controller: surgeMultiplier,
              label: 'Surge Multiplier',
              unit: '×',
              icon: Icons.electric_bolt_rounded,
              validator: _validateSurge,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: surgeReason,
              validator: _validateSurgeReason,
              style: GoogleFonts.inter(fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Surge Reason (e.g. Heavy Rain, Rush Hour)',
                labelStyle: GoogleFonts.inter(
                  color: context.colors.textMuted,
                  fontSize: 11,
                ),
                filled: true,
                fillColor: context.colors.background,
                prefixIcon: Icon(
                  Icons.description_outlined,
                  color: context.colors.textMuted,
                  size: 18,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.colors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDateTime(true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Start Time',
                        labelStyle: GoogleFonts.inter(
                          color: context.colors.textMuted,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: context.colors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.colors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.colors.cardBorder,
                          ),
                        ),
                      ),
                      child: Text(
                        surgeStartTime?.toString().substring(0, 16) ??
                            'Not set',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDateTime(false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'End Time',
                        labelStyle: GoogleFonts.inter(
                          color: context.colors.textMuted,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: context.colors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.colors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.colors.cardBorder,
                          ),
                        ),
                      ),
                      child: Text(
                        surgeEndTime?.toString().substring(0, 16) ?? 'Not set',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    final b = double.tryParse(base.text) ?? 0.0;
    final id = double.tryParse(includedDistance.text) ?? 0.0;
    final k = double.tryParse(km.text) ?? 0.0;
    final m = double.tryParse(minute.text) ?? 0.0;
    final mf = double.tryParse(minFare.text) ?? 0.0;

    final fwt = double.tryParse(freeWaitingTime.text) ?? 0.0;
    final wcp = double.tryParse(waitingChargePerMin.text) ?? 0.0;

    final sm = dynamicPricingEnabled
        ? (double.tryParse(surgeMultiplier.text) ?? 1.0)
        : 1.0;

    double extraDist = (previewDistance - id).clamp(0.0, double.infinity);
    double distCharge = extraDist * k;
    double timeCharge = previewDuration * m;
    double normalFare = b + distCharge + timeCharge;
    if (normalFare < mf) normalFare = mf;
    double finalFare = normalFare * sm;

    double chargeableWaitingMinutes = (previewWaitingMinutes - fwt).clamp(
      0.0,
      double.infinity,
    );
    double waitingCharge = chargeableWaitingMinutes * wcp;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B2748),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2748).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.adminAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: context.colors.adminAccent,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Preview',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Estimated ride breakdown',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSlider(
                        'Distance (km)',
                        previewDistance,
                        1,
                        50,
                        (v) => setState(() => previewDistance = v),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildSlider(
                        'Duration (min)',
                        previewDuration,
                        5,
                        120,
                        (v) => setState(() => previewDuration = v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildSlider(
                  'Waiting Time (min)',
                  previewWaitingMinutes.toDouble(),
                  0,
                  30,
                  (v) => setState(() => previewWaitingMinutes = v.toInt()),
                ),
                SizedBox(height: 24),
                const Divider(color: Color(0xFFE5E7EB)),
                SizedBox(height: 16),
                _buildReceiptRow('Base Fare', '₹${b.toStringAsFixed(1)}'),
                if (extraDist > 0)
                  _buildReceiptRow(
                    'Extra Distance (${extraDist.toStringAsFixed(1)} km)',
                    '₹${distCharge.toStringAsFixed(1)}',
                  ),
                _buildReceiptRow(
                  'Time Charge',
                  '₹${timeCharge.toStringAsFixed(1)}',
                ),
                if (normalFare == mf)
                  _buildReceiptRow(
                    'Minimum Fare Applied',
                    '',
                    isHighlighted: true,
                  ),
                if (sm > 1.0) ...[
                  SizedBox(height: 8),
                  _buildReceiptRow(
                    'Dynamic Pricing (${sm}x)',
                    '+₹${((sm - 1) * normalFare).toStringAsFixed(1)}',
                    isHighlighted: true,
                  ),
                ],
                if (waitingCharge > 0)
                  _buildReceiptRow(
                    'Waiting Charge',
                    '₹${waitingCharge.toStringAsFixed(1)}',
                    isHighlighted: true,
                  ),
                SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Estimate',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0B2748),
                        ),
                      ),
                      Text(
                        '₹${(finalFare + waitingCharge).toStringAsFixed(1)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: context.colors.adminAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double val,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B778C),
              ),
            ),
            Text(
              val.toStringAsFixed(1),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B2748),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: context.colors.adminAccent,
            inactiveTrackColor: context.colors.adminAccent.withValues(
              alpha: 0.2,
            ),
            thumbColor: const Color(0xFF0B2748),
            overlayColor: context.colors.adminAccent.withValues(alpha: 0.1),
          ),
          child: Slider(value: val, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(
    String label,
    String amount, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isHighlighted
                  ? context.colors.warning
                  : const Color(0xFF4B5563),
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isHighlighted
                  ? context.colors.warning
                  : const Color(0xFF172B4D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    final hasChanges = _hasChanges();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (hasChanges)
              Expanded(
                child: OutlinedButton(
                  onPressed: saving
                      ? null
                      : () {
                          final latest = ref
                              .read(fareRulesProvider(_vehicle))
                              .value;
                          _populateForm(latest); // resets to original
                          FocusScope.of(context).unfocus();
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    'Discard',
                    style: GoogleFonts.inter(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            if (hasChanges) SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (!hasChanges || saving || _conflictDetected)
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false))
                          return;
                        setState(() => saving = true);
                        try {
                          await ref
                              .read(adminRepositoryProvider)
                              .updateFareRules(
                                _vehicle,
                                double.parse(base.text),
                                double.parse(includedDistance.text),
                                double.parse(km.text),
                                double.parse(minute.text),
                                double.parse(minFare.text),
                                double.parse(freeWaitingTime.text),
                                double.parse(waitingChargePerMin.text),
                                dynamicPricingEnabled,
                                double.parse(surgeMultiplier.text),
                                surgeReason.text,
                                surgeStartTime,
                                surgeEndTime,
                              );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fare rules updated!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // We don't need to manually _populateForm because the Stream will emit a new snapshot
                            // and _populateForm will be called automatically if there are no conflicts.
                          }
                        } catch (e) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(friendlyError(e))),
                            );
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B2748),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                ),
                child: saving
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        hasChanges ? 'Save Changes' : 'Up to date',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FareField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final IconData icon;
  final String? Function(String?)? validator;

  const FareField({
    super.key,
    required this.controller,
    required this.label,
    required this.unit,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.inter(fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: context.colors.textMuted,
          fontSize: 10,
        ),
        filled: true,
        fillColor: context.colors.background,
        prefixIcon: Icon(icon, color: context.colors.textMuted, size: 16),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            unit,
            style: GoogleFonts.inter(
              color: context.colors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.colors.primary, width: 2),
        ),
      ),
    );
  }
}
