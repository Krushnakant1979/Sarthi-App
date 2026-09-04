import 'package:flutter/material.dart';
import '../admin_design.dart';
import '../admin_dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.onTap,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final String? trend;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AdminColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: AdminColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (trend != null) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        trend!.startsWith('-')
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        color: AdminColors.success,
                        size: 12,
                      ),
                      SizedBox(width: 2),
                      Text(
                        trend!,
                        style: GoogleFonts.inter(
                          color: AdminColors.success,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: context.colors.surface,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children
          .map(
            (c) =>
                Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
          )
          .toList(),
    ),
  );
}

class AdminFilterChip extends StatelessWidget {
  const AdminFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? context.colors.adminAccent : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? context.colors.adminAccent
              : const Color(0xFFD1D5DB),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.black,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 11,
        ),
      ),
    ),
  );
}

class DarkDropdown<T> extends StatelessWidget {
  const DarkDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final String label;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    dropdownColor: context.colors.surface, // White background for popup
    iconEnabledColor: context.colors.textMuted,
    borderRadius: BorderRadius.circular(16), // Rounded corners for popup menu
    elevation: 4,
    itemHeight:
        48, // Reduced height for dropdown items to remove unnecessary space
    style: GoogleFonts.inter(
      color: context.colors.text,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
        color: context.colors.textMuted,
        fontSize: 11,
      ),
      prefixIcon: Icon(icon, color: context.colors.textMuted, size: 18),
      filled: true,
      fillColor: context.colors.surfaceAlt, // Light grey for the field itself
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.adminAccent, width: 2),
      ),
    ),
    items: items,
    onChanged: onChanged,
  );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    style: GoogleFonts.inter(color: context.colors.text, fontSize: 12),
    cursorColor: context.colors.adminAccent,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: context.colors.textMuted,
        fontSize: 12,
      ),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: context.colors.textMuted,
        size: 18,
      ),
      filled: true,
      fillColor: context.colors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.adminAccent, width: 2),
      ),
    ),
  );
}

class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.cardBorder),
          ),
          child: Icon(icon, color: context.colors.textMuted, size: 18),
        ),
      ),
    ),
  );
}

class AsyncPage extends StatelessWidget {
  const AsyncPage({
    super.key,
    required this.loading,
    required this.error,
    required this.child,
  });
  final bool loading;
  final Object? error;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (loading)
      return Center(
        child: CircularProgressIndicator(color: context.colors.adminAccent),
      );
    if (error != null)
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load data',
        subtitle: friendlyError(error!),
      );
    return child;
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Icon(icon, size: 34, color: context.colors.textMuted),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.text,
            ),
          ),
          SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: context.colors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: context.colors.textMuted),
        SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: context.colors.textMuted,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: context.colors.text,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class DividerRow extends StatelessWidget {
  const DividerRow({super.key});
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: context.colors.cardBorder,
    indent: 16,
    endIndent: 16,
  );
}
