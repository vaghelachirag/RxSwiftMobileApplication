

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/delivery_confirm/provider/delivery_confirmation_provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/camera_capture_area.dart';
import '../../widgets/instruction_card.dart';
import '../../widgets/location_info_card.dart';
import '../../widgets/order_summary_card.dart';
import '../../widgets/upload_status_banner.dart';
import 'domain/delivery_state.dart';


class DeliveryConfirmationScreen extends ConsumerWidget {
  const DeliveryConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deliveryControllerProvider);
    final controller = ref.read(deliveryControllerProvider.notifier);
    final order = ref.watch(deliveryOrderProvider);

    // Surface success as a one-off SnackBar.
    ref.listen<DeliveryState>(deliveryControllerProvider, (prev, next) {
      if (prev?.status != DeliveryStatus.uploadSuccess &&
          next.status == DeliveryStatus.uploadSuccess) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              content: Text('Delivery confirmed successfully.'),
            ),
          );
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Delivery Confirmation'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive max width so it looks good on large phones / tablets.
            final maxW = constraints.maxWidth > 520 ? 520.0 : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OrderSummaryCard(order: order),
                      const SizedBox(height: AppSpacing.lg),
                      const InstructionCard(),
                      const SizedBox(height: AppSpacing.lg),
                      CameraCaptureArea(
                        state: state,
                        onOpenCamera: controller.openCamera,
                        onRetake: controller.retakePhoto,
                      ),
                      if (state.hasPhoto) ...[
                        const SizedBox(height: AppSpacing.lg),
                        LocationInfoCard(
                          state: state,
                          onRetryLocation: controller.retryLocation,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      UploadStatusBanner(
                        state: state,
                        onRetry: state.isOfflinePending
                            ? controller.retryPendingUpload
                            : controller.retryUpload,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomActionBar(
        state: state,
        onOpenCamera: controller.openCamera,
        onComplete: controller.uploadAndComplete,
        onDone: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.state,
    required this.onOpenCamera,
    required this.onComplete,
    required this.onDone,
  });

  final DeliveryState state;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    // Success → a single "Done" button.
    if (state.isSuccess) {
      return _BarWrapper(
        child: _PrimaryButton(
          label: 'Done',
          icon: Icons.check,
          color: AppColors.accentGreen,
          onPressed: onDone,
        ),
      );
    }

    // No photo yet → primary CTA is "Take Photo".
    if (!state.hasPhoto) {
      return _BarWrapper(
        child: _PrimaryButton(
          label: 'Take Photo',
          icon: Icons.camera_alt,
          color: AppColors.primary,
          // Disabled while the camera is opening to prevent double launch.
          onPressed: state.status == DeliveryStatus.cameraOpening
              ? null
              : onOpenCamera,
        ),
      );
    }

    // Photo captured → "Upload & Complete Delivery".
    // Disabled while uploading.
    final bool enabled = state.canComplete;
    return _BarWrapper(
      child: _PrimaryButton(
        label: state.isUploading
            ? 'Uploading…'
            : 'Upload & Complete Delivery',
        icon: state.isUploading ? null : Icons.check_circle_outline,
        color: AppColors.accentGreen,
        loading: state.isUploading,
        onPressed: enabled ? onComplete : null,
      ),
    );
  }
}

class _BarWrapper extends StatelessWidget {
  const _BarWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: child,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.color,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: const Color(0xFFCBD5DF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (loading || icon != null) const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
