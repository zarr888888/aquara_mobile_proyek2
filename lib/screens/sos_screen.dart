import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sos_report.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/sos_api.dart';
import '../widgets/session_boundary.dart';
import '../widgets/profile_cooldown_state.dart';

enum SosPage { form, history, detail }

class SosScreen extends StatelessWidget {
  const SosScreen({
    super.key,
    this.api,
    this.page = SosPage.form,
    this.id,
    this.pickPhoto,
    this.clock,
  });
  final ApiService? api;
  final SosPage page;
  final int? id;
  final Future<XFile?> Function(ImageSource)? pickPhoto;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    builder: (_) => _SosContent(
      api: api ?? ApiService(),
      page: page,
      id: id,
      picker: pickPhoto,
      clock: clock,
    ),
  );
}

class _SosContent extends StatefulWidget {
  const _SosContent({
    required this.api,
    required this.page,
    this.id,
    this.picker,
    this.clock,
  });
  final ApiService api;
  final SosPage page;
  final int? id;
  final Future<XFile?> Function(ImageSource)? picker;
  final DateTime Function()? clock;
  @override
  State<_SosContent> createState() => _SosState();
}

class _SosState extends State<_SosContent>
    with
        SessionOwnedState<_SosContent>,
        WidgetsBindingObserver,
        ProfileCooldownState<_SosContent> {
  @override
  SessionService get stateSession => widget.api.session;
  @override
  DateTime profileNow() => widget.clock?.call() ?? DateTime.now();
  final _description = TextEditingController();
  String _type = sosTypes.first;
  SosPhoto? _photo;
  List<SosReport>? _history;
  SosReport? _detail;
  ApiFailure? _failure;
  bool _busy = false;
  bool _uncertain = false;
  bool _checked = false;
  bool _sent = false;
  bool _opening = false;
  int _operation = 0;
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    openProfileCooldown();
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) {
        _operation++;
        _description.clear();
        _photo = null;
        _history = null;
        _detail = null;
        _failure = null;
      }
    });
    if (widget.page != SosPage.form) _load();
  }

  bool _valid(SessionSnapshot owner, int operation) =>
      sessionActive && stateSession.owns(owner) && operation == _operation;

  Future<void> _load() async {
    if (_busy || profileWait > 0 || !sessionActive) return;
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final owner = await stateSession.snapshot();
    if (!_valid(owner, operation)) return;
    if (widget.page == SosPage.detail) {
      final result = await widget.api.sosDetail(
        widget.id ?? 0,
        expectedSession: owner,
      );
      if (!_valid(owner, operation)) return;
      setState(() {
        _detail = result.data;
        _finish(result.failure);
      });
    } else {
      final result = await widget.api.sosHistory(expectedSession: owner);
      if (!_valid(owner, operation)) return;
      setState(() {
        _history = result.data;
        _finish(result.failure);
      });
    }
  }

  void _finish(ApiFailure? failure) {
    _busy = false;
    _failure = failure;
    if (failure != null) recordProfileFailure(failure);
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy || _sent || !sessionActive) return;
    final operation = ++_operation;
    setState(() => _busy = true);
    final owner = await stateSession.snapshot();
    if (!_valid(owner, operation)) return;
    try {
      final file =
          await (widget.picker?.call(source) ??
              ImagePicker().pickImage(source: source));
      if (!_valid(owner, operation)) return;
      final photo = file == null ? null : await SosPhoto.read(file);
      if (!_valid(owner, operation)) return;
      setState(() {
        if (photo != null) _photo = photo;
        _finish(null);
      });
    } catch (_) {
      if (!_valid(owner, operation)) return;
      setState(
        () => _finish(
          ApiFailure(
            kind: ApiErrorKind.validation,
            message:
                'Foto tidak dapat dipilih. Gunakan JPEG/PNG maksimal 2048 KB.',
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_busy ||
        _sent ||
        profileWait > 0 ||
        !sessionActive ||
        (_uncertain && !_checked)) {
      return;
    }
    final operation = ++_operation;
    setState(() => _busy = true);
    final owner = await stateSession.snapshot();
    if (!_valid(owner, operation)) return;
    final result = await widget.api.sendSos(
      expectedSession: owner,
      type: _type,
      description: _description.text,
      photo: _photo,
    );
    if (!_valid(owner, operation)) return;
    setState(() {
      _finish(result.failure);
      if (result.isSuccess) {
        _sent = true;
        _detail = result.data;
        _photo = null;
        _description.clear();
        _uncertain = false;
      } else {
        _uncertain =
            const [
              ApiErrorKind.timeout,
              ApiErrorKind.network,
              ApiErrorKind.invalidResponse,
            ].contains(result.failure!.kind) ||
            (result.failure!.kind == ApiErrorKind.server &&
                result.statusCode != 503);
        _checked = false;
        if (result.statusCode == 503) {
          _failure = ApiFailure(
            kind: ApiErrorKind.server,
            message:
                'Upload gagal; laporan tidak dibuat. Draft tetap tersedia. Silakan kirim ulang secara manual.',
          );
        }
      }
    });
  }

  Future<void> _open(SosPage page, [int? id]) async {
    if (!sessionActive || _opening) return;
    _opening = true;
    final operation = _operation;
    final owner = await stateSession.snapshot();
    if (!mounted || !_valid(owner, operation)) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SosScreen(
          api: widget.api,
          page: page,
          id: id,
          pickPhoto: widget.picker,
          clock: widget.clock,
        ),
      ),
    );
    if (!_valid(owner, operation)) return;
    _opening = false;
    if (_uncertain) setState(() => _checked = true);
  }

  @override
  void dispose() {
    _operation++;
    _subscription?.cancel();
    _description.dispose();
    _photo = null;
    _history = null;
    _detail = null;
    super.dispose();
  }

  Widget _report(SosReport report) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(report.type, style: Theme.of(context).textTheme.titleLarge),
      Text('Status: ${report.status}'),
      Text(report.createdAt?.toLocal().toString() ?? 'Tanggal tidak tersedia'),
      const SizedBox(height: 12),
      Text(report.description),
      const SizedBox(height: 12),
      if (report.photo != null)
        Image.network(
          report.photo!,
          semanticLabel: 'Foto laporan SOS',
          height: 180,
          errorBuilder: (_, _, _) => const Text('Foto tidak tersedia'),
        )
      else
        const Text('Tidak ada foto'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final form = widget.page == SosPage.form;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.page) {
          SosPage.form => 'SOS Bahari',
          SosPage.history => 'Riwayat SOS',
          SosPage.detail => 'Detail SOS',
        }),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (form) ...[
                  const Text(
                    'Fitur ini mengirim laporan kepada dinas. Tidak menjamin respons instan dan bukan pengganti layanan tanggap darurat.',
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _open(SosPage.history),
                    child: const Text('Periksa riwayat saya'),
                  ),
                ],
                if (_busy) const Center(child: CircularProgressIndicator()),
                if (_failure != null) ...[
                  Text(_failure!.message),
                  for (final key in const ['jenis_sos', 'deskripsi', 'foto'])
                    if (_failure!.fieldErrors.containsKey(key))
                      Text('$key: ${_failure!.fieldErrors[key]!.join(' ')}'),
                ],
                if (profileWait > 0) Text(profileWaitMessage),
                if (form && !_sent) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Jenis SOS'),
                    items: [
                      for (final type in sosTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _type = value!),
                  ),
                  TextField(
                    controller: _description,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: 'Deskripsi',
                      helperText: 'Wajib, maksimal 5000 karakter',
                      helperMaxLines: 3,
                      errorText: _failure?.fieldErrors['deskripsi']?.join(' '),
                      errorMaxLines: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Foto opsional: JPEG/PNG, maksimal 2048 KB.'),
                  if (_photo != null) ...[
                    Image.memory(
                      _photo!.bytes,
                      semanticLabel: 'Preview foto laporan SOS',
                      height: 160,
                      errorBuilder: (_, _, _) =>
                          const Text('Preview tidak tersedia'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _photo = null),
                      child: const Text('Hapus foto'),
                    ),
                  ],
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.gallery),
                        child: const Text('Pilih foto'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.camera),
                        child: const Text('Kamera'),
                      ),
                    ],
                  ),
                  if (_uncertain)
                    const Text(
                      'Hasil pengiriman belum diketahui. Periksa riwayat sebelum memilih kirim ulang. Laporan yang belum terlihat bukan jaminan pengiriman sebelumnya tidak diproses; mengirim ulang dapat membuat laporan ganda.',
                    ),
                  FilledButton(
                    onPressed:
                        _busy || profileWait > 0 || (_uncertain && !_checked)
                        ? null
                        : _submit,
                    child: Text(
                      _uncertain
                          ? 'Kirim ulang dengan risiko duplikat'
                          : 'Kirim laporan',
                    ),
                  ),
                ],
                if (_sent) ...[
                  const Text('Laporan berhasil dikirim.'),
                  _report(_detail!),
                  TextButton(
                    onPressed: () => _open(SosPage.detail, _detail!.id),
                    child: const Text('Lihat detail status'),
                  ),
                ],
                if (!form) ...[
                  TextButton(
                    onPressed: _busy || profileWait > 0 ? null : _load,
                    child: const Text('Muat ulang'),
                  ),
                  if (widget.page == SosPage.history &&
                      !_busy &&
                      _failure == null &&
                      _history?.isEmpty == true)
                    const Text('Belum ada laporan.'),
                  if (widget.page == SosPage.history)
                    for (final report in _history ?? <SosReport>[])
                      Card(
                        child: ListTile(
                          title: Text(report.type),
                          subtitle: Text('Status: ${report.status}'),
                          onTap: () => _open(SosPage.detail, report.id),
                        ),
                      ),
                  if (widget.page == SosPage.detail && _detail != null)
                    _report(_detail!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
