import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/route_details/route_detail_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../today_route/model/route_model.dart';

// ─────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────

class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key, required this.stop});

  final RouteStop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routeDetailProvider(stop.orderId));
    final notifier = ref.read(routeDetailProvider(stop.orderId).notifier);

    final isPickup = stop.stopType == StopType.pickup;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // ── AppBar ─────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Tasks',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          titleSpacing: 0,
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                isPickup ? 'Pick up Task' : 'Drop off Task',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),

        // ── Fixed bottom buttons ────────────────────────────────
        bottomNavigationBar: _BottomActions(
          stop: stop,
          isNavigating: state.isNavigating,
          isArriving: state.isArriving,
          onNavigate: () => _onNavigate(context, ref, notifier),
          onArrived: () => _onArrived(context, ref, notifier),
        ),

        // ── Scrollable body ─────────────────────────────────────
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              const _SectionHeader(title: 'Details'),
              const SizedBox(height: 12),

              // Detail card
              _DetailCard(stop: stop),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigate: open Google Maps ──────────────────────────────────

  Future<void> _onNavigate(
      BuildContext context,
      WidgetRef ref,
      RouteDetailNotifier notifier,
      ) async {
    if (ref.read(routeDetailProvider(stop.orderId)).isNavigating) return;
    notifier.setNavigating(true);

    final opened = await notifier.openInGoogleMaps(stop);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps',
              style: TextStyle(fontFamily: 'Poppins')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    notifier.setNavigating(false);
  }

  // ── Arrived: pop back with result so caller can act ───────────

  Future<void> _onArrived(
      BuildContext context,
      WidgetRef ref,
      RouteDetailNotifier notifier,
      ) async {
    if (ref.read(routeDetailProvider(stop.orderId)).isArriving) return;
    notifier.setArriving(true);

    // Pop with `true` so the list screen can mark the stop arrived / trigger
    // the pickup or delivery confirmation flow.
    if (context.mounted) Navigator.of(context).pop(true);
  }
}

// ─────────────────────────────────────────────────────────────
//  Section Header  "Details"
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Detail Card
// ─────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.stop});
  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final isPickup = stop.stopType == StopType.pickup;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Company / Pharmacy Name ──────────────────────────
          _DetailRow(
            label: 'Company Name',
            value: stop.pharmacyName.isNotEmpty ? stop.pharmacyName : 'N/A',
          ),
          _Divider(),

          // ── Address ──────────────────────────────────────────
          _DetailRow(
            label: 'Address',
            value: stop.address.isNotEmpty ? stop.address : 'N/A',
            trailing: stop.hasCoordinates
                ? _CopyIcon(text: stop.address)
                : null,
          ),
          _Divider(),

          // ── Suite ────────────────────────────────────────────
          _DetailRow(label: 'Suite', value: 'N/A'),
          _Divider(),

          // ── Order Placed By ──────────────────────────────────
          _DetailRow(
            label: 'Order Placed By',
            value: stop.pharmacyName.isNotEmpty ? stop.pharmacyName : 'N/A',
          ),
          _Divider(),

          // ── Order Tracking # ─────────────────────────────────
          _DetailRow(
            label: 'Order Tracking #',
            value: stop.orderNumber.isNotEmpty ? stop.orderNumber : 'N/A',
          ),
          _Divider(),

          // ── Customer Reference # ─────────────────────────────
          _DetailRow(label: 'Customer Reference #', value: 'N/A'),
          _Divider(),

          // ── Service Type ─────────────────────────────────────
          _DetailRow(label: 'Service Type', value: '- Regular'),
          _Divider(),

          // ── Contact Name ─────────────────────────────────────
          _DetailRow(
            label: 'Contact Name',
            value: stop.patientName.isNotEmpty ? stop.patientName : 'N/A',
          ),
          _Divider(),

          // ── Pick up time ─────────────────────────────────────
          _DetailRow(
            label: 'Pick up time',
            value: 'Ready by 11:10 AM',
          ),
          _Divider(),

          // ── Task ─────────────────────────────────────────────
          _DetailRow(
            label: 'Task',
            value: isPickup ? 'Pick up' : 'Drop off',
          ),
          _Divider(),

          // ── Package Size ─────────────────────────────────────
          _DetailRow(label: 'Package Size', value: 'N/A'),
          _Divider(),

          // ── Package Type ─────────────────────────────────────
          _DetailRow(label: 'Package Type', value: 'N/A'),
          _Divider(),

          // ── Weight ───────────────────────────────────────────
          _DetailRow(label: 'Weight', value: 'N/A'),
          _Divider(),

          // ── Package Description ──────────────────────────────
          _DetailRow(label: 'Package Description', value: 'N/A'),
          _Divider(),

          // ── Quantity ─────────────────────────────────────────
          _DetailRow(label: 'Quantity', value: 'N/A'),
          _Divider(),

          // ── Phone ────────────────────────────────────────────
          _DetailRow(
            label: 'Phone',
            value: stop.patientPhone.isNotEmpty ? stop.patientPhone : 'N/A',
            trailing: stop.patientPhone.isNotEmpty
                ? _PhoneActions(phone: stop.patientPhone)
                : null,
          ),

          // ── Notes (only if present) ──────────────────────────
          if (stop.notes != null && stop.notes!.isNotEmpty) ...[
            _Divider(),
            _DetailRow(
              label: 'Notes',
              value: stop.notes!,
              valueColor: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Single detail row
// ─────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Thin divider between rows
// ─────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Copy address icon
// ─────────────────────────────────────────────────────────────

class _CopyIcon extends StatelessWidget {
  const _CopyIcon({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address copied', style: TextStyle(fontFamily: 'Poppins')),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Phone action icons (call + message)
// ─────────────────────────────────────────────────────────────

class _PhoneActions extends StatelessWidget {
  const _PhoneActions({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PhoneIconButton(
          icon: Icons.phone_rounded,
          onTap: () => _launch('tel:$phone'),
        ),
        const SizedBox(width: 8),
        _PhoneIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => _launch('sms:$phone'),
        ),
      ],
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _PhoneIconButton extends StatelessWidget {
  const _PhoneIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Fixed bottom action bar
// ─────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.stop,
    required this.isNavigating,
    required this.isArriving,
    required this.onNavigate,
    required this.onArrived,
  });

  final RouteStop stop;
  final bool isNavigating;
  final bool isArriving;
  final VoidCallback onNavigate;
  final VoidCallback onArrived;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // ── Navigate ────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isNavigating ? null : onNavigate,
                icon: isNavigating
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : const Icon(Icons.navigation_rounded, size: 18),
                label: const Text(
                  'Navigate',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Arrived ─────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isArriving ? null : onArrived,
                icon: isArriving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text(
                  'Arrived',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  const Color(0xFF1A1A2E).withOpacity(0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}