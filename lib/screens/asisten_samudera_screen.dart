import 'dart:async';
import 'package:flutter/material.dart';
import '../models/asisten_chat.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/session_boundary.dart';
import '../widgets/gombyang.dart';

const asistenSimulationLabel =
    'Pesan dapat diproses oleh AI. Jangan kirim data rahasia. Chat ini bukan layanan tanggap darurat.';

class AsistenSamuderaScreen extends StatelessWidget {
  const AsistenSamuderaScreen({super.key, this.api, this.id});
  final ApiService? api;
  final int? id;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    builder: (_) => _AsistenContent(api: api ?? ApiService(), id: id),
  );
}

class _AsistenContent extends StatefulWidget {
  const _AsistenContent({required this.api, this.id});
  final ApiService api;
  final int? id;
  @override
  State<_AsistenContent> createState() => _AsistenState();
}

class _AsistenState extends State<_AsistenContent>
    with SessionOwnedState<_AsistenContent> {
  @override
  SessionService get stateSession => widget.api.session;
  final _draft = TextEditingController();
  StreamSubscription<int>? _subscription;
  Timer? _ticker;
  List<AsistenChat> _items = [];
  AsistenPage? _page;
  ApiFailure? _failure;
  bool _loading = false, _sending = false, _loaded = false, _opening = false;
  bool _uncertain = false;
  int _generation = 0;
  int get _wait => widget.api.asistenGate.seconds(widget.api.asistenNow());

  @override
  void initState() {
    super.initState();
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) _clear();
    });
    // Presentation only: never fetch on deadline expiry or app resume.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (sessionActive) setState(() {});
    });
    if (_wait == 0) _load();
  }

  void _clear() {
    _generation++;
    _draft.clear();
    _items = [];
    _page = null;
    _failure = null;
    _sending = _loading = _loaded = _opening = _uncertain = false;
    _ticker?.cancel();
  }

  bool _valid(SessionSnapshot owner, int generation) =>
      sessionActive && stateSession.owns(owner) && generation == _generation;

  Future<void> _load({bool more = false}) async {
    if (!sessionActive ||
        _wait > 0 ||
        _sending ||
        (more && (_loading || !(_page?.hasNext ?? false)))) {
      return;
    }
    final generation = ++_generation;
    final page = more ? _page!.currentPage + 1 : 1;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final owner = await stateSession.snapshot();
    if (!_valid(owner, generation)) return;
    if (widget.id != null) {
      final result = await widget.api.asistenDetail(
        widget.id!,
        expectedSession: owner,
      );
      if (!_valid(owner, generation)) return;
      setState(() {
        _loading = false;
        _failure = result.failure;
        if (result.isSuccess) {
          _items = [result.data!];
          _loaded = true;
        }
      });
    } else {
      final result = await widget.api.asistenHistory(
        expectedSession: owner,
        page: page,
      );
      if (!_valid(owner, generation)) return;
      setState(() {
        _loading = false;
        _failure = result.failure;
        if (result.isSuccess) {
          _page = result.data!;
          _items = AsistenChat.merge(more ? _items : [], _page!.items);
          _loaded = true;
        }
      });
    }
  }

  Future<void> _send() async {
    if (!sessionActive ||
        _sending ||
        _wait > 0 ||
        widget.api.asistenGate.sending) {
      return;
    }
    final text = _draft.text;
    if (!asistenMessageValid(text)) {
      setState(
        () => _failure = ApiFailure(
          kind: ApiErrorKind.validation,
          message: asistenMessageError,
        ),
      );
      return;
    }
    final generation = ++_generation;
    setState(() {
      _sending = true;
      _loading = false;
      _failure = null;
    });
    final owner = await stateSession.snapshot();
    if (!_valid(owner, generation)) return;
    final result = await widget.api.sendAsisten(text, expectedSession: owner);
    if (!_valid(owner, generation)) return;
    setState(() {
      _sending = false;
      _failure = result.failure;
      if (result.isSuccess) {
        _items = AsistenChat.merge(_items, [result.data!]);
        _draft.clear();
        _uncertain = false;
      } else {
        _uncertain =
            _uncertain ||
            const {
              ApiErrorKind.network,
              ApiErrorKind.timeout,
              ApiErrorKind.server,
              ApiErrorKind.invalidResponse,
              ApiErrorKind.http,
            }.contains(result.failure!.kind);
      }
    });
  }

  Future<void> _open(int id) async {
    if (!sessionActive || _opening || _wait > 0) return;
    _opening = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AsistenSamuderaScreen(api: widget.api, id: id),
        ),
      );
    } finally {
      if (sessionActive) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _clear();
    _draft.dispose();
    super.dispose();
  }

  Widget _pair(AsistenChat chat) => Column(
    key: ValueKey('asisten-${chat.id}'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _bubble(chat, user: true),
      const SizedBox(height: 16),
      _bubble(chat, user: false),
      if (widget.id == null)
        TextButton(
          onPressed: _wait > 0 || _opening ? null : () => _open(chat.id),
          child: const Text('Buka detail'),
        ),
      const SizedBox(height: 24),
    ],
  );

  Widget _bubble(AsistenChat chat, {required bool user}) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: .88,
      child: Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: user
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!user) ...[
                Row(
                  children: [
                    Image.asset(
                      gombyangAsset,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chat.isMock ? 'Gombyang • Simulasi' : 'Gombyang • AI',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Container(
                key: ValueKey(
                  'asisten-${user ? 'question' : 'answer'}-${chat.id}',
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: user
                      ? const Color(0xFF009FE3)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user ? chat.question : chat.answer,
                  style: TextStyle(
                    color: user
                        ? Colors.black
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                chat.createdAt.toLocal().toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _identity() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Image.asset(
          gombyangAsset,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asisten SAMUDERA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Balasan otomatis'),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _composer(bool compact) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const Key('asisten-draft'),
            controller: _draft,
            enabled: !_sending,
            minLines: 1,
            maxLines: compact ? 2 : 4,
            decoration: const InputDecoration(
              labelText: 'Pesan',
              hintText: 'Maksimal 2000 karakter Unicode',
              hintMaxLines: 1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _uncertain
              ? 'Kirim ulang dengan risiko duplikat'
              : 'Kirim pesan',
          child: FilledButton(
            key: const Key('asisten-send'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              backgroundColor: const Color(0xFF009FE3),
              foregroundColor: Colors.black,
            ),
            onPressed: _sending || _wait > 0 ? null : _send,
            child: Icon(
              Icons.send_rounded,
              semanticLabel: _uncertain
                  ? 'Kirim ulang dengan risiko duplikat'
                  : 'Kirim pesan',
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.id == null ? 'Asisten SAMUDERA' : 'Detail Asisten'),
      actions: [
        PopupMenuButton<String>(
          key: const Key('asisten-menu'),
          tooltip: 'Menu Asisten',
          onSelected: (value) {
            if (value == 'refresh') _load();
            if (value == 'close') Navigator.maybePop(context);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'refresh',
              enabled: !_sending && _wait == 0,
              child: Text(
                widget.id == null
                    ? 'Periksa / muat ulang riwayat'
                    : 'Muat ulang detail',
              ),
            ),
            const PopupMenuItem(value: 'close', child: Text('Tutup layar')),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 600 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5;
          return Column(
            children: [
              // Outside the scrolling content: present in loading/empty/error/detail.
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.secondaryContainer,
                padding: const EdgeInsets.all(12),
                child: Text(
                  asistenSimulationLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.2),
                ),
              ),
              if (_loading || _sending) const LinearProgressIndicator(),
              if (!compact) _identity(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (compact) _identity(),
                    const Text(
                      'Jangan kirim password, OTP, atau token. Dr.Fisho dan WhatsApp adalah layanan terpisah.',
                    ),
                    const Text(
                      'Logout membersihkan tampilan lokal, bukan menghapus riwayat server. Draft hanya disimpan dalam memori sesi.',
                    ),
                    if (_wait > 0)
                      Text(
                        widget.api.asistenGate.localFallback
                            ? 'Jeda lokal aplikasi: $_wait detik. Ini bukan waktu reset server.'
                            : 'Tunggu $_wait detik sesuai Retry-After server.',
                      ),
                    if (_failure != null)
                      Text(_failure!.message, key: const Key('asisten-error')),
                    if (_uncertain)
                      const Text(
                        'Hasil pengiriman belum dapat dipastikan. Periksa riwayat secara manual sebelum mengirim ulang. Tidak muncul pada satu halaman bukan bukti gagal; teks/tanggal yang sama bukan bukti pasti berhasil. Mengirim ulang berisiko duplikat.',
                        key: Key('asisten-uncertain'),
                      ),
                    if (widget.id == null) ...[
                      const Text(
                        'Riwayat sendiri • kronologis: waktu terlama dahulu, lalu ID naik. Setiap pasangan berdiri sendiri, bukan percakapan berkelanjutan.',
                      ),
                    ],
                    TextButton(
                      key: const Key('asisten-refresh'),
                      onPressed: _sending || _wait > 0 ? null : () => _load(),
                      child: Text(
                        widget.id == null
                            ? 'Periksa / muat ulang riwayat'
                            : 'Muat ulang detail',
                      ),
                    ),
                    if (_loaded && _items.isEmpty)
                      const Text('Belum ada riwayat.'),
                    ..._items.map(_pair),
                    if (widget.id == null && (_page?.hasNext ?? false))
                      TextButton(
                        key: const Key('asisten-more'),
                        onPressed: _loading || _sending || _wait > 0
                            ? null
                            : () => _load(more: true),
                        child: const Text('Muat halaman lebih lama'),
                      ),
                  ],
                ),
              ),
              if (widget.id == null) _composer(compact),
            ],
          );
        },
      ),
    ),
  );
}
