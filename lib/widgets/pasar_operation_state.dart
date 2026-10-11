import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'session_boundary.dart';

/// In-memory UX state, owned by one session. No retries or navigation here.
mixin PasarOperationState<T extends StatefulWidget>
    on State<T>, SessionOwnedState<T>, WidgetsBindingObserver {
  ApiService get pasarApi;
  DateTime pasarNow() => DateTime.now();
  SessionSnapshot? pasarOwner;
  bool pasarBusy = false;
  bool pasarUncertain = false;
  String? pasarMessage;
  Map<String, List<String>> pasarErrors = {};
  DateTime? _deadline;
  bool _localWait = false;
  Timer? _timer;
  StreamSubscription<int>? _subscription;
  bool _foreground = true;
  bool get pasarActive =>
      sessionActive && pasarOwner != null && stateSession.owns(pasarOwner!);
  int get pasarRemaining {
    final milliseconds = _deadline?.difference(pasarNow()).inMilliseconds ?? 0;
    return milliseconds > 0 ? (milliseconds / 1000).ceil() : 0;
  }

  bool get pasarBlocked =>
      !pasarActive || pasarBusy || pasarRemaining > 0 || pasarUncertain;

  Future<void> openPasar() async {
    WidgetsBinding.instance.addObserver(this);
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) {
        _timer?.cancel();
        pasarMessage = null;
        pasarErrors.clear();
        clearPasarPrivate();
      }
    });
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;
    setState(() => pasarOwner = owner);
  }

  void clearPasarPrivate() {}

  void pasarFailure(ApiFailure failure, {bool mutation = false}) {
    pasarErrors = Map.of(failure.fieldErrors);
    pasarMessage = switch (failure.kind) {
      ApiErrorKind.forbidden ||
      ApiErrorKind.notFound => 'Akses atau data Pasar tidak tersedia.',
      _ => failure.message,
    };
    if (mutation &&
        {
          ApiErrorKind.timeout,
          ApiErrorKind.network,
          ApiErrorKind.invalidResponse,
          ApiErrorKind.server,
        }.contains(failure.kind)) {
      pasarUncertain = true;
      pasarMessage =
          'Hasil aksi belum dapat dipastikan. Periksa ulang daftar sebelum mengirim lagi.';
    }
    if (failure.kind == ApiErrorKind.rateLimited) {
      _localWait = failure.retryAfter == null;
      _deadline =
          failure.retryAt ??
          pasarNow().add(failure.retryAfter ?? const Duration(seconds: 60));
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_foreground || !pasarActive || pasarRemaining == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!pasarActive || pasarRemaining == 0) _timer?.cancel();
      if (pasarActive) setState(() {});
    });
  }

  Widget pasarStatus({VoidCallback? checkList}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (pasarMessage != null)
        Padding(padding: const EdgeInsets.all(8), child: Text(pasarMessage!)),
      for (final field in [
        'nama_ikan',
        'harga',
        'deskripsi',
        'nomor_wa',
        'lokasi',
        'foto',
      ])
        if (pasarErrors.containsKey(field))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$field: ${pasarErrors[field]!.join(' ')}'),
          ),
      if (pasarRemaining > 0)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _localWait
                ? 'Jeda lokal $pasarRemaining detik; waktu reset server tidak tersedia.'
                : 'Tunggu $pasarRemaining detik sebelum mencoba lagi.',
          ),
        ),
      if (checkList != null && pasarUncertain)
        TextButton(
          onPressed: pasarBusy || pasarRemaining > 0 ? null : checkList,
          child: const Text('Periksa ulang daftar'),
        ),
    ],
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _timer?.cancel();
    if (_foreground && pasarActive) {
      setState(() {});
      _startTimer();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
