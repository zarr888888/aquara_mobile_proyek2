import 'dart:async';
import 'package:flutter/material.dart';
import '../models/profile_summary.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/profile_cooldown_state.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_products.dart';
import '../widgets/session_boundary.dart';

/// Authenticated, read-only presentation; never exposes self-service controls.
class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({
    super.key,
    required this.api,
    required this.userId,
  });
  final ApiService api;
  final int userId;
  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    builder: (_) => _MemberProfile(key: ValueKey(userId), api: api, id: userId),
  );
}

class _MemberProfile extends StatefulWidget {
  const _MemberProfile({super.key, required this.api, required this.id});
  final ApiService api;
  final int id;
  @override
  State<_MemberProfile> createState() => _MemberProfileState();
}

class _MemberProfileState extends State<_MemberProfile>
    with
        SessionOwnedState<_MemberProfile>,
        WidgetsBindingObserver,
        ProfileCooldownState<_MemberProfile> {
  @override
  SessionService get stateSession => widget.api.session;
  SessionSnapshot? _owner;
  StreamSubscription<int>? _subscription;
  ProfileSummary? _profile;
  int _generation = 0;

  bool _loading = false;
  String? _error;
  bool get _active =>
      sessionActive && _owner != null && stateSession.owns(_owner!);

  @override
  void initState() {
    super.initState();
    openProfileCooldown();
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) _clear();
    });
    _open();
  }

  void _clear() {
    _profile = null;

    _error = null;
  }

  Future<void> _open() async {
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;
    _owner = owner;
    await _load();
  }

  void _fail(ApiFailure failure) {
    recordProfileFailure(failure);
    _error = switch (failure.kind) {
      ApiErrorKind.notFound => 'Profil tidak ditemukan atau sudah dihapus.',
      ApiErrorKind.forbidden => 'Profil tidak dapat diakses.',
      _ => failure.message,
    };
  }

  Future<void> _load({bool more = false}) async {
    if (!_active || _loading || profileWait > 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!more) {
      final result = await widget.api.fetchProfile(
        widget.id,
        expectedSession: _owner!,
      );
      if (!_active) return;
      if (!result.isSuccess) {
        setState(() {
          _clear();
          _fail(result.failure!);
          _loading = false;
        });
        return;
      }
      _profile = result.data;
      _generation++;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profil pengguna')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_profile != null) ...[
              ProfileHeader(
                name: _profile!.name,
                photo: _profile!.photo,
                focus: _profile!.focus,
              ),
              ProfileProducts(
                key: ValueKey('${widget.id}:$_generation'),
                api: widget.api,
                ownerId: widget.id,
              ),
            ],
            if (_error != null) Text(_error!),
            if (profileWait > 0) Text(profileWaitMessage),
            TextButton(
              onPressed: _loading || profileWait > 0 ? null : () => _load(),
              child: const Text('Muat ulang profil'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _subscription?.cancel();
    _clear();
    super.dispose();
  }
}
