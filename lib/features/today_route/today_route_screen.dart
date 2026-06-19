import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/today_route/provider/today_route_provider.dart';
import 'package:rxswift/features/today_route/route_map/screen/route_map_screen.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_progress_dialoug.dart';
import '../route_details/route_detail_screen.dart';
import 'model/route_model.dart';


class TodayRouteScreen extends ConsumerWidget {
  const TodayRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todayRouteProvider);
    final notifier = ref.read(todayRouteProvider.notifier);

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

      final acceptMsg = next.acceptErrorMessage;
      if (acceptMsg != null &&
          acceptMsg != previous?.acceptErrorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content:
              Text(acceptMsg, style: const TextStyle(fontFamily: 'Poppins')),
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
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar: availability toggle ──────────────────
              _TopBar(state: state, notifier: notifier),

              // ── Page header ───────────────────────────────────
              if (state.isAvailable && state.isLoaded)
                _PageHeader(
                  totalStops: state.hasUnacceptedOrders
                      ? state.unacceptedOrders.length
                      : (state.route?.totalStops ?? 0),
                ),

              // ── Body ──────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _buildBody(context, state, notifier, ref),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: !(state.isAvailable && state.isLoaded)
            ? null
            : state.hasUnacceptedOrders
            ? _AcceptOrderBottomBar(
          state: state,
          onAccept: notifier.acceptAllUnacceptedOrders,
        )
            : _BottomBar(
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
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TodayRouteState state,
      TodayRouteNotifier notifier, WidgetRef ref) {
    if (!state.isAvailable) {
      return const _AvailabilityRequiredView(key: ValueKey('unavailable'));
    }
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
      if (state.hasUnacceptedOrders) {
        return _UnacceptedOrdersBody(
          key: const ValueKey('unaccepted'),
          orders: state.unacceptedOrders,
        );
      }
      return _RouteBody(key: const ValueKey('body'), state: state);
    }
    return const _LoadingView(key: ValueKey('loading-fallback'));
  }
}

class TodayRouteScaffold extends StatelessWidget {
  const TodayRouteScaffold({super.key});

  @override
  Widget build(BuildContext context) => const TodayRouteScreen();
}

// ─────────────────────────────────────────────────────────────
//  Top Bar  (availability toggle, no title here)
// ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.notifier});
  final TodayRouteState state;
  final TodayRouteNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final isOn = state.isAvailable;
    final isUpdating = state.isAvailabilityUpdating;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Invisible spacer to balance layout
          const SizedBox(width: 80),

          // ── Availability toggle (centered) ────────────────────
          Row(
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
                    valueColor:
                    AlwaysStoppedAnimation(AppColors.primary),
                  ),
                )
                    : Text(
                  key: ValueKey(isOn),
                  isOn ? 'Available' : 'Offline',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOn
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: isOn,
                  onChanged: isUpdating ? null : notifier.toggleAvailability,
                  activeColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // ── Right placeholder (notification bell or avatar) ───
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 20, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Page Header  "Tasks / Today (N)"
// ─────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.totalStops});
  final int totalStops;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tasks',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Today ($totalStops)',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Availability Required View
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
//  Main Body  (grouped list)
// ─────────────────────────────────────────────────────────────

class _RouteBody extends ConsumerWidget {
  const _RouteBody({super.key, required this.state});
  final TodayRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = state.route!;
    final stops = route.stops;

    // Build a list of items: groups of stops by storeName (or patientName
    // when there's no store). Each group shows a "X more tasks" separator
    // between the first stop and the rest, mirroring the target design.
    final List<_ListItem> items = _buildItems(stops);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        switch (item) {
          case _StopItem(:final stop, :final isFirst, :final isLast):
            return _TaskCard(
              stop: stop,
              isFirst: isFirst,
              isLast: isLast,
              isRouteActive: state.isRouteActive,
              onMarkDone: () => ref
                  .read(todayRouteProvider.notifier)
                  .markStopCompleted(stop.id),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RouteDetailScreen(stop: stop),
                  ),
                );
              },
            );
          case _CollapseItem(:final count, :final groupLabel):
            return _MoreTasksDivider(count: count, label: groupLabel);
        }
      },
    );
  }

  List<_ListItem> _buildItems(List<RouteStop> stops) {
    if (stops.isEmpty) return [];

    // Group consecutive stops that share the same store/patient name.
    final groups = <_StopGroup>[];
    _StopGroup? current;

    for (final stop in stops) {
      final key = stop.patientName; // use patientName as group key
      if (current == null || current.key != key) {
        current = _StopGroup(key: key, stops: [stop]);
        groups.add(current);
      } else {
        current.stops.add(stop);
      }
    }

    final items = <_ListItem>[];
    for (final group in groups) {
      final groupStops = group.stops;
      for (int i = 0; i < groupStops.length; i++) {
        final isFirst = i == 0;
        final isLast = i == groupStops.length - 1;

        // After the first stop in a group, insert the "X more tasks" banner
        // before the remaining stops (only when the group has > 1 stop).
        if (i == 1 && groupStops.length > 1) {
          items.add(_CollapseItem(
            count: groupStops.length - 1,
            groupLabel: group.key,
          ));
        }

        items.add(_StopItem(
          stop: groupStops[i],
          isFirst: isFirst,
          isLast: isLast,
        ));
      }
    }
    return items;
  }
}

