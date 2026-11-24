import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/session_boundary.dart';
import '../widgets/profile_identity.dart';
import '../widgets/profile_cooldown_state.dart';

class ForumCommentsScreen extends StatelessWidget {
  const ForumCommentsScreen({
    super.key,
    required this.api,
    required this.postId,
  });
  final ApiService api;
  final int postId;
  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    builder: (_) => _Comments(api: api, postId: postId),
  );
}

class _Comments extends StatefulWidget {
  const _Comments({required this.api, required this.postId});
  final ApiService api;
  final int postId;
  @override
  State<_Comments> createState() => _CommentsState();
}

class _Thread {
  List<Map<String, dynamic>> items = [];
  int page = 0, last = 1, generation = 0, total = 0;
  bool loading = false;
  String? error;
}

class _CommentsState extends State<_Comments>
    with
        SessionOwnedState<_Comments>,
        WidgetsBindingObserver,
        ProfileCooldownState<_Comments> {
  @override
  SessionService get stateSession => widget.api.session;
  SessionSnapshot? _owner;
  final _roots = _Thread();
  final _threads = <int, _Thread>{};
  final _mutations = <int>{};
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<int>? _subscription;
  int? _editing, _replyTo;
  bool _sending = false, _uncertain = false;
  String? _message, _contentError;
  bool get _active =>
      sessionActive && _owner != null && stateSession.owns(_owner!);
  bool get _blocked => !_active || profileWait > 0 || _uncertain;
  bool _owns(Map item) =>
      _active &&
      item['user_id'] == int.tryParse(stateSession.metadata['user_id'] ?? '');

  void _invalidateReads() {
    for (final thread in [_roots, ..._threads.values]) {
      thread.generation++;
      thread.loading = false;
    }
  }

  void _showEditor() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

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
    _draft.clear();
    _roots.items.clear();
    _roots.generation++;
    _threads.clear();
    _mutations.clear();
    _editing = _replyTo = null;
    _message = _contentError = null;
    _sending = _uncertain = false;
  }

  Future<void> _open() async {
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;
    _owner = owner;
    await _load();
  }

  void _fail(ApiFailure failure, {bool mutation = false}) {
    recordProfileFailure(failure);
    _message = failure.kind == ApiErrorKind.notFound
        ? 'Komentar atau induknya sudah tidak tersedia. Muat ulang daftar.'
        : failure.message;
    _contentError = failure.fieldErrors['content']?.join(' ');
    if (failure.fieldErrors.containsKey('parent_id')) {
      _message =
          'Induk balasan tidak valid atau sudah dihapus. Muat ulang daftar.';
    }
    if (mutation &&
        {
          ApiErrorKind.timeout,
          ApiErrorKind.network,
          ApiErrorKind.invalidResponse,
          ApiErrorKind.server,
        }.contains(failure.kind)) {
      _uncertain = true;
      _message =
          'Hasil aksi belum dapat dipastikan. Muat ulang untuk memeriksa keadaan server; jangan kirim ulang otomatis.';
    }
  }

  Future<bool> _load({
    int? parent,
    bool more = false,
    bool afterMutation = false,
  }) async {
    if (!_active ||
        profileWait > 0 ||
        (!afterMutation && (_sending || _mutations.isNotEmpty))) {
      return false;
    }
    final thread = parent == null
        ? _roots
        : _threads.putIfAbsent(parent, _Thread.new);
    if (more && (thread.loading || thread.page >= thread.last)) return false;
    final generation = ++thread.generation;
    final page = more ? thread.page + 1 : 1;
    setState(() {
      thread.loading = true;
      thread.error = null;
    });
    final result = await widget.api.fetchForumPage(
      expectedSession: _owner!,
      postId: widget.postId,
      parentId: parent,
      page: page,
    );
    if (!_active ||
        generation != thread.generation ||
        (parent != null && !identical(_threads[parent], thread))) {
      return false;
    }
    setState(() {
      thread.loading = false;
      if (result.isSuccess) {
        final data = result.data!;
        final merged = <int, Map<String, dynamic>>{
          if (more)
            for (final c in thread.items) c['id'] as int: c,
          for (final c in data.items) c['id'] as int: c,
        };
        thread.items = merged.values.toList()
          ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
        thread.page = data.currentPage;
        thread.last = data.lastPage;
        thread.total = data.total;
        if (parent == null && !more) {
          _threads.removeWhere(
            (id, _) => !thread.items.any((c) => c['id'] == id),
          );
        }
      } else {
        _fail(result.failure!);
        thread.error = _message;
        if (result.failure!.kind == ApiErrorKind.notFound) {
          thread.items.clear();
          thread.page = thread.last = 1;
          thread.total = 0;
          if (parent == null) _threads.clear();
          if (parent != null) {
            _roots.items.removeWhere((c) => c['id'] == parent);
            _threads.remove(parent);
            if (_replyTo == parent) _replyTo = null;
          }
        }
      }
    });
    return result.isSuccess;
  }

  Future<void> _refresh() async {
    if (_sending || _mutations.isNotEmpty) return;
    final parents = _threads.keys.toList();
    var ok = await _load();
    for (final parent in parents) {
      if (_threads.containsKey(parent)) ok = await _load(parent: parent) && ok;
    }
    if (!_active) return;
    setState(() {
      if (ok) {
        _uncertain = false;
        _message = null;
      }
    });
  }

  Map<String, dynamic>? _find(int id) {
    for (final c in [
      ..._roots.items,
      for (final t in _threads.values) ...t.items,
    ]) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  Future<void> _send() async {
    if (_blocked || _sending || _mutations.isNotEmpty) return;
    if (_draft.text.trim().isEmpty || _draft.text.runes.length > 5000) {
      setState(() => _contentError = 'Isi wajib, maksimal 5000 karakter.');
      return;
    }
    final edit = _editing, parent = _replyTo;
    final existing = edit == null ? null : _find(edit);
    if (edit != null && (existing == null || !_owns(existing))) return;
    setState(() {
      _invalidateReads();
      _sending = true;
      _contentError = null;
      _message = null;
    });
    final result = edit != null
        ? await widget.api.editComment(
            edit,
            _draft.text,
            expectedSession: _owner!,
          )
        : await widget.api.storeComment(
            widget.postId,
            _draft.text,
            parentId: parent,
            expectedSession: _owner!,
          );
    if (!_active) return;
    if (result.isSuccess) {
      final data = result.data! as Map<String, dynamic>;
      if (data['community_post_id'] != widget.postId ||
          (existing != null &&
              (data['parent_id'] != existing['parent_id'] ||
                  data['user_id'] != existing['user_id']))) {
        _fail(
          ApiFailure(
            kind: ApiErrorKind.invalidResponse,
            message: 'Respons komentar tidak valid.',
          ),
          mutation: true,
        );
      } else {
        if (existing != null) existing.addAll(data);
        _draft.clear();
        _editing = _replyTo = null;
        if (edit == null) {
          var ok = await _load(afterMutation: true);
          if (parent != null && _roots.items.any((c) => c['id'] == parent)) {
            ok = await _load(parent: parent, afterMutation: true) && ok;
          }
          if (!_active) return;
          if (!ok) {
            _uncertain = true;
            _message =
                'Komentar tersimpan, tetapi daftar belum diperbarui. Muat ulang; jangan kirim ulang.';
          }
        }
      }
    } else {
      _fail(result.failure!, mutation: true);
    }
    if (_active) setState(() => _sending = false);
  }

  Future<void> _like(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    if (_blocked || _sending || !_mutations.add(id)) return;
    _invalidateReads();
    setState(() {});
    final result = await widget.api.setCommentLike(
      id,
      !item['is_liked_by_me'],
      expectedSession: _owner!,
    );
    if (!_active) return;
    setState(() {
      _mutations.remove(id);
      if (result.isSuccess) {
        // Resolve by identity again: refresh may have replaced the old object.
        _find(id)?.addAll(result.data! as Map<String, dynamic>);
      } else {
        _fail(result.failure!, mutation: true);
      }
    });
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    if (_blocked || _sending || _mutations.isNotEmpty || !_owns(item)) return;
    final parent = item['parent_id'] as int?;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Komentar?'),
        content: Text(
          parent == null
              ? 'Komentar utama dan seluruh balasannya, termasuk balasan pengguna lain, serta suka terkait akan dihapus permanen.'
              : 'Hapus balasan ini permanen? Komentar induk tetap tersedia.',
        ),
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
    if (!_active ||
        confirmed != true ||
        _blocked ||
        _sending ||
        _mutations.isNotEmpty) {
      return;
    }
    setState(() {
      _invalidateReads();
      _mutations.add(id);
    });
    final result = await widget.api.deleteComment(id, expectedSession: _owner!);
    if (!_active) return;
    if (result.isSuccess || result.failure?.kind == ApiErrorKind.notFound) {
      if (_editing == id || _replyTo == id) {
        _draft.clear();
        _editing = _replyTo = null;
      }
      if (parent == null) _threads.remove(id);
      var ok = await _load(afterMutation: true);
      if (parent != null && _threads.containsKey(parent)) {
        ok = await _load(parent: parent, afterMutation: true) && ok;
      }
      if (!_active) return;
      if (!ok) {
        _uncertain = true;
        _message =
            'Daftar belum diperbarui. Muat ulang sebelum aksi berikutnya.';
      }
    } else {
      _fail(result.failure!, mutation: true);
    }
    if (_active) setState(() => _mutations.remove(id));
  }

  Widget _comment(Map<String, dynamic> item, {bool reply = false}) {
    final id = item['id'] as int;
    final disabled = _blocked || _sending || _mutations.contains(id);
    return Padding(
      padding: EdgeInsets.fromLTRB(reply ? 20 : 0, 8, 0, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileIdentity(
                api: widget.api,
                profile: item['profile'],
                fallbackName: item['author_name'],
              ),
              Text(item['content']),
              Text('${item['likes_count']} suka'),
              Wrap(
                children: [
                  IconButton(
                    tooltip: item['is_liked_by_me']
                        ? 'Batal suka komentar'
                        : 'Suka komentar',
                    onPressed: disabled ? null : () => _like(item),
                    icon: Icon(
                      item['is_liked_by_me']
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                  ),
                  TextButton(
                    onPressed: disabled
                        ? null
                        : () => setState(() {
                            _editing = null;
                            _replyTo = item['parent_id'] ?? id;
                            _draft.clear();
                            _contentError = null;
                            _showEditor();
                          }),
                    child: const Text('Balas'),
                  ),
                  if (_owns(item)) ...[
                    IconButton(
                      tooltip: 'Edit komentar',
                      onPressed: disabled
                          ? null
                          : () => setState(() {
                              _editing = id;
                              _replyTo = null;
                              _draft.text = item['content'];
                              _contentError = null;
                              _showEditor();
                            }),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Hapus komentar',
                      onPressed: disabled ? null : () => _delete(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                  if (!reply)
                    TextButton(
                      onPressed: disabled ? null : () => _load(parent: id),
                      child: Text('Lihat balasan (${item['replies_count']})'),
                    ),
                ],
              ),
              if (!reply && _threads[id] != null)
                _listing(_threads[id]!, parent: id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listing(_Thread thread, {int? parent}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (thread.loading) const LinearProgressIndicator(),
      if (thread.error != null) Text(thread.error!),
      if (!thread.loading && thread.items.isEmpty && thread.error == null)
        Text(parent == null ? 'Belum ada komentar.' : 'Belum ada balasan.'),
      for (final item in thread.items) _comment(item, reply: parent != null),
      if (thread.page < thread.last || thread.error != null)
        TextButton(
          onPressed:
              thread.loading ||
                  profileWait > 0 ||
                  _sending ||
                  _mutations.isNotEmpty
              ? null
              : () => _load(parent: parent, more: thread.page > 0),
          child: Text(
            parent == null
                ? 'Muat komentar berikutnya'
                : 'Muat balasan berikutnya',
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Komentar')),
    body: SafeArea(
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(12),
        children: [
          if (_message != null) Text(_message!),
          if (profileWait > 0) Text(profileWaitMessage),
          TextButton(
            onPressed:
                !_active || _sending || _mutations.isNotEmpty || profileWait > 0
                ? null
                : _refresh,
            child: const Text('Muat ulang komentar'),
          ),
          Text(
            _editing != null
                ? 'Edit komentar'
                : _replyTo != null
                ? 'Balasan untuk komentar #$_replyTo'
                : 'Komentar baru',
          ),
          TextField(
            controller: _draft,
            enabled: !_sending,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Tulis komentar',
              errorText: _contentError,
              border: const OutlineInputBorder(),
            ),
          ),
          Wrap(
            children: [
              ElevatedButton(
                onPressed: _blocked || _sending || _mutations.isNotEmpty
                    ? null
                    : _send,
                child: Text(
                  _sending
                      ? 'Memproses...'
                      : _editing != null
                      ? 'Simpan komentar'
                      : 'Kirim',
                ),
              ),
              if (_editing != null || _replyTo != null)
                TextButton(
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                          _editing = _replyTo = null;
                          _draft.clear();
                          _contentError = null;
                        }),
                  child: const Text('Batal'),
                ),
            ],
          ),
          Text('${_roots.total} komentar utama'),
          _listing(_roots),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    _subscription?.cancel();
    _clear();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
