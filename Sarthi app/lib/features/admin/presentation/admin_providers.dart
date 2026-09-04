import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../../auth/domain/app_user.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final fareRulesProvider = StreamProvider.family<Map<String, dynamic>?, String>((
  ref,
  vehicleType,
) {
  return ref.watch(adminRepositoryProvider).streamFareRules(vehicleType);
});

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAllUsers();
});

final allRidesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).streamAllRides();
});

final usersFilterProvider = StateProvider<String>((ref) => 'all');

final payoutHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).streamPayoutHistory();
});

final offersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).streamOffers();
});

final offersTabProvider = StateProvider<String>((ref) => 'Active');
final offersSearchProvider = StateProvider<String>((ref) => '');
final offersSortProvider = StateProvider<String>((ref) => 'newest');

final processedOffersProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final offersAsync = ref.watch(offersProvider);
  final search = ref.watch(offersSearchProvider).toLowerCase();
  final tab = ref.watch(offersTabProvider);
  final sort = ref.watch(offersSortProvider);

  if (offersAsync.value == null) return [];
  var offers = List<Map<String, dynamic>>.from(offersAsync.value!);

  // 1. Calculate live status for each offer
  final now = DateTime.now();
  for (var i = 0; i < offers.length; i++) {
    final o = Map<String, dynamic>.from(offers[i]);

    // Default to published if not set for backward compatibility
    final statusField =
        o['status'] as String? ??
        (o['isActive'] == true ? 'published' : 'draft');

    DateTime? start;
    if (o['startDate'] != null) start = (o['startDate'] as dynamic).toDate();

    DateTime? expiry;
    if (o['expiryDate'] != null) expiry = (o['expiryDate'] as dynamic).toDate();

    String liveStatus = 'draft';
    if (statusField == 'published') {
      if (expiry != null && expiry.isBefore(now)) {
        liveStatus = 'expired';
      } else if (start != null && start.isAfter(now)) {
        liveStatus = 'scheduled';
      } else {
        liveStatus = 'active';
      }
    } else {
      liveStatus = statusField; // e.g. draft or inactive
    }

    o['liveStatus'] = liveStatus;
    offers[i] = o;
  }

  // 2. Filter by tab
  if (tab != 'All') {
    offers = offers.where((o) => o['liveStatus'] == tab.toLowerCase()).toList();
  } else {
    // If "All", maybe exclude drafts or include them based on preference. Let's include everything.
  }

  // 3. Filter by search
  if (search.isNotEmpty) {
    offers = offers.where((o) {
      final code = (o['code'] as String?)?.toLowerCase() ?? '';
      final desc = (o['description'] as String?)?.toLowerCase() ?? '';
      return code.contains(search) || desc.contains(search);
    }).toList();
  }

  // 4. Sort
  offers.sort((a, b) {
    switch (sort) {
      case 'oldest':
        final ad = (a['createdAt'] as dynamic)?.toDate() ?? DateTime(2000);
        final bd = (b['createdAt'] as dynamic)?.toDate() ?? DateTime(2000);
        return ad.compareTo(bd);
      case 'expiring':
        final ae = (a['expiryDate'] as dynamic)?.toDate() ?? DateTime(2100);
        final be = (b['expiryDate'] as dynamic)?.toDate() ?? DateTime(2100);
        return ae.compareTo(be);
      case 'discount':
        final av = (a['value'] as num?)?.toDouble() ?? 0;
        final bv = (b['value'] as num?)?.toDouble() ?? 0;
        return bv.compareTo(av); // descending
      case 'newest':
      default:
        final ad = (a['createdAt'] as dynamic)?.toDate() ?? DateTime(2000);
        final bd = (b['createdAt'] as dynamic)?.toDate() ?? DateTime(2000);
        return bd.compareTo(ad);
    }
  });

  return offers;
});

final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAnalyticsData();
});

final globalSettingsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).streamGlobalSettings();
});

final supportTicketsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(adminRepositoryProvider).streamSupportTickets();
});

