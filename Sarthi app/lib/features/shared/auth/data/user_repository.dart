import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import '../domain/app_user.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cloudName = 'rabz3snt';
  static const String _uploadPreset = 'rapido_unsigned';

  Future<void> createUser(AppUser user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AppUser.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  /// Shared Cloudinary upload helper — avoids duplicating Dio/FormData boilerplate.
  Future<String> _uploadToCloudinary(String filename, File imageFile) async {
    final dio = Dio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path, filename: filename),
      'upload_preset': _uploadPreset,
    });

    try {
      final response = await dio.post(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
        data: formData,
      );
      if (response.statusCode == 200) {
        return response.data['secure_url'] as String;
      } else {
        throw Exception('Failed to upload image: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Cloudinary Error: ${e.response?.data}');
      }
      throw Exception('Cloudinary Network Error: ${e.message}');
    } catch (e) {
      throw Exception('Cloudinary Upload Error: $e');
    }
  }

  Future<String> uploadProfilePicture(String uid, File imageFile) async {
    return _uploadToCloudinary('$uid.jpg', imageFile);
  }

  Future<String> uploadDocument(
    String uid,
    String docType,
    File imageFile,
  ) async {
    return _uploadToCloudinary('${uid}_$docType.jpg', imageFile);
  }

  Future<void> createSupportTicket(
    String uid,
    String role,
    String subject,
    String message,
  ) async {
    await _firestore.collection('support_tickets').add({
      'userId': uid,
      'reporterRole': role,
      'subject': subject,
      'message': message,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamMyTickets(String uid) {
    return _firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final tickets = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort in Dart to avoid needing a composite index in Firestore
          tickets.sort((a, b) {
            final aTime =
                (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bTime =
                (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime); // descending
          });

          return tickets;
        });
  }
}
