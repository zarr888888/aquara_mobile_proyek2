import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/perizinan_guide.dart';

typedef GuideLauncher = Future<bool> Function(Uri uri);

Future<bool> _openBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Public local guide: intentionally has no API, session, storage or form.
class PerizinanScreen extends StatefulWidget {
  const PerizinanScreen({super.key, this.launcher = _openBrowser});
  final GuideLauncher launcher;

  @override
  State<PerizinanScreen> createState() => _PerizinanScreenState();
}

mixin _GuideLinks<T extends StatefulWidget> on State<T> {
  GuideLauncher get launcher;
  bool _opening = false;

  Future<void> _open(GuideSource source) async {
    if (_opening || !isApprovedGuideUrl(source.url)) return;
    setState(() => _opening = true);
    var opened = false;
    try {
      opened = await launcher(Uri.parse(source.url));
    } catch (_) {
      // Never expose platform errors or change the SAMUDERA session.
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Halaman resmi belum dapat dibuka. Coba kembali secara manual atau gunakan kontak Diskanla.',
        ),
      ),
    );
  }

  Widget _source(GuideSource source, String topic) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sumber: ${source.name}'),
        Text('Diperiksa: ${source.checked}'),
        if (source.published != null) Text('Publikasi: ${source.published}'),
        const SizedBox(height: 8),
        OutlinedButton(
          key: ValueKey('guide-link-$topic-${source.id}'),
          onPressed: _opening ? null : () => _open(source),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${source.action}\n${Uri.parse(source.url).host}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );

  Widget action(
    GuideSource source,
    String id, {
    bool primary = false,
    String? label,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '${label ?? source.action}\n${Uri.parse(source.url).host}',
        textAlign: TextAlign.center,
      ),
    );
    return primary
        ? FilledButton(
            key: ValueKey(id),
            onPressed: _opening ? null : () => _open(source),
            child: child,
          )
        : OutlinedButton(
            key: ValueKey(id),
            onPressed: _opening ? null : () => _open(source),
            child: child,
          );
  }
}

class _PerizinanScreenState extends State<PerizinanScreen>
    with _GuideLinks<PerizinanScreen> {
  @override
  GuideLauncher get launcher => widget.launcher;
  bool _detailOpen = false;

  Future<void> _showTopic(PerizinanTopic topic) async {
    if (_detailOpen || _opening) return;
    _detailOpen = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PerizinanDetailScreen(topic: topic, launcher: launcher),
        ),
      );
    } finally {
      _detailOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => _GuideScaffold(
    alignment: Alignment.topCenter,
    children: [
      Text(
        'Pilih panduan yang dibutuhkan',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      for (final topic in perizinanTopics)
        Card(
          margin: const EdgeInsets.only(top: 16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('guide-topic-${topic.id}'),
            onTap: () => _showTopic(topic),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(switch (topic.id) {
                    'kusuka' => Icons.badge_outlined,
                    'kapal' => Icons.sailing_outlined,
                    _ => Icons.shield_outlined,
                  }, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(switch (topic.id) {
                          'kusuka' => 'KUSUKA',
                          'kapal' => 'SIPI/SIKPI',
                          _ => 'Perlindungan Nelayan',
                        }, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(switch (topic.id) {
                          'kusuka' => 'Panduan identitas pelaku usaha.',
                          'kapal' => 'Panduan perizinan kapal.',
                          _ => 'Informasi asuransi/jaminan sosial.',
                        }),
                        const SizedBox(height: 12),
                        const Text('Baca panduan'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 20),
      action(diskanlaAssistance, 'guide-help', label: 'Bantuan Diskanla'),
      const SizedBox(height: 16),
      const Text(
        'Pengajuan dan keputusan diproses melalui layanan terkait. SAMUDERA tidak menerbitkan izin atau polis.',
      ),
    ],
  );
}

class PerizinanDetailScreen extends StatefulWidget {
  const PerizinanDetailScreen({
    super.key,
    required this.topic,
    this.launcher = _openBrowser,
  });
  final PerizinanTopic topic;
  final GuideLauncher launcher;
  @override
  State<PerizinanDetailScreen> createState() => _PerizinanDetailScreenState();
}

class _PerizinanDetailScreenState extends State<PerizinanDetailScreen>
    with _GuideLinks<PerizinanDetailScreen> {
  @override
  GuideLauncher get launcher => widget.launcher;

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final primary = topic.sources.firstWhere(
      (s) =>
          s.id ==
          switch (topic.id) {
            'kusuka' => 'stelina',
            'kapal' => 'portal',
            _ => 'bpjs',
          },
    );
    return _GuideScaffold(
      children: [
        Text(topic.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(topic.summary),
        const SizedBox(height: 24),
        Text('Langkah akses', style: Theme.of(context).textTheme.titleLarge),
        for (var i = 0; i < topic.steps.length; i++)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${i + 1}. ${topic.steps[i]}'),
            ),
          ),
        const SizedBox(height: 24),
        Text('Perlu diketahui', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(topic.caution),
        const SizedBox(height: 12),
        const Text(
          'SAMUDERA tidak meminta atau menyimpan NIK, KTP, dokumen kapal, password pemerintah, data pembayaran, atau kredensial BPJS. Tautan dibuka di browser eksternal setelah diketuk.',
        ),
        const SizedBox(height: 24),
        action(primary, 'guide-primary-${topic.id}', primary: true),
        const SizedBox(height: 12),
        action(diskanlaAssistance, 'guide-help', label: 'Bantuan Diskanla'),
        const SizedBox(height: 20),
        ExpansionTile(
          key: ValueKey('guide-sources-${topic.id}'),
          title: const Text('Sumber & pembaruan'),
          childrenPadding: const EdgeInsets.all(16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Konten belum ditinjau oleh dinas. Tanggal pemeriksaan sumber bukan persetujuan dinas.',
            ),
            for (final source in [...topic.sources, diskanlaAssistance])
              _source(source, topic.id),
          ],
        ),
      ],
    );
  }
}

class _GuideScaffold extends StatelessWidget {
  const _GuideScaffold({
    required this.children,
    this.alignment = Alignment.center,
  });
  final List<Widget> children;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Perizinan')),
    body: SafeArea(
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}
