import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/message_notification_provider.dart';

final appBadgeProvider = StateNotifierProvider<AppBadgeNotifier, BadgeState>((ref) {
  return AppBadgeNotifier(ref);
});

class BadgeState {
  final int count;
  final bool isFlashing;
  
  BadgeState({this.count = 0, this.isFlashing = false});
  
  BadgeState copyWith({int? count, bool? isFlashing}) {
    return BadgeState(
      count: count ?? this.count,
      isFlashing: isFlashing ?? this.isFlashing,
    );
  }
}

class AppBadgeNotifier extends StateNotifier<BadgeState> {
  final Ref _ref;
  Timer? _flashTimer;
  
  AppBadgeNotifier(this._ref) : super(BadgeState()) {
    _ref.listen(messageNotificationProvider, (prev, next) {
      final count = next.length;
      state = state.copyWith(count: count, isFlashing: count > 0);
      if (count > 0) {
        startFlashing();
      } else {
        stopFlashing();
      }
    });
  }
  
  void startFlashing() {
    if (_flashTimer != null) return;
    _flashTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      state = state.copyWith(isFlashing: !state.isFlashing);
    });
  }
  
  void stopFlashing() {
    _flashTimer?.cancel();
    _flashTimer = null;
    state = state.copyWith(isFlashing: false);
  }
  
  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }
}

class AnimatedAppIcon extends ConsumerWidget {
  final Widget child;
  
  const AnimatedAppIcon({super.key, required this.child});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeState = ref.watch(appBadgeProvider);
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (badgeState.count > 0)
          Positioned(
            right: -8,
            top: -8,
            child: AnimatedOpacity(
              opacity: badgeState.isFlashing ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  badgeState.count > 99 ? '99+' : '${badgeState.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}