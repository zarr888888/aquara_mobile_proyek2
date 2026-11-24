import 'dart:async';
import 'package:flutter/material.dart';
import '../services/omni_search.dart';
import '../services/api_service.dart';
import '../services/api_result.dart';
import '../screens/pasar_screen.dart';
import '../screens/forum_comments_screen.dart';
import '../screens/berita_detail_screen.dart';
import 'session_boundary.dart';

const guestContentSearchHint =
    'Login untuk mencari konten Pasar, Forum, dan Berita.';

class OmniResults extends StatefulWidget {
  const OmniResults({super.key, required this.api, required this.query});
  final ApiService api;
  final String query;
  @override
  State<OmniResults> createState() => OmniResultsState();
}

class OmniResultsState extends State<OmniResults>
    with SessionOwnedState<OmniResults> {
  @override
  get stateSession => widget.api.session;
  final Groups _groups = {};
  int _generation = 0;
  bool _searching = false, _opening = false;
  String? _message;
  DateTime? _searchWait, _detailWait;
  Timer? _timer;
  int _seconds(DateTime? until) =>
      ((until?.difference(DateTime.now()).inMilliseconds ?? 0) / 1000).ceil();
  @override
  void didUpdateWidget(OmniResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.trim() != widget.query.trim()) {
      _generation++;
      _groups.clear();
      _searching = false;
      _opening = false;
      _message = null;
    }
  }

  void _failure(ApiFailure failure, {required bool detail}) {
    _message = switch (failure.kind) {
      ApiErrorKind.notFound => 'Konten tidak tersedia.',
      ApiErrorKind.validation => 'Periksa kata pencarian (1–100 karakter).',
      _ => failure.message,
    };
    if (failure.kind != ApiErrorKind.rateLimited) return;
    final until =
        failure.retryAt ??
        DateTime.now().add(failure.retryAfter ?? const Duration(seconds: 60));
    if (detail) {
      _detailWait = until;
    } else {
      _searchWait = until;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds(_searchWait) <= 0 && _seconds(_detailWait) <= 0) {
        _timer?.cancel();
        _timer = null;
      }
      if (sessionActive) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> search([ContentKind? group]) async {
    if (!sessionActive ||
        !stateSession.hasSession ||
        _searching ||
        _seconds(_searchWait) > 0) {
      return;
    }
    final query = widget.query.trim();
    if (query.isEmpty || query.runes.length > 100) {
      setState(() => _message = 'Masukkan 1–100 karakter.');
      return;
    }
    FocusScope.of(context).unfocus();
    final generation = _generation;
    final page = group == null ? 1 : _groups[group]!.page + 1;
    setState(() {
      _searching = true;
      _message = null;
    });
    final owner = await stateSession.snapshot();
    if (!sessionActive || generation != _generation) return;
    final result = await widget.api.searchContent(
      query,
      owner,
      group: group,
      page: page,
    );
    if (!sessionActive || generation != _generation) return;
    setState(() {
      _searching = false;
      if (!result.isSuccess) {
        _failure(result.failure!, detail: false);
        return;
      }
      for (final kind in group == null ? ContentKind.values : [group]) {
        final next = result.data![kind]!;
        final byId = {
          for (final hit in [
            if (group != null) ..._groups[kind]!.hits,
            ...next.hits,
          ])
            hit.id: hit,
        };
        _groups[kind] = (
          hits: byId.values.toList(),
          page: next.page,
          more: next.more,
        );
      }
    });
  }

  Future<void> _open(ContentKind kind, int id) async {
    if (!sessionActive || _opening || _seconds(_detailWait) > 0) return;
    final generation = _generation;
    setState(() {
      _opening = true;
      _message = null;
    });
    try {
      final owner = await stateSession.snapshot();
      if (!sessionActive || generation != _generation) return;
      final result = await widget.api.contentDetail(kind, id, owner);
      if (!sessionActive || generation != _generation) return;
      if (!result.isSuccess) {
        setState(() => _failure(result.failure!, detail: true));
        return;
      }
      final data = result.data!;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final api = widget.api;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => switch (kind) {
            ContentKind.pasar => PasarScreen(api: api, product: data),
            ContentKind.berita => BeritaDetailScreen(
              api: api,
              title: data['title'],
              content: data['content'],
              date: data['date'],
              imageUrl: data['image'],
            ),
            ContentKind.forum => SessionBoundary(
              api: api,
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Posting Forum')),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(data['author_name']),
                    Text(data['content']),
                    if (data['image'] != null)
                      Image.network(
                        data['image'],
                        errorBuilder: (_, e, s) =>
                            const Icon(Icons.broken_image),
                      ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ForumCommentsScreen(api: api, postId: id),
                        ),
                      ),
                      child: Text('${data['comments_count']} komentar'),
                    ),
                  ],
                ),
              ),
            ),
          },
        ),
      );
    } finally {
      if (sessionActive && generation == _generation) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!stateSession.hasSession) {
      return const Text(guestContentSearchHint);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: _searching || _seconds(_searchWait) > 0 ? null : search,
          child: const Text('Cari konten'),
        ),
        if (_seconds(_searchWait) > 0)
          Text('Cari kembali dalam ${_seconds(_searchWait)} detik.'),
        if (_seconds(_detailWait) > 0)
          Text('Buka konten dalam ${_seconds(_detailWait)} detik.'),
        if (_message != null) Text(_message!),
        if (_searching || _opening) const LinearProgressIndicator(),
        for (final entry in _groups.entries) ...[
          Text(entry.key.label, style: Theme.of(context).textTheme.titleMedium),
          if (entry.value.hits.isEmpty) const Text('Tidak ada hasil.'),
          for (final hit in entry.value.hits)
            ListTile(
              key: ValueKey('${entry.key.name}-${hit.id}'),
              title: Text(hit.title ?? hit.summary ?? 'Posting Forum'),
              subtitle: hit.title != null && hit.summary != null
                  ? Text(hit.summary!)
                  : null,
              onTap: _opening || _seconds(_detailWait) > 0
                  ? null
                  : () => _open(entry.key, hit.id),
            ),
          if (entry.value.more)
            TextButton(
              onPressed: _searching || _seconds(_searchWait) > 0
                  ? null
                  : () => search(entry.key),
              child: Text('Muat lagi ${entry.key.label}'),
            ),
        ],
      ],
    );
  }
}
