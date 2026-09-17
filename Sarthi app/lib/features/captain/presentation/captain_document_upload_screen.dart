import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../core/design/tokens.dart';
import '../../shared/auth/presentation/auth_providers.dart';

class CaptainDocumentUploadScreen extends ConsumerStatefulWidget {
  const CaptainDocumentUploadScreen({super.key});

  @override
  ConsumerState<CaptainDocumentUploadScreen> createState() =>
      _CaptainDocumentUploadScreenState();
}

class _CaptainDocumentUploadScreenState
    extends ConsumerState<CaptainDocumentUploadScreen> {
  bool _isLoading = false;
  String? _uploadError;

  String? _aadhaarUrl;
  String? _drivingLicenceUrl;
  String _vehicleType = 'bike';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingDocuments();
    });
  }

  void _loadExistingDocuments() {
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      setState(() {
        _aadhaarUrl = user.aadhaarCardUrl;
        _drivingLicenceUrl = user.drivingLicenceUrl;
      });
    }
  }

  Future<void> _pickAndUploadDocument(String docType) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _uploadError = null;
    });

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Compress image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        image.path,
        minWidth: 800,
        minHeight: 800,
        quality: 75,
      );

      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_$docType.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      // Upload to Storage
      final userRepo = ref.read(userRepositoryProvider);
      final downloadUrl = await userRepo.uploadDocument(
        user.uid,
        docType,
        tempFile,
      );

      setState(() {
        if (docType == 'aadhaar') {
          _aadhaarUrl = downloadUrl;
        } else if (docType == 'dl') {
          _drivingLicenceUrl = downloadUrl;
        }
      });
    } catch (e) {
      setState(() {
        _uploadError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload document: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeRegistration() async {
    if (_aadhaarUrl == null || _drivingLicenceUrl == null) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updateUser(user.uid, {
        'aadhaarCardUrl': _aadhaarUrl,
        'drivingLicenceUrl': _drivingLicenceUrl,
        'vehicleType': _vehicleType,
        'verificationStatus': 'pending_review',
      });

      ref.invalidate(currentUserProvider);

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: context.colors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Registration Successful',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.colors.primary,
              ),
            ),
            content: Text(
              'Your registration is complete.\n\nThe Admin will review and accept your verification request soon. Once approved, you can log into your account.',
              style: TextStyle(color: context.colors.primary, height: 1.5),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.rapidoYellow,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );

        if (mounted) {
          await ref.read(authRepositoryProvider).signOut();
        }
      }
    } catch (e) {
      setState(() => _uploadError = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDocumentCard(
    String title,
    String subtitle,
    String docType,
    String? currentUrl,
  ) {
    final isUploaded = currentUrl != null;

    return GestureDetector(
      onTap: _isLoading ? null : () => _pickAndUploadDocument(docType),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded
                ? const Color(0xFF16A34A)
                : const Color(0xFFE5E7EB),
            width: isUploaded ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUploaded
                    ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUploaded
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: isUploaded
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF6B7280),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isUploaded ? 'Document Uploaded' : subtitle,
                    style: TextStyle(
                      color: isUploaded
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isUploaded)
              const Icon(Icons.check_rounded, color: Color(0xFF16A34A))
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canComplete = _aadhaarUrl != null && _drivingLicenceUrl != null;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text(
          'Document Verification',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            ref.read(authRepositoryProvider).signOut();
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading)
              LinearProgressIndicator(color: context.colors.liveTeal),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almost there!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To ensure the safety of our passengers, we need to verify your legal documents before you can start accepting rides.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4B5563),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildDocumentCard(
                      'Aadhaar Card',
                      'Tap to upload front side',
                      'aadhaar',
                      _aadhaarUrl,
                    ),
                    const SizedBox(height: 16),
                    _buildDocumentCard(
                      'Driving Licence',
                      'Tap to upload front side',
                      'dl',
                      _drivingLicenceUrl,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Vehicle Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _vehicleType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'bike', child: Text('Bike')),
                        DropdownMenuItem(value: 'cab', child: Text('Cab')),
                        DropdownMenuItem(
                          value: 'auto',
                          child: Text('Auto Rickshaw'),
                        ),
                        DropdownMenuItem(
                          value: 'parcel',
                          child: Text('Parcel Delivery'),
                        ),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _vehicleType = value);
                              }
                            },
                    ),

                    if (_uploadError != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.colors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _uploadError!,
                          style: TextStyle(
                            color: context.colors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canComplete && !_isLoading
                      ? _completeRegistration
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    disabledBackgroundColor: context.colors.primary.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Complete Registration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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
