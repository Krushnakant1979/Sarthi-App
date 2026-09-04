import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? profilePictureUrl;
  final String verificationStatus;
  final String? aadhaarCardUrl;
  final String? drivingLicenceUrl;
  final num ratingScore;
  final int ratingCount;
  final Map<String, dynamic>? homeAddress;
  final Map<String, dynamic>? workAddress;
  final List<Map<String, dynamic>>? recentSearches;
  final String? vehicleType;
  final DateTime createdAt;

  String get publicId {
    if (uid.length < 8) return uid.toUpperCase();
    return uid.substring(0, 8).toUpperCase();
  }

  static String shortId(String uid) {
    if (uid.length < 8) return uid.toUpperCase();
    return uid.substring(0, 8).toUpperCase();
  }

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.role = 'user',
    this.profilePictureUrl,
    this.verificationStatus = 'pending',
    this.aadhaarCardUrl,
    this.drivingLicenceUrl,
    this.ratingScore = 0,
    this.ratingCount = 0,
    this.homeAddress,
    this.workAddress,
    this.recentSearches,
    this.vehicleType,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'profilePictureUrl': profilePictureUrl,
      'verificationStatus': verificationStatus,
      'aadhaarCardUrl': aadhaarCardUrl,
      'drivingLicenceUrl': drivingLicenceUrl,
      'ratingScore': ratingScore,
      'ratingCount': ratingCount,
      'homeAddress': homeAddress,
      'workAddress': workAddress,
      'recentSearches': recentSearches,
      'vehicleType': vehicleType,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      uid: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: map['role'] ?? 'user',
      profilePictureUrl: map['profilePictureUrl'],
      verificationStatus: map['verificationStatus'] ?? 'pending',
      aadhaarCardUrl: map['aadhaarCardUrl'],
      drivingLicenceUrl: map['drivingLicenceUrl'],
      ratingScore: map['ratingScore'] ?? 0,
      ratingCount: map['ratingCount'] ?? 0,
      homeAddress: map['homeAddress'] != null
          ? Map<String, dynamic>.from(map['homeAddress'])
          : null,
      workAddress: map['workAddress'] != null
          ? Map<String, dynamic>.from(map['workAddress'])
          : null,
      recentSearches: map['recentSearches'] != null
          ? List<Map<String, dynamic>>.from(
              (map['recentSearches'] as List).map(
                (e) => Map<String, dynamic>.from(e),
              ),
            )
          : null,
      vehicleType: map['vehicleType'],
      createdAt: _parseDate(map['createdAt']),
    );
  }

  static DateTime _parseDate(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    if (dateStr is DateTime) return dateStr;
    if (dateStr is Timestamp) return dateStr.toDate();
    if (dateStr is String) {
      return DateTime.tryParse(dateStr) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
