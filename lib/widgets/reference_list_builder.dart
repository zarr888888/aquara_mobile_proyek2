import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_result.dart';

/// Keeps typed failures out of legacy success/empty rendering branches.
class ReferenceListBuilder extends StatefulWidget {
  const ReferenceListBuilder({
    super.key,
    required this.future,
    required this.retry,
    required this.builder,
    this.clock = DateTime.now,
  });
  final Future<ApiResult<List<dynamic>>> future;
  final Future<ApiResult<List<dynamic>>> Function() retry;
  final AsyncWidgetBuilder<List<dynamic>> builder;
  final DateTime Function() clock;
  @override
  State<ReferenceListBuilder> createState() => _ReferenceListBuilderState();
}

class _ReferenceListBuilderState extends State<ReferenceListBuilder>
    with WidgetsBindingObserver {
  ApiResult<List<dynamic>>? _result;
  Timer? _timer;
  DateTime? _deadline;
  int _wait = 0;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watch(widget.future);
  }

  @override
  void didUpdateWidget(covariant ReferenceListBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.future != widget.future) _watch(widget.future);
  }

  void _watch(Future<ApiResult<List<dynamic>>> future) {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _wait = 0;
    _loading = true;
    _result = null;
    final generation = ++_generation;
    future.then((result) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _loading = false;
        if (result.failure?.kind == ApiErrorKind.rateLimited) {
          final failure = result.failure!;
          _deadline =
              failure.retryAt ??
              widget.clock().add(
                failure.retryAfter ?? const Duration(seconds: 60),
              );
          _wait = _remaining();
          _startTimer();
        }
      });
    });
  }

  int _remaining() {
    final milliseconds =
        _deadline?.difference(widget.clock()).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  void _syncWait() {
    if (!mounted) return;
    final remaining = _remaining();
    if (remaining != _wait) setState(() => _wait = remaining);
    if (remaining == 0) _timer?.cancel();
  }

  void _startTimer() {
    _timer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (_wait > 0 &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _syncWait());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed) {
      _syncWait();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _result = null;
    _deadline = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final failure = _result?.failure;
    if (failure != null) {
      final guest = failure.kind == ApiErrorKind.unauthenticated;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(switch (failure.kind) {
                ApiErrorKind.forbidden ||
                ApiErrorKind.notFound => 'Akses atau data tidak tersedia.',
                _ => failure.message,
              }, textAlign: TextAlign.center),
              if (_wait > 0)
                Text(
                  failure.retryAfter != null
                      ? 'Tunggu $_wait detik sebelum mencoba kembali.'
                      : 'Jeda lokal $_wait detik. Server tidak memberikan waktu reset kuota.',
                  textAlign: TextAlign.center,
                ),
              if (!guest)
                TextButton(
                  onPressed: _wait > 0
                      ? null
                      : () {
                          if (_loading || _wait > 0) return;
                          setState(() => _watch(widget.retry()));
                        },
                  child: const Text('Coba lagi'),
                ),
            ],
          ),
        ),
      );
    }
    return widget.builder(
      context,
      AsyncSnapshot.withData(ConnectionState.done, _result!.data!),
    );
  }
}
