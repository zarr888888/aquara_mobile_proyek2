import '../widgets/session_boundary.dart';
import 'dart:async';
import '../models/app_notification.dart';
import '../services/api_result.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'pasar_screen.dart';
import 'forum_screen.dart';
import 'consultation_screen.dart';

class NotifikasiScreen extends StatelessWidget {
  const NotifikasiScreen({super.key, this.api});
  final ApiService? api;
  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) => _NotifikasiScreenContent(api: api),
  );
}

class _NotifikasiScreenContent extends StatefulWidget {
  const _NotifikasiScreenContent({this.api});
  final ApiService? api;
  @override
  State<_NotifikasiScreenContent> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<_NotifikasiScreenContent>
    with SessionOwnedState<_NotifikasiScreenContent> {
  List<AppNotification> _items = [];
  bool _loading = false;
  bool _opening = false;
  String? _error;
  int _wait = 0;
  bool _serverWait = false;
  Timer? _timer;
  late final _api = widget.api ?? ApiService();
  @override
  get stateSession => _api.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _blocked => _loading || _opening || _wait > 0;

  void _failure(ApiFailure failure) {
    _error = switch (failure.kind) {
      ApiErrorKind.forbidden ||
      ApiErrorKind.notFound => 'Akses atau data notifikasi tidak tersedia.',
      _ => failure.message,
    };
    if (failure.kind == ApiErrorKind.rateLimited) {
      _serverWait = failure.retryAfter != null;
      _wait = (failure.retryAfter ?? const Duration(seconds: 60)).inSeconds;
      _timer?.cancel();
      if (_wait > 0) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!sessionActive) {
            timer.cancel();
            return;
          }
          setState(() {
            if (_wait > 0) _wait--;
          });
          if (_wait == 0) timer.cancel();
        });
      }
    }
  }

  Future<void> _load() async {
    if (!sessionActive || _blocked) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final owner = await _api.session.snapshot();
      if (!sessionActive || !_api.session.owns(owner)) return;
      final result = await _api.fetchNotifications(expectedSession: owner);
      if (!sessionActive || !_api.session.owns(owner)) return;
      setState(() {
        if (result.isSuccess) {
          _items = result.data!;
        } else {
          _failure(result.failure!);
        }
      });
    } catch (_) {
      if (sessionActive) {
        setState(
          () => _error = 'Notifikasi tidak dapat dimuat. Silakan coba kembali.',
        );
      }
    } finally {
      if (sessionActive) setState(() => _loading = false);
    }
  }

  Future<void> _open(AppNotification item) async {
    if (!sessionActive || _blocked) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final owner = await _api.session.snapshot();
      if (!sessionActive || !_api.session.owns(owner)) return;
      if (!item.isRead) {
        final result = await _api.markNotificationRead(
          item.id,
          expectedSession: owner,
        );
        if (!sessionActive || !_api.session.owns(owner)) return;
        setState(() {
          if (result.isSuccess) {
            _items = _items
                .map((n) => n.id == item.id ? n.asRead() : n)
                .toList();
          } else {
            _failure(result.failure!);
          }
        });
        // Keep failure visible; the user can retry manually, never automatically.
        if (!result.isSuccess) return;
      }
      if (!sessionActive || !_api.session.owns(owner)) return;
      // Existing destinations are lists/hub, not reference-based detail routes.
      // Nullable/invalid references are never interpolated into URLs or routes.
      final Widget? destination = switch (item.type) {
        'pasar' => PasarScreen(api: _api),
        'forum' => ForumScreen(api: _api),
        'ai' => SessionBoundary(
          api: _api,
          builder: (_) => const ConsultationScreen(),
        ),
        _ => null,
      };
      if (destination == null) {
        setState(() => _error = 'Tujuan notifikasi belum tersedia.');
        return;
      }
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => destination));
    } catch (_) {
      if (sessionActive) {
        setState(
          () => _error =
              'Notifikasi tidak dapat dibuka. Periksa status sebelum mencoba kembali.',
        );
      }
    } finally {
      if (sessionActive) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _items = [];
    super.dispose();
  }

  IconData _getIcon(String type) {
    if (type == 'pasar') return Icons.storefront_outlined;
    if (type == 'forum') return Icons.forum_outlined;
    if (type == 'ai') return Icons.smart_toy_outlined;
    return Icons.notifications_none;
  }

  Color _getColor(String type) {
    if (type == 'pasar') return Colors.orange;
    if (type == 'forum') return Colors.purple;
    if (type == 'ai') return Colors.teal;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Notifikasi",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF009FE3),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _blocked ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          if (_wait > 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _serverWait
                    ? 'Tunggu $_wait detik sebelum mencoba kembali.'
                    : 'Jeda lokal $_wait detik. Server tidak memberikan waktu reset kuota.',
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_items.isEmpty) {
                  return Center(
                    child: Text(
                      _error == null
                          ? 'Belum ada notifikasi.'
                          : 'Gunakan Muat ulang untuk mencoba kembali.',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final n = _items[index];

                    return GestureDetector(
                      key: ValueKey('notification-${n.id}'),
                      onTap: _blocked ? null : () => _open(n),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: n.isRead
                              ? Colors.white
                              : Colors.blue.shade50.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: _getColor(
                                n.type,
                              ).withValues(alpha: 0.1),
                              child: Icon(
                                _getIcon(n.type),
                                color: _getColor(n.type),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    n.message,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    n.createdAt == null
                                        ? 'Tanggal tidak tersedia'
                                        : DateFormat(
                                            'dd MMM yyyy, HH:mm',
                                          ).format(n.createdAt!),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