// ─── Support & Complaints State ─────────────────────────────────────────────
final supportTabProvider = StateProvider<String>((ref) => 'Open Complaints');
final supportRoleProvider = StateProvider<String>((ref) => 'All');
final supportSearchProvider = StateProvider<String>((ref) => '');
final supportSortProvider = StateProvider<String>((ref) => 'newest');

// ─── Analytics Filtering & State ─────────────────────────────────────────────
enum RevenuePeriod { day, month, year }

class AnalyticsFilterState {
  final RevenuePeriod period;
  final DateTime selectedDate;

  AnalyticsFilterState({required this.period, required this.selectedDate});

  AnalyticsFilterState copyWith({
    RevenuePeriod? period,
    DateTime? selectedDate,
  }) {
    return AnalyticsFilterState(
      period: period ?? this.period,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class AnalyticsFilterNotifier extends StateNotifier<AnalyticsFilterState> {
  AnalyticsFilterNotifier()
    : super(
        AnalyticsFilterState(
          period: RevenuePeriod.day,
          selectedDate: DateTime.now(),
        ),
      );

  void setPeriod(RevenuePeriod p) => state = state.copyWith(period: p);
  void setDate(DateTime d) => state = state.copyWith(selectedDate: d);
}

final analyticsFilterProvider =
    StateNotifierProvider<AnalyticsFilterNotifier, AnalyticsFilterState>((ref) {
      return AnalyticsFilterNotifier();
    });

final activeCaptainsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(adminRepositoryProvider).streamActiveCaptainsCount();
});

final filteredRidesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final filter = ref.watch(analyticsFilterProvider);
  final repo = ref.watch(adminRepositoryProvider);

  DateTime start;
  DateTime end;
  final d = filter.selectedDate;

  switch (filter.period) {
    case RevenuePeriod.day:
      start = DateTime(d.year, d.month, d.day);
      end = start.add(const Duration(days: 1));
      break;
    case RevenuePeriod.month:
      start = DateTime(d.year, d.month);
      end = DateTime(d.year, d.month + 1);
      break;
    case RevenuePeriod.year:
      start = DateTime(d.year);
      end = DateTime(d.year + 1);
      break;
  }

  return repo.streamAnalyticsRides(start, end);
});

final previousFilteredRidesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      final filter = ref.watch(analyticsFilterProvider);
      final repo = ref.watch(adminRepositoryProvider);

      DateTime start;
      DateTime end;
      final d = filter.selectedDate;

      switch (filter.period) {
        case RevenuePeriod.day:
          start = DateTime(d.year, d.month, d.day - 1);
          end = start.add(const Duration(days: 1));
          break;
        case RevenuePeriod.month:
          start = DateTime(d.year, d.month - 1);
          end = DateTime(d.year, d.month);
          break;
        case RevenuePeriod.year:
          start = DateTime(d.year - 1);
          end = DateTime(d.year);
          break;
      }

      return repo.streamAnalyticsRides(start, end);
    });

class ProcessedAnalyticsData {
  final double totalRevenue;
  final int totalRides;
  final double averageFare;
  final double previousTotalRevenue;
  final Map<String, double> serviceRevenue;
  final List<double> chartData;
  final List<String> chartLabels;
  final List<Map<String, dynamic>> topLocations;

  ProcessedAnalyticsData({
    required this.totalRevenue,
    required this.totalRides,
    required this.averageFare,
    required this.previousTotalRevenue,
    required this.serviceRevenue,
    required this.chartData,
    required this.chartLabels,
    required this.topLocations,
  });
}

