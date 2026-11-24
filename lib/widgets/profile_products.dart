import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../screens/pasar_screen.dart';
import 'session_boundary.dart';
import 'profile_cooldown_state.dart';

/// Owner endpoint only: stock quantities and fish-type IDs are never route IDs.
class ProfileProducts extends StatefulWidget {
  const ProfileProducts({
    super.key,
    required this.api,
    required this.ownerId,
    this.mine = false,
    this.clock,
  });
  final ApiService api;
  final int ownerId;
  final bool mine;
  final DateTime Function()? clock;
  @override
  State<ProfileProducts> createState() => _ProfileProductsState();
}

class _ProfileProductsState extends State<ProfileProducts>
    with
        SessionOwnedState<ProfileProducts>,
        WidgetsBindingObserver,
        ProfileCooldownState<ProfileProducts> {
  @override
  SessionService get stateSession => widget.api.session;
  @override
  DateTime profileNow() => (widget.clock ?? DateTime.now)();
  SessionSnapshot? _owner;
  StreamSubscription<int>? _subscription;
  final List<Map<String, dynamic>> _items = [];
  int _page = 0, _last = 1;
  bool _loading = false, _opening = false;
  String? _error;
  bool get _active =>
      sessionActive && _owner != null && stateSession.owns(_owner!);

  @override
  void initState() {
    super.initState();
    openProfileCooldown();
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) _items.clear();
    });
    _open();
  }

  Future<void> _open() async {
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;
    _owner = owner;
    await _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (!_active || _loading || profileWait > 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.api.fetchProfileProducts(
      widget.ownerId,
      expectedSession: _owner!,
      page: refresh ? 1 : _page + 1,
    );
    if (!_active) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        if (refresh) _items.clear();
        final ids = _items.map((e) => e['id']).toSet();
        _items.addAll(result.data!.items.where((e) => ids.add(e['id'])));
        _page = result.data!.page;
        _last = result.data!.lastPage;
      } else {
        recordProfileFailure(result.failure!);
        _error = result.failure!.message;
      }
    });
  }

  Future<void> _product(Map<String, dynamic> item) async {
    if (!_active || _opening || item['user_id'] != widget.ownerId) return;
    _opening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PasarScreen(
            api: widget.api,
            targetItemId: item['id'],
            targetOwnerId: widget.ownerId,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
    if (_active && widget.mine) await _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final processed in [false, true]) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Stok ${processed ? 'Olahan' : 'Panen'} ${widget.mine ? 'Saya' : 'Pemilik'}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (final item in _items.where(
          (e) => processed
              ? e['kategori'] == 'olahan'
              : e['kategori'] == 'tawar' || e['kategori'] == 'laut',
        ))
          Card(
            child: ListTile(
              key: ValueKey('profile-product-${item['id']}'),
              title: Text(item['nama_ikan']),
              subtitle: Text(
                'Rp ${item['harga']}\nStok: ${item['stok'] ?? 'Tidak tersedia'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _product(item),
            ),
          ),
        if (!_loading &&
            !_items.any(
              (e) => processed
                  ? e['kategori'] == 'olahan'
                  : e['kategori'] == 'tawar' || e['kategori'] == 'laut',
            ))
          Text(
            _page < _last || _error != null
                ? 'Belum ada pada halaman yang dimuat.'
                : processed
                ? 'Belum ada stok olahan.'
                : 'Belum ada stok panen.',
          ),
      ],
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      if (profileWait > 0) Text(profileWaitMessage),
      if (_page < _last || _error != null)
        TextButton(
          onPressed: _loading || profileWait > 0 ? null : () => _load(),
          child: Text(_error == null ? 'Muat produk berikutnya' : 'Coba lagi'),
        ),
      TextButton(
        onPressed: _loading || profileWait > 0
            ? null
            : () => _load(refresh: true),
        child: const Text('Muat ulang produk'),
      ),
    ],
  );

  @override
  void dispose() {
    _subscription?.cancel();
    _items.clear();
    super.dispose();
  }
}
