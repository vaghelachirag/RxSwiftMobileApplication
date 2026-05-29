// ============================================================================
// lib/features/failed_delivery/presentation/screens/failed_delivery_screen.dart
//
// RESTYLED to match route_map_screen.dart — teal AppBar, RouteColors /
// RouteSpacing / RouteRadius / RouteShadows / RouteText tokens, same rhythm.
//
// Only styling changed in THIS file. All providers, controllers, and the
// composed child widgets (OrderSummaryCard, ReasonDropdown, NotesField,
// PhotoGrid, SubmitStatusBanner) are wired exactly as before.
//
// ⚠️ PARTIAL COVERAGE: those child widgets still use AppColors/AppSpacing
//    internally. Send their source files if you want them restyled too.
//
// ⚠️ THEME REQUIREMENTS — your route_map_theme.dart must include:
//    • class RouteSpacing { sm, md, lg, xxl, ... }
//    • RouteRadius.button (14.0)
//    • RouteColors aliases: surface, cardBorder, background, danger,
//                           disabledDanger (or use Color(0xFFEBC9C9) inline)
//    • RouteText.appBar(...) and RouteText.button(...)
//    If any are missing, see the previous reply for the additions to paste.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../route_map/theme/route_map_theme.dart';
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
                SnackBar(
                  backgroundColor: RouteColors.tealDark,
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Failed delivery report submitted.',
                    style: RouteText.body(Colors.white),
                  ),
                ),
              );
          }
        });

    return Scaffold(
      backgroundColor: RouteColors.background,
      appBar: AppBar(
        backgroundColor: RouteColors.tealDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Delivery Failed',
          style: RouteText.appBar(Colors.white),
        ),
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
                    RouteSpacing.lg,
                    RouteSpacing.lg,
                    RouteSpacing.lg,
                    RouteSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OrderSummaryCard(order: order),
                      const SizedBox(height: RouteSpacing.lg),
                      ReasonDropdown(
                        value: state.reason,
                        onChanged: controller.selectReason,
                      ),
                      const SizedBox(height: RouteSpacing.lg),
                      NotesField(
                        initialValue: state.notes,
                        onChanged: controller.updateNotes,
                      ),
                      const SizedBox(height: RouteSpacing.lg),
                      PhotoGrid(
                        photoPaths: state.photoPaths,
                        isCapturing: state.isCapturing,
                        onAdd: controller.addPhoto,
                        onRemove: controller.removePhoto,
                      ),
                      const SizedBox(height: RouteSpacing.lg),
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
            RouteSpacing.lg, RouteSpacing.md, RouteSpacing.lg, RouteSpacing.md),
        decoration: const BoxDecoration(
          color: RouteColors.surface,
          border: Border(top: BorderSide(color: RouteColors.cardBorder)),
          boxShadow: RouteShadows.sheet,
        ),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled ? controller.submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: RouteColors.danger,
              // If you added `disabledDanger` to RouteColors, use it here:
              //   disabledBackgroundColor: RouteColors.disabledDanger,
              // Otherwise leave the inline tint below.
              disabledBackgroundColor: const Color(0xFFEBC9C9),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
                : Text('Submit Report',
                style: RouteText.button(Colors.white)),
          ),
        ),
      ),
    );
  }
}