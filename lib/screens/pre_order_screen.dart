import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pre_order.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/session_boundary.dart';
import '../widgets/profile_cooldown_state.dart';

enum PreOrderView { form, history, detail }

/// Each entry (including direct detail navigation) has its own lazy session guard.
class PreOrderScreen extends StatelessWidget {
  const PreOrderScreen({
    super.key,
    this.api,
    this.view = PreOrderView.form,
    this.id,
    this.clock,
  });
  final ApiService? api;
  final PreOrderView view;
  final int? id;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    builder: (_) => _OrderContent(
      api: api ?? ApiService(),
      view: view,
      id: id,
      clock: clock,
    ),
  );
}

class _OrderContent extends StatefulWidget {
  const _OrderContent({
    required this.api,
    required this.view,
    this.id,
    this.clock,
  });
  final ApiService api;
  final PreOrderView view;
  final int? id;
  final DateTime Function()? clock;
  @override
  State<_OrderContent> createState() => _OrderState();
}

class _OrderState extends State<_OrderContent>
    with
        SessionOwnedState<_OrderContent>,
        WidgetsBindingObserver,
        ProfileCooldownState<_OrderContent> {
  @override
  SessionService get stateSession => widget.api.session;
  @override
  DateTime profileNow() => widget.clock?.call() ?? DateTime.now();
  final _tonnage = TextEditingController();
  final _date = TextEditingController();
  StreamSubscription<int>? _subscription;
  List<PreOrder> _items = [];
  PreOrder? _detail;
  PreOrderPage? _page;
  String? _productName;
  bool _eligible = false;
  bool _busy = false;
  bool _loadingMore = false;
  bool _opening = false;
  bool _sent = false;
  bool _uncertain = false;
  bool _checked = false;
  bool _loaded = false;
  int _operation = 0;
  ApiFailure? _failure;

  @override
  void initState() {
    super.initState();
    openProfileCooldown();
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) _clear();
    });
    _load();
  }

  void _clear() {
    _operation++;
    _tonnage.clear();
    _date.clear();
    _items = [];
    _detail = null;
    _page = null;
    _productName = null;
    _eligible = false;
    _failure = null;
  }

  bool _valid(SessionSnapshot owner, int operation) =>
      sessionActive && stateSession.owns(owner) && operation == _operation;

  void _finish(ApiFailure? failure) {
    _busy = false;
    _loadingMore = false;
    _failure = failure;
    if (failure != null) recordProfileFailure(failure);
  }

  Future<void> _load({bool more = false}) async {
    if (!sessionActive ||
        profileWait > 0 ||
        (_busy &&
            !(widget.view == PreOrderView.history && !more && _loadingMore)) ||
        (more && !(_page?.hasNext ?? false))) {
      return;
    }
    final operation = ++_operation;
    final page = more ? _page!.currentPage + 1 : 1;
    setState(() {
      _busy = true;
      _loadingMore = more;
      _failure = null;
    });
    final owner = await stateSession.snapshot();
    if (!_valid(owner, operation)) return;
    if (widget.view == PreOrderView.form) {
      final result = await widget.api.fetchPasar(expectedSession: owner);
      if (!_valid(owner, operation)) return;
      setState(() {
        _eligible = false;
        _productName = null;
        if (result.isSuccess) {
          for (final product in result.data!) {
            if (product['id'] == widget.id &&
                product['tipe_penjualan'] == 'grosir') {
              _eligible = true;
              _productName = product['nama_ikan'] as String;
              break;
            }
          }
        }
        _loaded = result.isSuccess;
        _finish(result.failure);
      });
    } else if (widget.view == PreOrderView.history) {
      final result = await widget.api.preOrderHistory(
        expectedSession: owner,
        page: page,
      );
      if (!_valid(owner, operation)) return;
      setState(() {
        if (result.isSuccess) {
          final byId = <int, PreOrder>{
            if (more)
              for (final item in _items) item.id: item,
            for (final item in result.data!.items) item.id: item,
          };
          _items = byId.values.toList();
          _page = result.data;
          _loaded = true;
        }
        _finish(result.failure);
      });
    } else {
      final result = await widget.api.preOrderDetail(
        widget.id ?? 0,
        expectedSession: owner,
      );
      if (!_valid(owner, operation)) return;
      setState(() {
        // Do not keep a previously accessible detail after a denied refresh.
        _detail = result.data;
        _loaded = result.isSuccess;
        _finish(result.failure);
      });
    }
  }

  Future<void> _submit() async {
    if (!sessionActive ||
        _busy ||
        _sent ||
        !_eligible ||
        profileWait > 0 ||
        (_uncertain && !_checked)) {
      return;
    }
    final operation = ++_operation;
    setState(() => _busy = true);
    final owner = await stateSession.snapshot();
    if (!_valid(owner, operation)) return;
    final result = await widget.api.createPreOrder(
      expectedSession: owner,
      pasarId: widget.id!,
      tonnage: _tonnage.text,
      pickupDate: _date.text,
    );
    if (!_valid(owner, operation)) return;
    setState(() {
      _finish(result.failure);
      if (result.isSuccess) {
        _detail = result.data;
        _sent = true;
        _uncertain = false;
        _tonnage.clear();
        _date.clear();
      } else {
        _uncertain =
            _uncertain ||
            const [
              ApiErrorKind.timeout,
              ApiErrorKind.network,
              ApiErrorKind.invalidResponse,
              ApiErrorKind.server,
            ].contains(result.failure!.kind) ||
            (result.statusCode ?? 0) >= 500;
        _checked = false;
      }
    });
  }

  Future<void> _confirm() async {
    final order = _detail;
    if (!sessionActive ||
        _busy ||
        profileWait > 0 ||
        order == null ||
        !order.canConfirm) {
      return;
    }
    final operation = ++_operation;
    setState(() => _busy = true);
    final owner = await stateSession.snapshot();
    if (!_valid(owner, operation)) return;
    final result = await widget.api.confirmPreOrder(
      order.id,
      expectedSession: owner,
    );
    if (!_valid(owner, operation)) return;
    setState(() {
      _detail = result.data;
      _finish(result.failure);
    });
  }

  Future<void> _open(PreOrderView view, [int? id]) async {
    if (!sessionActive || _opening) return;
    _opening = true;
    final owner = await stateSession.snapshot();
    if (!mounted || !sessionActive || !stateSession.owns(owner)) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreOrderScreen(
          api: widget.api,
          view: view,
          id: id,
          clock: widget.clock,
        ),
      ),
    );
    if (!sessionActive || !stateSession.owns(owner)) return;
    setState(() {
      _opening = false;
      if (_uncertain && view == PreOrderView.history) _checked = true;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _clear();
    _tonnage.dispose();
    _date.dispose();
    super.dispose();
  }

  Widget _summary(PreOrder order) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Pesanan #${order.id}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Text('Produk #${order.pasarId}'),
      Text('Tonase: ${order.tonnage} ton'),
      Text('Pengambilan: ${order.pickupDate}'),
      Text('Status pembayaran: ${order.statusLabel}'),
      Text(
        order.confirmedAt == null
            ? 'Menunggu konfirmasi penjual'
            : 'Dikonfirmasi penjual',
      ),
      const Text('Pembayaran dilakukan langsung kepada penjual.'),
      if (widget.view == PreOrderView.detail && order.canConfirm)
        FilledButton(
          onPressed: _busy || profileWait > 0 ? null : _confirm,
          child: const Text('Konfirmasi pesanan'),
        ),
      const Text(
        'Status adalah informasi backend; bukan pembayaran melalui aplikasi.',
      ),
      if (order.createdAt != null) Text('Dibuat: ${order.createdAt}'),
      if (order.updatedAt != null) Text('Diperbarui: ${order.updatedAt}'),
    ],
  );

  Widget _header() {
    final form = widget.view == PreOrderView.form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_failure != null)
          Text(_failure!.message, key: const Key('order-error')),
        if (profileWait > 0) Text(profileWaitMessage),
        TextButton(
          onPressed: _opening ? null : () => _open(PreOrderView.history),
          child: const Text('Riwayat pre-order'),
        ),
        if (!form || (!_sent && !_uncertain))
          TextButton(
            onPressed: profileWait > 0 || (_busy && !_loadingMore)
                ? null
                : () => _load(),
            child: const Text('Muat ulang'),
          ),
        if (form) ...[
          Text(
            _productName ?? 'Produk #${widget.id ?? "—"}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('Informasi produk saat ini, bukan snapshot pesanan.'),
          const Text(
            'Ketersediaan dan tindak lanjut pengajuan perlu dikonfirmasi dengan penjual. '
            'Pengajuan tidak mencadangkan stok. Pembayaran tidak diproses melalui fitur ini.',
          ),
          if (_loaded && !_eligible)
            const Text('Produk grosir tidak tersedia. Kembali ke Pasar.'),
          if (_failure?.fieldErrors['pasar_id'] != null)
            Text(_failure!.fieldErrors['pasar_id']!.first),
          if (!_sent && _eligible) ...[
            TextField(
              key: const Key('order-tonnage'),
              controller: _tonnage,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Tonase (ton)',
                helperText: 'Contoh 2,50. Koma desimal, tanpa pemisah ribuan.',
                helperMaxLines: 3,
                errorMaxLines: 5,
                errorText: _failure?.fieldErrors['total_tonase']?.first,
              ),
            ),
            TextField(
              key: const Key('order-date'),
              controller: _date,
              enabled: !_busy,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: 'Tanggal pengambilan',
                helperText:
                    'YYYY-MM-DD; hari ini atau sesudahnya menurut tanggal server.',
                helperMaxLines: 4,
                errorMaxLines: 5,
                errorText: _failure?.fieldErrors['tgl_pengambilan']?.first,
              ),
            ),
            if (_uncertain)
              const Text(
                'Hasil pengiriman belum dapat dipastikan. Periksa riwayat. '
                'Tidak muncul pada satu halaman bukan bukti pengajuan gagal. '
                'Mengirim ulang dapat membuat pesanan ganda.',
              ),
            FilledButton(
              key: const Key('order-submit'),
              onPressed: _busy || profileWait > 0 || (_uncertain && !_checked)
                  ? null
                  : _submit,
              child: Text(
                _uncertain
                    ? 'Kirim ulang dengan risiko duplikat'
                    : 'Kirim pengajuan',
              ),
            ),
          ],
          if (_sent) ...[
            const Text('Pengajuan berhasil dicatat.'),
            _summary(_detail!),
            TextButton(
              onPressed: () => _open(PreOrderView.detail, _detail!.id),
              child: const Text('Lihat detail pesanan'),
            ),
          ],
        ],
        if (widget.view == PreOrderView.history) ...[
          const Text(
            'Pesanan terkait Anda sebagai pembeli atau pemilik produk.',
          ),
          if (_loaded && _items.isEmpty) const Text('Belum ada pesanan.'),
        ],
        if (widget.view == PreOrderView.detail && _detail != null)
          _summary(_detail!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.view) {
        PreOrderView.form => 'Pengajuan pre-order',
        PreOrderView.history => 'Riwayat pesanan',
        PreOrderView.detail => 'Detail pesanan',
      }),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount:
                2 + (widget.view == PreOrderView.history ? _items.length : 0),
            itemBuilder: (context, index) {
              if (index == 0) return _header();
              if (widget.view == PreOrderView.history &&
                  index <= _items.length) {
                final order = _items[index - 1];
                return Card(
                  child: ListTile(
                    key: ValueKey('order-${order.id}'),
                    title: Text(
                      'Pesanan #${order.id} • Produk #${order.pasarId}',
                    ),
                    subtitle: Text(
                      '${order.tonnage} ton • ${order.pickupDate}\n${order.statusLabel}',
                    ),
                    onTap: () => _open(PreOrderView.detail, order.id),
                  ),
                );
              }
              return widget.view == PreOrderView.history &&
                      (_page?.hasNext ?? false)
                  ? TextButton(
                      key: const Key('order-more'),
                      onPressed: _busy || profileWait > 0
                          ? null
                          : () => _load(more: true),
                      child: const Text('Muat berikutnya'),
                    )
                  : const SizedBox(height: 24);
            },
          ),
        ),
      ),
    ),
  );
}
