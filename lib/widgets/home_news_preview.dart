import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reference_data.dart';
import '../screens/berita_detail_screen.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'reference_list_builder.dart';
import 'session_boundary.dart';

/// The /posts contract is newest-first. Preserve that order and deduplicate IDs.
List<Map<String, dynamic>> previewPosts(List<dynamic> posts) {
  final seen = <int>{};
  return posts
      .whereType<Map<String, dynamic>>()
      .where((p) => p['id'] is int && seen.add(p['id'] as int))
      .take(3)
      .toList();
}

class HomeNewsPreview extends StatelessWidget {
  const HomeNewsPreview({super.key, required this.api, required this.openPage});
  final ApiService api;
  final ValueChanged<Widget> openPage;
  @override
  Widget build(BuildContext context) =>
      _NewsContent(api: api, openPage: openPage);
}

class _NewsContent extends StatefulWidget {
  const _NewsContent({required this.api, required this.openPage});
  final ApiService api;
  final ValueChanged<Widget> openPage;
  @override
  State<_NewsContent> createState() => _NewsContentState();
}

class _NewsContentState extends State<_NewsContent>
    with SessionOwnedState<_NewsContent> {
  @override
  SessionService get stateSession => widget.api.session;
  late final Future<ApiResult<List<dynamic>>> _future = _load();
  StreamSubscription<int>? _subscription;
  @override
  void initState() {
    super.initState();
    // A guest preview has no private content to evict. Its public boundary
    // rebuilds on sign-in; redirecting here would overwrite the new Home.
    if (!stateSession.hasSession) return;
    _subscription = stateSession.changes.listen((_) {
      if (mounted && !sessionActive) SessionNavigation.leave(context);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<ApiResult<List<dynamic>>> _load() async {
    try {
      final owner = await stateSession.snapshot();
      if (!sessionActive || owner.revision != stateSession.revision) {
        return ApiResult.failure(
          ApiFailure(kind: ApiErrorKind.staleSession, message: 'Sesi berubah.'),
        );
      }
      if (!owner.isAuthenticated) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.unauthenticated,
            message:
                'Masuk untuk membaca berita Info Diskanla. Gunakan daftar berita di atas.',
          ),
        );
      }
      final result = await widget.api.fetchPosts(expectedSession: owner);
      if (!sessionActive || !stateSession.owns(owner)) {
        return ApiResult.failure(
          ApiFailure(kind: ApiErrorKind.staleSession, message: 'Sesi berubah.'),
        );
      }
      return result;
    } catch (_) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.network,
          message: 'Berita tidak dapat dimuat. Silakan coba kembali.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ReferenceListBuilder(
    future: _future,
    retry: _load,
    builder: (context, snapshot) {
      if (!sessionActive) return const SizedBox.shrink();
      final posts = previewPosts(snapshot.data ?? []);
      if (posts.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Belum ada berita Info Diskanla.'),
        );
      }
      return Column(
        children: [
          for (final post in posts)
            Builder(
              builder: (context) {
                final timestamp = DateTime.tryParse(
                  post['created_at'] as String? ?? '',
                );
                final date = timestamp == null
                    ? '-'
                    : DateFormat('dd MMM yyyy').format(timestamp);
                final image = referenceImage(post) ?? '';
                final title = post['title'] as String? ?? 'Tanpa judul';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('news-preview-${post['id']}'),
                    onTap: () {
                      if (!sessionActive) return;
                      widget.openPage(
                        BeritaDetailScreen(
                          key: ValueKey('news-detail-${post['id']}'),
                          api: widget.api,
                          title: title,
                          content: post['content'] as String? ?? '',
                          date: date,
                          imageUrl: image,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox.square(
                              dimension: 80,
                              child: ColoredBox(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: image.isEmpty
                                    ? const Icon(Icons.newspaper)
                                    : Image.network(
                                        image,
                                        cacheWidth: 240,
                                        fit: BoxFit.cover,
                                        excludeFromSemantics: true,
                                        errorBuilder: (_, error, stack) =>
                                            const Icon(Icons.newspaper),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  date,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}
