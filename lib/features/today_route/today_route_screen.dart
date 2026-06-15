import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/today_route/provider/today_route_provider.dart';
import 'package:rxswift/features/today_route/route_map/screen/route_map_screen.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_progress_dialoug.dart';
import 'model/route_model.dart';

class TodayRouteScreen extends ConsumerWidget {
  const TodayRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayRouteProvider);
    final notifier = ref.read(todayRouteProvider.notifier);

    // Show availability error as SnackBar and immediately clear it.
    ref.listen<TodayRouteState>(todayRouteProvider, (previous, next) {
      final msg = next.availabilityErrorMessage;
      if (msg != null &&
          msg != previous?.availabilityErrorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _RouteAppBar(state: state, notifier: notifier),
        body: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _buildBody(state, notifier),
          ),
        ),
        bottomNavigationBar: (state.isAvailable && state.isLoaded)
            ? _BottomBar(
          state: state,
          onStart: () async {
            await notifier.startRoute();
            if (context.mounted) {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const RouteMapScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
            }
          },
        )
            : null,
      ),
    );
  }

  Widget _buildBody(TodayRouteState state, TodayRouteNotifier notifier) {
    // Driver is unavailable — show the prompt.
    if (!state.isAvailable) {
      return const _AvailabilityRequiredView(key: ValueKey('unavailable'));
    }

    // Driver is available — show normal load/error/content states.
    if (state.isLoading) {
      return const _LoadingView(key: ValueKey('loading'));
    }

    if (state.isError) {
      return _ErrorView(
        key: const ValueKey('error'),
        message: state.errorMessage ?? 'Something went wrong.',
        onRetry: notifier.refresh,
      );
    }

    if (state.isLoaded) {
      return _RouteBody(key: const ValueKey('body'), state: state);
    }

    // Fallback while availability was just toggled ON and loadRoute starts.
    return const _LoadingView(key: ValueKey('loading-fallback'));
  }
}

class TodayRouteScaffold extends StatelessWidget {
  const TodayRouteScaffold({super.key});

  @override
  Widget build(BuildContext context) => const TodayRouteScreen();
}

// ─────────────────────────────────────────────────────────────
//  AppBar  (with availability switch)
// ─────────────────────────────────────────────────────────────

