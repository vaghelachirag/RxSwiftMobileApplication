import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/today_route/provider/today_route_provider.dart';

import '../../model/route_model.dart';
import '../../theme/app_theme.dart';
import '../navigation/navigation_screen.dart';



class TodayRouteScreen extends ConsumerWidget {
  const TodayRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayRouteProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _RouteAppBar(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: state.isLoading
              ? const _LoadingView()
              : state.isLoaded
              ? _RouteBody(state: state)
              : const _LoadingView(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  AppBar
// ─────────────────────────────────────────────────────────────

class _RouteAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.primary,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Route",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      titleSpacing: 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Loading
// ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        strokeWidth: 2.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Main Body
// ─────────────────────────────────────────────────────────────

class _RouteBody extends ConsumerWidget {
  const _RouteBody({required this.state});
  final TodayRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = state.route!;

    return Column(
      children: [
        // ── Sub-header ────────────────────────────────────────
        _SubHeader(route: route, completedStops: state.completedStops),

        // ── Progress bar (shown when route is active) ─────────
        if (state.isRouteActive)
          _ProgressBar(
            completed: state.completedStops,
            total: route.totalStops,
          ),

        // ── Stops list ────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            itemCount: route.stops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final stop = route.stops[index];
              return _StopCard(
                stop: stop,
                isRouteActive: state.isRouteActive,
                onMarkDone: () => ref
                    .read(todayRouteProvider.notifier)
                    .markStopCompleted(stop.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Sub-header  "4 Stops • 10:00 PM Pickup"
// ─────────────────────────────────────────────────────────────

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.route, required this.completedStops});
  final TodayRoute route;
  final int completedStops;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _Chip(
            icon: Icons.location_on_rounded,
            label: '${route.totalStops} Stops',
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _Chip(
            icon: Icons.access_time_rounded,
            label: '${route.pickupTime} Pickup',
            color: AppColors.teal,
          ),
          if (completedStops > 0) ...[
            const SizedBox(width: 10),
            _Chip(
              icon: Icons.check_circle_outline_rounded,
              label: '$completedStops/${route.totalStops} Done',
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Progress bar
// ─────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.completed, required this.total});
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Route Progress',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$completed of $total stops',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stop Card
// ─────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.isRouteActive,
    required this.onMarkDone,
  });

  final RouteStop stop;
  final bool isRouteActive;
  final VoidCallback onMarkDone;

  Color get _numberColor {
    switch (stop.status) {
      case StopStatus.completed:
        return AppColors.success;
      case StopStatus.inProgress:
        return AppColors.teal;
      case StopStatus.skipped:
        return AppColors.textSecondary;
      case StopStatus.pending:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = stop.status == StopStatus.completed;
    final isInProgress = stop.status == StopStatus.inProgress;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isInProgress
            ? AppColors.primary.withOpacity(0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isInProgress
              ? AppColors.teal.withOpacity(0.45)
              : isCompleted
              ? AppColors.success.withOpacity(0.30)
              : AppColors.border,
          width: isInProgress ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stop number bubble ──────────────────────────
            _NumberBubble(
              number: stop.stopNumber,
              color: _numberColor,
              isCompleted: isCompleted,
            ),

            const SizedBox(width: 14),

            // ── Patient info ────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      decorationColor: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          stop.address,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (isInProgress) ...[
                    const SizedBox(height: 10),
                    // "Mark as Done" button shown for in-progress stop
                    SizedBox(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: onMarkDone,
                        icon: const Icon(Icons.check_rounded, size: 15),
                        label: const Text(
                          'Mark as Done',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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

            // ── Scheduled time ──────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stop.scheduledTime,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _StatusBadge(status: stop.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Number Bubble  (1 / 2 / 3 / 4 or ✓)
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
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check_rounded, size: 18, color: color)
            : Text(
          '$number',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Status Badge
// ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final StopStatus status;

  String get _label {
    switch (status) {
      case StopStatus.completed:
        return 'Done';
      case StopStatus.inProgress:
        return 'Active';
      case StopStatus.skipped:
        return 'Skipped';
      case StopStatus.pending:
        return 'Pending';
    }
  }

  Color get _color {
    switch (status) {
      case StopStatus.completed:
        return AppColors.success;
      case StopStatus.inProgress:
        return AppColors.teal;
      case StopStatus.skipped:
        return AppColors.textSecondary;
      case StopStatus.pending:
        return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Start Route FAB  (bottom fixed button)
// ─────────────────────────────────────────────────────────────

// Wrap TodayRouteScreen in a Scaffold with a bottom button via bottomNavigationBar
// We override the full screen using a Stack approach in a wrapper:

class TodayRouteScaffold extends ConsumerWidget {
  const TodayRouteScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayRouteProvider);
    final notifier = ref.read(todayRouteProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _RouteAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: state.isLoading
            ? const _LoadingView()
            : state.isLoaded
            ? _RouteBody(state: state)
            : const _LoadingView(),
      ),
      bottomNavigationBar: state.isLoaded
          ? _BottomBar(
        state: state,
        onStart: () async {
          await notifier.startRoute();
          if (context.mounted) {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                const NavigationMapScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration:
                const Duration(milliseconds: 400),
              ),
            );
          }
        },
      )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom Bar
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
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
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
                : AppColors.disabledBg,
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
                : Row(
              key: ValueKey(state.startStatus),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : isActive
                      ? Icons.navigation_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted
                      ? 'Route Completed!'
                      : isActive
                      ? 'Route In Progress'
                      : 'Start Route',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}