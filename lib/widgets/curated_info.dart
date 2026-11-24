import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/external_info.dart';
import 'samudera_theme.dart';
import 'tpi_map.dart';

class SourceButton extends StatelessWidget {
  const SourceButton(this.url, {super.key});
  final Uri url;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.open_in_new),
    label: const Text('Buka sumber'),
    onPressed: () async {
      try {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sumber tidak dapat dibuka.')),
        );
      }
    },
  );
}

class CuratedInfo extends StatefulWidget {
  const CuratedInfo({
    super.key,
    required this.kind,
    required this.data,
    required this.busy,
    required this.failure,
    required this.wait,
    required this.reload,
    this.tileProvider,
  });
  final ExternalInfoKind kind;
  final ExternalInfo? data;
  final bool busy, failure;
  final String? wait;
  final VoidCallback? reload;
  final TileProvider? tileProvider;
  @override
  State<CuratedInfo> createState() => _CuratedInfoState();
}

class _CuratedInfoState extends State<CuratedInfo> {
  String query = '';
  bool map = false;
  void _detail(String id) {
    final row = widget.data?.items
        .whereType<TpiInfoItem>()
        .where((e) => e.id == id)
        .firstOrNull;
    if (row == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          key: ValueKey('detail-$id'),
          appBar: AppBar(title: const Text('Detail TPI')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(row.name, style: Theme.of(context).textTheme.titleLarge),
                Text(row.address),
                if (row.coordinateSource case final url?) ...[
                  Text('Koordinat: ${row.latitude}, ${row.longitude}'),
                  SourceButton(url),
                ] else
                  const Text('Titik TPI belum terverifikasi'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tpi = widget.kind == ExternalInfoKind.tpi;
    final rows =
        widget.data?.items
            .whereType<TpiInfoItem>()
            .where(
              (e) => '${e.name} ${e.village} ${e.district}'
                  .toLowerCase()
                  .contains(query.trim().toLowerCase()),
            )
            .toList() ??
        <TpiInfoItem>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.label),
        backgroundColor: SamuderaColors.blue,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (widget.busy)
                  const Center(child: CircularProgressIndicator()),
                if (widget.failure)
                  Text(
                    widget.data == null
                        ? 'Informasi resmi belum dapat dimuat.'
                        : 'DATA LAMA — penyegaran gagal.',
                  ),
                if (widget.wait != null) Text(widget.wait!),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('external-info-refresh'),
                    onPressed: widget.reload,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      widget.data == null ? 'Coba kembali' : 'Muat ulang',
                    ),
                  ),
                ),
                if (tpi) ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Cari nama, desa, atau kecamatan',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (s) => setState(() => query = s),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final mode in [false, true])
                        ChoiceChip(
                          avatar: Icon(mode ? Icons.map : Icons.list),
                          label: Text(mode ? 'Peta' : 'Daftar'),
                          selected: map == mode,
                          onSelected: (_) {
                            FocusScope.of(context).unfocus();
                            setState(() => map = mode);
                          },
                        ),
                    ],
                  ),
                  if (map)
                    SizedBox(
                      height:
                          MediaQuery.sizeOf(context).height.clamp(420, 720) *
                          .78,
                      child: TpiMap(
                        rows: rows,
                        open: _detail,
                        tileProvider: widget.tileProvider,
                      ),
                    )
                  else ...[
                    if (rows.isEmpty && widget.data != null)
                      const Text('Tidak ada TPI yang cocok.'),
                    for (final r in rows)
                      Card(
                        child: ListTile(
                          title: Text(r.name),
                          subtitle: Text(r.address),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _detail(r.id),
                        ),
                      ),
                  ],
                ] else ...[
                  if (widget.data != null && widget.data!.items.isEmpty)
                    const Text('Belum ada informasi resmi.'),
                  for (final r
                      in widget.data?.items.whereType<KkpInfoItem>() ??
                          <KkpInfoItem>[])
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(r.summary),
                            Text(r.publisher),
                            if (r.publishedAt case final date?)
                              Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(date),
                              ),
                            SourceButton(r.sourceUrl),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
