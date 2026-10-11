import 'dart:async';
import 'package:flutter/widgets.dart';
import '../services/api_result.dart';
import 'session_boundary.dart';

/// Session-owned presentation throttling; never retries requests or mutations.
mixin ProfileCooldownState<T extends StatefulWidget>
    on State<T>, SessionOwnedState<T>
    implements WidgetsBindingObserver {
  DateTime profileNow() => DateTime.now();
  DateTime? _deadline;
  bool _local = false;
  Timer? _timer;
  StreamSubscription<int>? _subscription;
  int get profileWait {
    final ms = _deadline?.difference(profileNow()).inMilliseconds ?? 0;
    return ms > 0 ? (ms / 1000).ceil() : 0;
  }

  String get profileWaitMessage => _local
      ? 'Jeda lokal $profileWait detik; server tidak memberikan waktu reset kuota.'
      : 'Tunggu $profileWait detik sebelum mencoba lagi.';

  void openProfileCooldown() {
    WidgetsBinding.instance.addObserver(this);
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) {
        _timer?.cancel();
        _deadline = null;
      }
    });
  }

  void recordProfileFailure(ApiFailure failure) {
    if (failure.kind != ApiErrorKind.rateLimited) return;
    _local = failure.retryAfter == null && failure.retryAt == null;
    _deadline =
        failure.retryAt ??
        profileNow().add(failure.retryAfter ?? const Duration(seconds: 60));
    _start();
  }

  void _start() {
    _timer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!sessionActive ||
        profileWait == 0 ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!sessionActive || profileWait == 0) _timer?.cancel();
      if (sessionActive) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed && sessionActive) {
      setState(() {});
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