class _RouteAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _RouteAppBar({required this.state, required this.notifier});

  final TodayRouteState state;
  final TodayRouteNotifier notifier;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.textPrimary,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        "Today's Route",
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      titleSpacing: 0,
      centerTitle: false,
      actions: [
        _AvailabilitySwitch(state: state, notifier: notifier),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Availability switch widget (label + toggle)
// ─────────────────────────────────────────────────────────────

class _AvailabilitySwitch extends StatelessWidget {
  const _AvailabilitySwitch({required this.state, required this.notifier});

  final TodayRouteState state;
  final TodayRouteNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final isOn = state.isAvailable;
    final isUpdating = state.isAvailabilityUpdating;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isUpdating
              ? const SizedBox(
            key: ValueKey('spinner'),
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          )
              : Text(
            key: ValueKey(isOn),
            isOn ? 'Available' : 'Offline',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOn ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Transform.scale(
          scale: 0.80,
          child: Switch.adaptive(
            value: isOn,
            onChanged: isUpdating ? null : notifier.toggleAvailability,
            activeColor: AppColors.primary,
            inactiveThumbColor: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Availability required view
// ─────────────────────────────────────────────────────────────

class _AvailabilityRequiredView extends StatelessWidget {
  const _AvailabilityRequiredView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.toggle_off_rounded,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'You are currently offline',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please turn on availability to find today\'s task list.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Loading
// ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppProgressLoader(
      message: "Loading today's route...",
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Error
// ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry',
                  style: TextStyle(fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Main Body
// ─────────────────────────────────────────────────────────────

class _RouteBody extends ConsumerWidget {
  const _RouteBody({super.key, required this.state});
  final TodayRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = state.route!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sub-header ────────────────────────────────────────
        _SubHeader(route: route),

        const SizedBox(height: 8),

        // ── Timeline list ─────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: route.stops.length,
            itemBuilder: (context, index) {
              final stop = route.stops[index];
              final isFirst = index == 0;
              final isLast = index == route.stops.length - 1;
              return _TimelineStop(
                stop: stop,
                isFirst: isFirst,
                isLast: isLast,
                isRouteActive: state.isRouteActive,
                onMarkDone: () => ref
                    .read(todayRouteProvider.notifier)
                    .markStopCompleted(stop.id),
                onOpenMaps: () async {
                  final ok = await ref
                      .read(todayRouteProvider.notifier)
                      .openInGoogleMaps(stop);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open Google Maps.'),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Sub-header  "4 Stops · 10:00 PM Pickup"
// ─────────────────────────────────────────────────────────────

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.route});
  final TodayRoute route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Text(
        '${route.totalStops} Stops · ${route.pickupTime} Pickup',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Timeline Stop  (number bubble + connector line + card)
// ─────────────────────────────────────────────────────────────

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.isRouteActive,
    required this.onMarkDone,
    required this.onOpenMaps,
  });

  final RouteStop stop;
  final bool isFirst;
  final bool isLast;
  final bool isRouteActive;
  final VoidCallback onMarkDone;
  final VoidCallback onOpenMaps;

  Color get _bubbleColor {
    switch (stop.status) {
      case StopStatus.completed:
        return AppColors.success;
      case StopStatus.inProgress:
        return AppColors.teal;
      case StopStatus.skipped:
        return AppColors.textSecondary;
      case StopStatus.pending:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = stop.status == StopStatus.completed;
    final isInProgress = stop.status == StopStatus.inProgress;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline column (connector + centered bubble) ────
          SizedBox(
            width: 36,
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: CustomPaint(
                painter: _TimelinePainter(
                  lineColor: AppColors.border,
                  drawTopHalf: !isFirst,
                  drawBottomHalf: !isLast,
                ),
                child: Center(
                  child: _NumberBubble(
                    number: stop.stopNumber,
                    color: _bubbleColor,
                    isCompleted: isCompleted,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Card ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: _StopCard(
                stop: stop,
                isInProgress: isInProgress,
                isCompleted: isCompleted,
                onMarkDone: onMarkDone,
                onTap: onOpenMaps,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Timeline Painter
// ─────────────────────────────────────────────────────────────

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.lineColor,
    required this.drawTopHalf,
    required this.drawBottomHalf,
  });

  final Color lineColor;
  final bool drawTopHalf;
  final bool drawBottomHalf;

  static const double _bubbleRadius = 15;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    if (drawTopHalf) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, centerY - _bubbleRadius - 2),
        paint,
      );
    }
    if (drawBottomHalf) {
      canvas.drawLine(
        Offset(centerX, centerY + _bubbleRadius + 2),
        Offset(centerX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.lineColor != lineColor ||
          old.drawTopHalf != drawTopHalf ||
          old.drawBottomHalf != drawBottomHalf;
}

// ─────────────────────────────────────────────────────────────
//  Stop Card
// ─────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.isInProgress,
    required this.isCompleted,
    required this.onMarkDone,
    required this.onTap,
  });

  final RouteStop stop;
  final bool isInProgress;
  final bool isCompleted;
  final VoidCallback onMarkDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isInProgress
                  ? AppColors.teal.withOpacity(0.40)
                  : AppColors.border.withOpacity(0.60),
              width: isInProgress ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Name + Address ─────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stop.patientName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.address,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isInProgress) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 30,
                        child: ElevatedButton.icon(
                          onPressed: onMarkDone,
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text(
                            'Mark as Done',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── Pickup/Drop label + tap-to-navigate affordance ──
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TypeChip(type: stop.stopType, dimmed: isCompleted),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.directions_rounded,
                    size: 18,
                    color: isCompleted
                        ? AppColors.textHint
                        : AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Pickup / Drop chip
// ─────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.dimmed});
  final StopType type;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final isPickup = type == StopType.pickup;
    final base = isPickup ? AppColors.success : AppColors.primary;
    final color = dimmed ? AppColors.textHint : base;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Number Bubble  (filled circle with number or ✓)
// ─────────────────────────────────────────────────────────────

class _NumberBubble extends StatelessWidget {
  const _NumberBubble({
    required this.number,
    required this.color,
    required this.isCompleted,
  });

  final int number;
  final Color color;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text(
          '$number',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom Bar  (Start Route)
// ─────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.onStart});
  final TodayRouteState state;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isStarting = state.startStatus == RouteStartStatus.starting;
    final isActive = state.isRouteActive;
    final isCompleted = state.isRouteCompleted;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (isStarting || isCompleted) ? null : onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: isCompleted
                ? AppColors.success
                : isActive
                ? AppColors.teal
                : AppColors.primary,
            disabledBackgroundColor: isCompleted
                ? AppColors.success.withOpacity(0.70)
                : AppColors.primary.withOpacity(0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            elevation: 0,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isStarting
                ? const SizedBox(
              key: ValueKey('loader'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : Text(
              isCompleted
                  ? 'Route Completed!'
                  : isActive
                  ? 'Route In Progress'
                  : 'Start Route',
              key: ValueKey(state.startStatus),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}