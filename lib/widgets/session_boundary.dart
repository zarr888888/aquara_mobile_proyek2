import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../screens/login_screen.dart';

/// One coordinator per existing Navigator. No parallel router or token store.
class SessionNavigation {
  static final _pending = Expando<bool>();

  static void leave(BuildContext context) {
    leaveNavigator(Navigator.of(context, rootNavigator: true));
  }

  static void leaveNavigator(NavigatorState navigator) {
    if (_pending[navigator] == true) return;
    _pending[navigator] = true;
    // Do not retain decoded account avatars/photos across credential changes.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pending[navigator] = false;
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

/// Lazy child construction prevents private initState/requests before entry.
/// Removing the child discards its futures, controllers and account data.
class SessionBoundary extends StatefulWidget {
  const SessionBoundary({
    super.key,
    required this.builder,
    this.api,
    this.private = true,
  });
  final WidgetBuilder builder;
  final ApiService? api;
  final bool private;

  @override
  State<SessionBoundary> createState() => _SessionBoundaryState();
}

class _SessionBoundaryState extends State<SessionBoundary> {
  late final ApiService _api = widget.api ?? ApiService();
  late final SessionService _session = _api.session;
  StreamSubscription<int>? _subscription;
  SessionSnapshot? _owner;
  bool _ready = false;
  bool _closed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _session.changes.listen((revision) {
      if (!mounted || _closed) return;
      if (_owner != null && revision != _owner!.revision) {
        if (!_owner!.isAuthenticated && !widget.private) {
          setState(() => _ready = false);
          _open();
          return;
        }
        _closed = true;
        setState(() => _ready = false);
        SessionNavigation.leave(context);
      } else if (_ready) {
        setState(() {});
      }
    });
    _open();
  }

  Future<void> _open() async {
    try {
      final owner = await _session.snapshot();
      if (!mounted || _closed) return;
      _owner = owner;
      if (widget.private && !owner.isAuthenticated) {
        _closed = true;
        SessionNavigation.leave(context);
        setState(() {});
        return;
      }
      if (owner.isAuthenticated && _session.metadata.isEmpty) {
        final result = await _api.currentUser();
        if (!mounted || _closed || !_session.owns(owner)) return;
        if (!result.isSuccess) {
          setState(() => _error = result.failure!.message);
          return;
        }
      }
      if (!mounted || _closed || owner.revision != _session.revision) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted && !_closed) {
        setState(
          () => _error = 'Sesi tidak dapat dibuka. Silakan coba kembali.',
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && !_closed && _owner?.revision == _session.revision) {
      return KeyedSubtree(
        key: ValueKey(_owner!.revision),
        child: widget.builder(context),
      );
    }
    return Scaffold(
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _open();
                    },
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Legacy callbacks belong to the revision that constructed their State.
/// A mounted check alone is insufficient during route removal animations.
mixin SessionOwnedState<T extends StatefulWidget> on State<T> {
  SessionService get stateSession => SessionService.instance;
  late final int _sessionRevision;
  @override
  void initState() {
    super.initState();
    _sessionRevision = stateSession.revision;
  }

  bool get sessionActive =>
      mounted && _sessionRevision == stateSession.revision;

  @override
  void setState(VoidCallback fn) {
    if (sessionActive) super.setState(fn);
  }
}
