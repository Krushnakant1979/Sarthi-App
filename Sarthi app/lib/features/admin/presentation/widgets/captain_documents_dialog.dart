import 'package:flutter/material.dart';
import '../../../auth/domain/app_user.dart';
import '../admin_design.dart';
import 'admin_badges.dart';


class CaptainDocumentsDialog extends StatelessWidget {
  const CaptainDocumentsDialog({super.key, required this.user});
  final AppUser user;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.colors.surfaceAlt, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700), child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.colors.text)),
            Text('Captain Documents', style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
          ])),
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: context.colors.textMuted), style: IconButton.styleFrom(backgroundColor: context.colors.surface)),
        ]),
        const SizedBox(height: 8),
        VerificationBadge(status: user.verificationStatus),
        const SizedBox(height: 20),
        Flexible(child: SingleChildScrollView(child: LayoutBuilder(builder: (_, box) {
          final width = box.maxWidth > 600 ? (box.maxWidth - 12) / 2 : box.maxWidth;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            DocumentPreview(label: 'Aadhaar Card', url: user.aadhaarCardUrl, width: width),
            DocumentPreview(label: 'Driving Licence', url: user.drivingLicenceUrl, width: width),
          ]);
        }))),
      ]),
    )),
  );
}


class DocumentPreview extends StatelessWidget {
  const DocumentPreview({super.key, required this.label, required this.url, required this.width});
  final String label; final String? url; final double width;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.text, fontSize: 13)),
    const SizedBox(height: 8),
    ClipRRect(borderRadius: BorderRadius.circular(16), child: Container(height: 240, color: context.colors.surface, child: url == null
        ? Center(child: Text('Not uploaded', style: TextStyle(color: context.colors.textMuted)))
        : Image.network(url!, fit: BoxFit.contain, width: double.infinity, errorBuilder: (context, error, stackTrace) => Center(child: Text('Could not load document', style: TextStyle(color: context.colors.textMuted)))))),  
  ]));
}