final processedAnalyticsProvider = Provider<ProcessedAnalyticsData>((ref) {
  final ridesAsync = ref.watch(filteredRidesProvider);
  final prevRidesAsync = ref.watch(previousFilteredRidesProvider);
  final filter = ref.watch(analyticsFilterProvider);

  final rides = ridesAsync.value ?? [];
  final prevRides = prevRidesAsync.value ?? [];

  double totalRev = 0;
  Map<String, double> svcRev = {'bike': 0, 'auto': 0, 'cab': 0};
  Map<String, int> locCounts = {};

  for (var ride in rides) {
    final fare = (ride['fareEstimate'] as num?)?.toDouble() ?? 0.0;
    totalRev += fare;

    final type = (ride['vehicleType'] as String?)?.toLowerCase() ?? 'bike';
    if (svcRev.containsKey(type)) {
      svcRev[type] = svcRev[type]! + fare;
    } else {
      svcRev[type] = fare;
    }

    final pickupAddress = ride['pickup']?['address'] as String?;
    if (pickupAddress != null &&
        pickupAddress.isNotEmpty &&
        pickupAddress != 'User pickup location') {
      final parts = pickupAddress.split(',').map((e) => e.trim()).toList();
      String city = parts.first;
      int offset = parts.length - 1;
      if (offset >= 0 && parts[offset].toLowerCase() == 'india') offset--;
      if (offset >= 0 && RegExp(r'^\d+$').hasMatch(parts[offset])) offset--;
      if (offset - 1 >= 0)
        city = parts[offset - 1].replaceAll(RegExp(r'\d'), '').trim();
      if (city.isNotEmpty) {
        locCounts[city] = (locCounts[city] ?? 0) + 1;
      }
    }
  }

  double prevTotalRev = 0;
  for (var ride in prevRides) {
    prevTotalRev += (ride['fareEstimate'] as num?)?.toDouble() ?? 0.0;
  }

  final topLocs = locCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Chart Logic
  List<double> chartData = [];
  List<String> chartLabels = [];

  if (filter.period == RevenuePeriod.day) {
    // 24 buckets
    chartData = List.filled(24, 0.0);
    chartLabels = List.generate(
      24,
      (i) => i % 6 == 0
          ? '${i == 0
                ? 12
                : i > 12
                ? i - 12
                : i} ${i >= 12 ? 'PM' : 'AM'}'
          : '',
    );
    for (var ride in rides) {
      final dt = (ride['createdAt'] as dynamic)?.toDate() as DateTime?;
      if (dt != null) {
        chartData[dt.hour] += (ride['fareEstimate'] as num?)?.toDouble() ?? 0.0;
      }
    }
  } else if (filter.period == RevenuePeriod.month) {
    final daysInMonth = DateTime(
      filter.selectedDate.year,
      filter.selectedDate.month + 1,
      0,
    ).day;
    chartData = List.filled(daysInMonth, 0.0);
    chartLabels = List.generate(
      daysInMonth,
      (i) => (i + 1) % 5 == 1 ? '${i + 1}' : '',
    );
    for (var ride in rides) {
      final dt = (ride['createdAt'] as dynamic)?.toDate() as DateTime?;
      if (dt != null) {
        chartData[dt.day - 1] +=
            (ride['fareEstimate'] as num?)?.toDouble() ?? 0.0;
      }
    }
  } else {
    // Year (12 months)
    chartData = List.filled(12, 0.0);
    chartLabels = [
      'Jan',
      '',
      'Mar',
      '',
      'May',
      '',
      'Jul',
      '',
      'Sep',
      '',
      'Nov',
      '',
    ];
    for (var ride in rides) {
      final dt = (ride['createdAt'] as dynamic)?.toDate() as DateTime?;
      if (dt != null) {
        chartData[dt.month - 1] +=
            (ride['fareEstimate'] as num?)?.toDouble() ?? 0.0;
      }
    }
  }

  return ProcessedAnalyticsData(
    totalRevenue: totalRev,
    totalRides: rides.length,
    averageFare: rides.isEmpty ? 0 : totalRev / rides.length,
    previousTotalRevenue: prevTotalRev,
    serviceRevenue: svcRev,
    chartData: chartData,
    chartLabels: chartLabels,
    topLocations: topLocs
        .take(5)
        .map((e) => {'name': e.key, 'count': e.value})
        .toList(),
  );
});
