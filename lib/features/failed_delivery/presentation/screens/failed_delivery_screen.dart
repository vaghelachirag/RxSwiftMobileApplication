// ============================================================================
// presentation/screens/failed_delivery_screen.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/failed_delivery_state.dart';
import '../providers/failed_delivery_providers.dart';
import '../widgets/notes_field.dart';
import '../widgets/order_summary_card.dart';
import '../widgets/photo_grid.dart';
import '../widgets/reason_dropdown.dart';
import '../widgets/submit_status_banner.dart';

class FailedDeliveryScreen extends ConsumerWidget {
  const FailedDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(failedDeliveryControllerProvider);
    final controller = ref.read(failedDeliveryControllerProvider.notifier);
    final order = ref.watch(failedDeliveryOrderProvider);

    ref.listen<FailedDeliveryState>(failedDeliveryControllerProvider,
        (prev, next) {
      if (prev?.status != SubmitStatus.submitSuccess &&
          next.status == SubmitStatus.submitSuccess) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              content: Text('Failed delivery report submitted.'),
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
        title: const Text('Delivery Failed'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW =
                constraints.maxWidth > 520 ? 520.0 : constraints.maxWidth;
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
                      ReasonDropdown(
                        value: state.reason,
                        onChanged: controller.selectReason,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      NotesField(
                        initialValue: state.notes,
                        onChanged: controller.updateNotes,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PhotoGrid(
                        photoPaths: state.photoPaths,
                        isCapturing: state.isCapturing,
                        onAdd: controller.addPhoto,
                        onRemove: controller.removePhoto,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SubmitStatusBanner(
                        state: state,
                        onRetry: state.isOfflinePending
                            ? controller.retryPendingSubmit
                            : controller.retrySubmit,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _SubmitBar(state: state, controller: controller),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.state, required this.controller});

  final FailedDeliveryState state;
  final FailedDeliveryController controller;

  @override
  Widget build(BuildContext context) {
    final enabled = state.canSubmit;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled ? controller.submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              disabledBackgroundColor: const Color(0xFFE6B0B0),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: state.isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text(
                    'Submit Report',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }
}
