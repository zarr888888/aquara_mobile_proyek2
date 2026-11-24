import 'dart:async';

import 'package:flutter/material.dart';

import '../models/external_info.dart';
import '../widgets/maritime_weather.dart';
import '../widgets/curated_info.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';

class ExternalInfoScreen extends StatefulWidget {
  const ExternalInfoScreen({super.key, required this.kind, required this.api});
  final ExternalInfoKind kind;
  final ApiService api;

  @override
  State<ExternalInfoScreen> createState() => _ExternalInfoScreenState();
}

class _ExternalInfoScreenState extends State<ExternalInfoScreen>
    with WidgetsBindingObserver {
  ExternalInfo? _data;
  ApiFailure? _failure;
  bool _busy = false;
  Timer? _timer;
  String _code = 'XJ022';
  int _generation = 0;
  bool get _weather => widget.kind == ExternalInfoKind.cuaca;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _updateTimer(); // Countdown only; never fetch on resume.
    }
  }

  void _updateTimer() {
    _timer?.cancel();
    if (widget.api.externalInfoRequests.remaining <= Duration.zero) {
      final bulletin = _data;
      if (bulletin is WeatherBulletin) {
        final now = widget.api.externalInfoRequests.now;
        final boundaries = [
          bulletin.from,
          bulletin.to,
          ...bulletin.slots.map((s) => s.validAt),
        ]..sort();
        final next = boundaries.where((t) => t.isAfter(now)).firstOrNull;
        if (next != null) {
          _timer = Timer(next.difference(now), () {
            if (!mounted) return;
            setState(() {});
            _updateTimer();
          });
        }
      }
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (widget.api.externalInfoRequests.remaining <= Duration.zero) {
        timer.cancel();
      }
    });
  }

  Future<void> _load({String? code}) async {
    if (!mounted || (_busy && code == null)) return;
    final generation = ++_generation;
    setState(() {
      if (code != null) _code = code;
      if (_weather) {
        _data = null;
        _failure = null;
      }
      _busy = true;
    });
    final result = await widget.api.fetchExternalInfo(widget.kind, code: _code);
    if (!mounted || generation != _generation) return;
    setState(() {
      _busy = false;
      _failure = result.failure;
      if (result.isSuccess) _data = result.data;
    });
    _updateTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requests = widget.api.externalInfoRequests;
    final seconds = (requests.remaining.inMilliseconds / 1000).ceil();
    final data = _data;
    final wait = seconds <= 0
        ? null
        : requests.usesServerWait
        ? 'Tunggu $seconds detik sesuai Retry-After server. Berlaku untuk KKP, Cuaca, dan TPI.'
        : 'Jeda aplikasi: $seconds detik. Ini kebijakan aplikasi, bukan waktu reset server. Berlaku untuk KKP, Cuaca, dan TPI.';
    if (_weather) {
      return MaritimeWeather(
        code: _code,
        bulletin: data as WeatherBulletin?,
        now: requests.now,
        busy: _busy,
        failure: _failure?.message,
        wait: wait,
        reload: _busy || seconds > 0 ? null : _load,
        select: (code) => _load(code: code),
      );
    }
    return CuratedInfo(
      kind: widget.kind,
      data: data,
      busy: _busy,
      failure: _failure != null,
      wait: wait,
      reload: _busy || seconds > 0 ? null : _load,
    );
  }
}
