import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/session_boundary.dart';

class ForumScreen extends StatelessWidget {
  const ForumScreen({super.key, this.api, this.mine = false, this.clock});
  final ApiService? api;
  final bool mine;
  final DateTime Function()? clock;
  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) => _ForumScreenContent(api: api, mine: mine, clock: clock),
  );
}

class _ForumScreenContent extends StatefulWidget {
  const _ForumScreenContent({this.api, required this.mine, this.clock});
  final ApiService? api;
  final bool mine;
  final DateTime Function()? clock;
  @override
  State<_ForumScreenContent> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<_ForumScreenContent>
    with SessionOwnedState<_ForumScreenContent>, WidgetsBindingObserver {
  late final ApiService _api = widget.api ?? ApiService();
  @override
  SessionService get stateSession => _api.session;
  SessionSnapshot? _owner;
  List<dynamic> _posts = [];
  bool _loading = true, _busy = false, _uncertain = false;
  String? _message;
  DateTime? _retryAt;
  bool _localWait = false;
  Timer? _timer;
  bool _foreground = true;
  StreamSubscription<int>? _subscription;
  final _updates = ValueNotifier<int>(0);
  final _draft = TextEditingController();
  File? _image;
  Future<bool>? _readFlight;
  DateTime _now() => (widget.clock ?? DateTime.now)();
  bool get _active =>
      sessionActive && _owner != null && stateSession.owns(_owner!);
  int get _remaining {
    final ms = _retryAt?.difference(_now()).inMilliseconds ?? 0;
    return ms > 0 ? (ms / 1000).ceil() : 0;
  }

  bool get _blocked => !_active || _busy || _remaining > 0 || _uncertain;
  bool _owns(Map item) {
    final id = int.tryParse(stateSession.metadata['user_id'] ?? '');
    return id != null && id > 0 && item['user_id'] == id;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) {
        _timer?.cancel();
        _posts.clear();
        _draft.clear();
        _image = null;
        _message = null;
        _updates.value++;
      }
    });
    _open();
  }

  Future<void> _open() async {
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;
    _owner = owner;
    await _refresh();
  }

  void _paint() {
    if (!_active) return;
    setState(() {});
    _updates.value++;
  }

  void _failure(ApiFailure failure, {bool mutation = false}) {
    _message = switch (failure.kind) {
      ApiErrorKind.forbidden ||
      ApiErrorKind.notFound => 'Akses atau data Forum tidak tersedia.',
      ApiErrorKind.validation =>
        '${failure.message} Periksa isi teks atau gambar. Draft tetap tersedia.',
      _ => failure.message,
    };
    if (mutation &&
        {
          ApiErrorKind.timeout,
          ApiErrorKind.network,
          ApiErrorKind.invalidResponse,
        }.contains(failure.kind)) {
      _uncertain = true;
      _message =
          'Hasil aksi belum dapat dipastikan. Periksa ulang daftar sebelum mengulang.';
    }
    if (failure.kind == ApiErrorKind.rateLimited) {
      _localWait = failure.retryAt == null && failure.retryAfter == null;
      _retryAt =
          failure.retryAt ??
          _now().add(failure.retryAfter ?? const Duration(seconds: 60));
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remaining == 0 || !_active || !_foreground) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining == 0 || !_active) _timer?.cancel();
      _paint();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _timer?.cancel();
    if (state == AppLifecycleState.resumed) {
      _paint();
      _startTimer();
    }
  }

  Future<bool> _refresh({bool afterMutation = false}) {
    if (_readFlight != null) return _readFlight!;
    if (!_active || _remaining > 0) return Future.value(false);
    final flight = _read(afterMutation);
    _readFlight = flight;
    return flight.whenComplete(() => _readFlight = null);
  }

  Future<bool> _read(bool afterMutation) async {
    _loading = true;
    _paint();
    final result = await _api.fetchForumPosts(
      expectedSession: _owner!,
      mine: widget.mine,
    );
    if (!_active) return false;
    _loading = false;
    if (result.isSuccess) {
      _posts = List.of(result.data!);
      _uncertain = false;
      _message = afterMutation ? 'Aksi berhasil. Daftar diperbarui.' : null;
    } else {
      _failure(result.failure!);
      if (afterMutation) {
        _message =
            'Aksi sudah berhasil, tetapi daftar belum diperbarui. Muat ulang daftar; jangan ulangi aksi. $_message';
        _uncertain = true;
      }
    }
    _paint();
    return result.isSuccess;
  }

  Future<bool> _mutate(
    Future<ApiResult<Object?>> Function(SessionSnapshot) action, {
    Map<String, dynamic>? likePost,
  }) async {
    if (_blocked || _loading) return false;
    final owner = _owner!;
    _busy = true;
    _message = null;
    _paint();
    final result = await action(owner);
    if (!_active) return false;
    if (result.isSuccess) {
      if (likePost != null) likePost['is_liked_by_me'] = result.data == 'liked';
      await _refresh(afterMutation: true);
    } else {
      _failure(result.failure!, mutation: true);
    }
    if (!_active) return false;
    _busy = false;
    _paint();
    return result.isSuccess;
  }

  Future<void> _delete(
    Map<String, dynamic> item, {
    bool comment = false,
  }) async {
    if (!_owns(item) || _blocked) return;
    final owner = _owner!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(comment ? 'Hapus Komentar?' : 'Hapus Postingan?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!_active || !stateSession.owns(owner) || confirmed != true) return;
    await _mutate(
      (s) => comment
          ? _api.deleteComment(item['id'], expectedSession: s)
          : _api.deleteForumPost(item['id'], expectedSession: s),
    );
  }

  Future<void> _editor({
    Map<String, dynamic>? post,
    bool comments = false,
  }) async {
    if (!_active || _busy || (!comments && post != null && !_owns(post))) {
      return;
    }
    _draft.text = comments ? '' : post?['content'] ?? '';
    _image = null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => ValueListenableBuilder<int>(
        valueListenable: _updates,
        builder: (context, value, child) {
          if (!_active) return const SizedBox.shrink();
          Map<String, dynamic>? current = post;
          if (comments) {
            for (final p in _posts) {
              if (p['id'] == post!['id']) current = p;
            }
          }
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 12,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .65,
                child: ListView(
                  children: [
                    Text(
                      comments
                          ? 'Komentar'
                          : post == null
                          ? 'Buat Topik Baru'
                          : 'Edit Postingan',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (comments) ...[
                      if ((current!['comments'] as List).isEmpty)
                        const Text('Belum ada komentar.'),
                      for (final c in current['comments'])
                        ListTile(
                          leading: _avatar(c['avatar']),
                          title: Text(c['author_name']),
                          subtitle: Text(c['content']),
                          trailing: _owns(c)
                              ? IconButton(
                                  tooltip: 'Hapus komentar',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: _blocked
                                      ? null
                                      : () => _delete(c, comment: true),
                                )
                              : null,
                          onTap: _blocked
                              ? null
                              : () => _draft.text = '@${c['author_name']} ',
                        ),
                    ],
                    if (_message != null || _remaining > 0) _status(),
                    TextField(
                      controller: _draft,
                      minLines: 3,
                      maxLines: 6,
                      enabled: !_busy,
                      maxLength: !comments && post != null ? null : 5000,
                      decoration: InputDecoration(
                        labelText: comments
                            ? 'Tulis komentar'
                            : 'Apa yang ingin didiskusikan?',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (!comments) ...[
                      if (_image != null)
                        Image.file(
                          _image!,
                          height: 100,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.broken_image),
                        )
                      else if (post?['image'] != null)
                        _photo(post!['image'], height: 100),
                      TextButton.icon(
                        onPressed: _blocked
                            ? null
                            : () async {
                                final owner = _owner!;
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 70,
                                  maxWidth: 1280,
                                  maxHeight: 1280,
                                );
                                if (!_active ||
                                    !stateSession.owns(owner) ||
                                    !sheetContext.mounted ||
                                    picked == null) {
                                  return;
                                }
                                _image = File(picked.path);
                                _paint();
                              },
                        icon: const Icon(Icons.image),
                        label: const Text('Tambahkan / Ganti Foto'),
                      ),
                      if (_image != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  _image = null;
                                  _paint();
                                },
                          child: const Text('Batalkan gambar baru'),
                        ),
                    ],
                    ElevatedButton(
                      onPressed: _blocked || _loading
                          ? null
                          : () async {
                              final ok = await _mutate(
                                (s) => comments
                                    ? _api.storeComment(
                                        post!['id'],
                                        _draft.text,
                                        expectedSession: s,
                                      )
                                    : post == null
                                    ? _api.postForum(
                                        _draft.text,
                                        _image,
                                        expectedSession: s,
                                      )
                                    : _api.updateForumPost(
                                        post['id'],
                                        _draft.text,
                                        _image,
                                        expectedSession: s,
                                      ),
                              );
                              if (!_active || !sheetContext.mounted) return;
                              if (ok) {
                                _draft.clear();
                                _image = null;
                                if (!comments) Navigator.pop(sheetContext);
                              }
                            },
                      child: Text(
                        _busy
                            ? 'Memproses...'
                            : comments
                            ? 'Kirim'
                            : post == null
                            ? 'Posting'
                            : 'Simpan Perubahan',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!_active) return;
    _draft.clear();
    _image = null;
  }

  Widget _status() => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_message != null) Text(_message!),
        if (_remaining > 0)
          Text(
            _localWait
                ? 'Jeda lokal $_remaining detik; waktu reset server tidak diketahui.'
                : 'Coba kembali dalam $_remaining detik.',
          ),
        TextButton(
          onPressed: _remaining > 0 || _busy || _loading
              ? null
              : () => _refresh(),
          child: const Text('Periksa ulang daftar'),
        ),
      ],
    ),
  );
  Widget _avatar(String? url) => CircleAvatar(
    child: url == null
        ? const Icon(Icons.person)
        : ClipOval(child: _photo(url, height: 40)),
  );
  Widget _photo(String url, {double? height}) => Image.network(
    url,
    height: height,
    fit: BoxFit.contain,
    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
  );
  String _date(Object? raw) {
    final date = raw is String ? DateTime.tryParse(raw) : null;
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.mine ? 'Forum Saya' : 'Forum Komunitas',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF009FE3),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: _loading || _busy || _remaining > 0
              ? null
              : () => _refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _blocked || _loading ? null : () => _editor(),
      backgroundColor: const Color(0xFF009FE3),
      child: const Icon(Icons.add, color: Colors.white),
    ),
    body: Column(
      children: [
        if (_message != null || _remaining > 0) _status(),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _loading && _posts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
              ? Center(
                  child: Text(
                    _message == null
                        ? 'Belum ada diskusi.'
                        : 'Daftar belum tersedia.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 88),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index] as Map<String, dynamic>;
                    return Card(
                      key: ValueKey('forum-${post['id']}'),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: _avatar(post['avatar']),
                            title: Text(
                              post['author_name'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(_date(post['created_at'])),
                            trailing: _owns(post)
                                ? PopupMenuButton<String>(
                                    enabled: !_blocked && !_loading,
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editor(post: post);
                                      } else {
                                        _delete(post);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Hapus'),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                          if (post['image'] != null)
                            Center(child: _photo(post['image'], height: 240)),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              post['content'],
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                          Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Suka',
                                onPressed: _blocked || _loading
                                    ? null
                                    : () => _mutate(
                                        (s) => _api.toggleLikePost(
                                          post['id'],
                                          expectedSession: s,
                                        ),
                                        likePost: post,
                                      ),
                                icon: Icon(
                                  post['is_liked_by_me']
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: post['is_liked_by_me']
                                      ? Colors.red
                                      : null,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Komentar',
                                onPressed: () =>
                                    _editor(post: post, comments: true),
                                icon: const Icon(Icons.chat_bubble_outline),
                              ),
                              IconButton(
                                tooltip: 'Bagikan',
                                onPressed: () => Share.share(
                                  'Cek diskusi ini dari ${post['author_name']}:\n\n${post['content']}',
                                ),
                                icon: const Icon(Icons.share_outlined),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '${post['likes_count']} suka · ${post['comments_count']} komentar',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _timer?.cancel();
    _posts.clear();
    _draft.dispose();
    _image = null;
    _updates.dispose();
    super.dispose();
  }
}