// ── List item sealed types ────────────────────────────────────

sealed class _ListItem {}

class _StopItem extends _ListItem {
  _StopItem({required this.stop, required this.isFirst, required this.isLast});
  final RouteStop stop;
  final bool isFirst;
  final bool isLast;
}

class _CollapseItem extends _ListItem {
  _CollapseItem({required this.count, required this.groupLabel});
  final int count;
  final String groupLabel;
}

class _StopGroup {
  _StopGroup({required this.key, required this.stops});
  final String key;
  final List<RouteStop> stops;
}

// ─────────────────────────────────────────────────────────────
//  "X more tasks" divider row
// ─────────────────────────────────────────────────────────────

class _MoreTasksDivider extends StatelessWidget {
  const _MoreTasksDivider({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            child: Divider(color: AppColors.border, thickness: 1),
          ),
          const SizedBox(width: 8),
          Text(
            '$count more task${count > 1 ? 's' : ''}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Task Card  (matches target screenshot style)
// ─────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.isRouteActive,
    required this.onMarkDone,
    required this.onTap,
  });

  final RouteStop stop;
  final bool isFirst;
  final bool isLast;
  final bool isRouteActive;
  final VoidCallback onMarkDone;
  final VoidCallback onTap;

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
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
                    ? AppColors.teal.withOpacity(0.35)
                    : AppColors.border.withOpacity(0.70),
                width: isInProgress ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status bubble ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _StatusBubble(
                    color: _bubbleColor,
                    isCompleted: isCompleted,
                  ),
                ),
                const SizedBox(width: 12),

                // ── Content ───────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store / patient name
                      Text(
                        stop.patientName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Address
                      Text(
                        stop.address,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Service type row
                      Text(
                        'Service Type: - Regular',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Order number + chip + ready time
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '#${stop.orderId.length > 8 ? stop.orderId.substring(0, 8) : stop.orderId}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _TypeChip(
                              type: stop.stopType, dimmed: isCompleted),
                          const SizedBox(width: 6),
                          Text(
                            'Ready now',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isCompleted
                                  ? AppColors.textHint
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Mark done button (only when in-progress)
                      if (isInProgress) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 30,
                          child: ElevatedButton.icon(
                            onPressed: onMarkDone,
                            icon:
                            const Icon(Icons.check_rounded, size: 14),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppRadius.full),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ── Maps icon ─────────────────────────────────────
                Icon(
                  Icons.near_me_rounded,
                  size: 20,
                  color:
                  isCompleted ? AppColors.textHint : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Status Bubble  (filled circle with ✓ or empty ring)
// ─────────────────────────────────────────────────────────────

class _StatusBubble extends StatelessWidget {
  const _StatusBubble({required this.color, required this.isCompleted});
  final Color color;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isCompleted ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: isCompleted ? null : Border.all(color: color, width: 2),
      ),
      child: isCompleted
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
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
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
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

// ─────────────────────────────────────────────────────────────
//  Unaccepted Orders  (shown before today's route is loaded)
// ─────────────────────────────────────────────────────────────

class _UnacceptedOrdersBody extends StatelessWidget {
  const _UnacceptedOrdersBody({super.key, required this.orders});
  final List<UnacceptedOrder> orders;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: orders.length,
      itemBuilder: (context, index) =>
          _UnacceptedOrderCard(order: orders[index]),
    );
  }
}

class _UnacceptedOrderCard extends StatelessWidget {
  const _UnacceptedOrderCard({required this.order});
  final UnacceptedOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withOpacity(0.70)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.patientName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (order.priority) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: const Text(
                    'Priority',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _IconLine(
            icon: Icons.storefront_rounded,
            text: order.pharmacyName,
          ),
          const SizedBox(height: 4),
          _IconLine(
            icon: Icons.location_on_rounded,
            text: order.deliveryAddress,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoChip(text: '#${order.orderNumber}'),
              if (order.handlingType.isNotEmpty)
                _InfoChip(text: order.handlingType),
              if (order.pickupWindowLabel.isNotEmpty)
                _InfoChip(text: order.pickupWindowLabel),
              if (order.statusLabel.isNotEmpty)
                _InfoChip(text: order.statusLabel, emphasize: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.maxLines = 1});
  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text, this.emphasize = false});
  final String text;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? AppColors.teal : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom Bar  (Accept Order — swipe)
// ─────────────────────────────────────────────────────────────

class _AcceptOrderBottomBar extends StatelessWidget {
  const _AcceptOrderBottomBar({required this.state, required this.onAccept});
  final TodayRouteState state;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: _SwipeToAcceptButton(
        label: 'Swipe to Accept Order',
        isLoading: state.isAccepting,
        onAccept: onAccept,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Swipe-to-accept slider control
// ─────────────────────────────────────────────────────────────

class _SwipeToAcceptButton extends StatefulWidget {
  const _SwipeToAcceptButton({
    required this.label,
    required this.isLoading,
    required this.onAccept,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onAccept;

  @override
  State<_SwipeToAcceptButton> createState() => _SwipeToAcceptButtonState();
}

class _SwipeToAcceptButtonState extends State<_SwipeToAcceptButton> {
  static const double _handleSize = 48;
  static const double _trackPadding = 4;
  static const double _acceptThreshold = 0.78;

  double _dragX = 0;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _SwipeToAcceptButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Snap the handle back once a (failed) accept call finishes. On success
    // the parent removes this order/rebuilds the list, so this widget is
    // typically disposed before it matters — this only covers the retry case.
    if (oldWidget.isLoading && !widget.isLoading) {
      setState(() => _dragX = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag =
            constraints.maxWidth - _handleSize - _trackPadding * 2;
        final progress =
        maxDrag <= 0 ? 0.0 : (_dragX / maxDrag).clamp(0.0, 1.0);

        return Container(
          height: 56,
          padding: const EdgeInsets.all(_trackPadding),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.10),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.success.withOpacity(0.25)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: 1 - progress,
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(left: _dragX),
                width: _handleSize,
                height: _handleSize,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: GestureDetector(
                  onHorizontalDragStart: widget.isLoading
                      ? null
                      : (_) => setState(() => _dragging = true),
                  onHorizontalDragUpdate: widget.isLoading || maxDrag <= 0
                      ? null
                      : (details) {
                    setState(() {
                      _dragX =
                          (_dragX + details.delta.dx).clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: widget.isLoading
                      ? null
                      : (_) {
                    final accepted =
                        maxDrag > 0 && _dragX >= maxDrag * _acceptThreshold;
                    setState(() {
                      _dragging = false;
                      _dragX = accepted ? maxDrag : 0;
                    });
                    if (accepted) widget.onAccept();
                  },
                  child: widget.isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}