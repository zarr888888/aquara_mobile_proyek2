import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'omni_results.dart';
import 'session_boundary.dart';

enum ServiceGroup { primary, secondary, additional, emergency }

enum ServiceCategory {
  cultivation('Budidaya & Analisa Usaha'),
  trade('Pasar & Perdagangan'),
  marine('Nelayan & Kelautan'),
  community('Komunitas & Konsultasi'),
  information('Berita & Informasi Dinas'),
  emergency('Laporan & Kedaruratan');

  const ServiceCategory(this.label);
  final String label;
}

const serviceCategories = <String, ServiceCategory>{
  'perizinan': ServiceCategory.marine,
  'analysis': ServiceCategory.cultivation,
  'fish': ServiceCategory.cultivation,
  'commodities': ServiceCategory.cultivation,
  'market': ServiceCategory.trade,
  'prices': ServiceCategory.trade,
  'orders': ServiceCategory.trade,
  'external-info-cuaca': ServiceCategory.marine,
  'external-info-tpi': ServiceCategory.marine,
  'external-info-kkp': ServiceCategory.marine,
  'forum': ServiceCategory.community,
  'my-forum': ServiceCategory.community,
  'consultation': ServiceCategory.community,
  'photo': ServiceCategory.community,
  'news': ServiceCategory.information,
  'department': ServiceCategory.information,
  'sos': ServiceCategory.emergency,
};

const serviceDescriptions = <String, String>{
  'perizinan': 'Panduan KUSUKA, SIPI/SIKPI, asuransi dan perlindungan nelayan.',
  'analysis':
      'Estimasi usaha berdasarkan input dan asumsi, bukan jaminan keuntungan.',
  'fish': 'Jelajahi katalog ikan dan informasi komoditas.',
  'commodities': 'Lihat seluruh komoditas yang tersedia.',
  'market': 'Cari produk dan bahan baku yang tersedia di pasar.',
  'prices': 'Lihat informasi harga pasar komoditas.',
  'orders':
      'Riwayat pengajuan pre-order grosir, tanpa pembayaran atau reservasi stok.',
  'external-info-cuaca': 'Prakiraan maritim Karangsong dan Eretan.',
  'external-info-tpi':
      'Cari tempat pelelangan ikan dan lihat titik yang terverifikasi.',
  'external-info-kkp': 'Pilihan informasi resmi dari Diskanla dan KKP.',
  'forum': 'Diskusi dan berbagi pengalaman dengan komunitas.',
  'my-forum': 'Temukan posting komunitas milikmu.',
  'consultation': 'Temukan kanal konsultasi yang tersedia.',
  'photo': 'Analisis foto ikan, bukan pengganti diagnosis ahli.',
  'news': 'Baca berita dan wawasan perikanan.',
  'department': 'Informasi dan pengumuman dinas.',
  'sos': 'Buka formulir laporan; tidak mengirim otomatis.',
};

const _serviceAliases = <String, String>{
  'perizinan': 'izin kapal e-kusuka bpjs pendampingan diskanla',
  'analysis': 'analisis kalkulator panen usaha',
  'orders': 'pesanan pre-order preorder grosir tonase',
  'photo': 'dr fisho kamera ai penyakit',
  'sos': 'darurat laporan bahari',
  'department': 'diskanla dinas informasi',
};

Map<ServiceCategory, List<HomeService>> groupedServices(
  Iterable<HomeService> services,
  String query,
) {
  final words = query.trim().toLowerCase().split(RegExp(r'\s+'));
  final seen = <String>{};
  final result = <ServiceCategory, List<HomeService>>{};
  for (final category in ServiceCategory.values) {
    final matches = services.where((s) {
      if (serviceCategories[s.id] != category || seen.contains(s.id)) {
        return false;
      }
      final text =
          '${s.label} ${category.label} ${serviceDescriptions[s.id] ?? ''} ${_serviceAliases[s.id] ?? ''}'
              .toLowerCase();
      if (!words.every(text.contains)) return false;
      seen.add(s.id);
      return true;
    }).toList()..sort((a, b) => a.order.compareTo(b.order));
    if (matches.isNotEmpty) result[category] = matches;
  }
  return result;
}

/// Presentation only: callbacks retain the existing destination/session guards.
class HomeService {
  const HomeService.perizinan({required VoidCallback onTap})
    : this(
        id: 'perizinan',
        label: 'Perizinan',
        asset: 'assets/icons/services/perizinan.png',
        group: ServiceGroup.additional,
        order: 4,
        requiresSession: false,
        onTap: onTap,
      );
  const HomeService({
    required this.id,
    required this.label,
    required this.group,
    required this.order,
    required this.onTap,
    this.asset,
    this.icon = Icons.apps,
    this.badge,
    this.requiresSession = true,
  });
  final String id;
  final String label;
  final ServiceGroup group;
  final int order;
  final String? asset;
  final IconData icon;
  final String? badge;
  final bool requiresSession;
  final VoidCallback onTap;
}

class ServiceGrid extends StatelessWidget {
  const ServiceGrid({super.key, required this.services});
  final List<HomeService> services;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final columns = scale > 1.4
          ? (constraints.maxWidth / (100 * scale)).floor().clamp(1, 2)
          : constraints.maxWidth < 340
          ? 2
          : 4;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (final service in services)
            SizedBox(
              width: width,
              child: ServiceTile(service: service),
            ),
        ],
      );
    },
  );
}

class ServiceTile extends StatelessWidget {
  const ServiceTile({super.key, required this.service});
  final HomeService service;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('service-${service.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: service.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              Container(
                key: ValueKey('service-icon-${service.id}'),
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: service.asset == null
                    ? Icon(service.icon, color: const Color(0xFF009FE3))
                    : Image.asset(
                        service.asset!,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                service.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (service.badge != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3D9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    service.badge!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF304516),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ContentSearchAction extends StatelessWidget {
  const ContentSearchAction({super.key, required this.api});
  final ApiService api;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Cari konten',
    icon: const Icon(Icons.search),
    onPressed: () {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SessionBoundary(
            api: api,
            private: false,
            builder: (_) => ServiceCatalogScreen(api: api, services: const []),
          ),
        ),
      );
    },
  );
}

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key, required this.services, this.api});
  // A login entry must never mount private results, even during a session change.
  const ServiceCatalogScreen.public({super.key, required this.services})
    : api = null;
  final ApiService? api;
  final List<HomeService> services;

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  String _query = '';
  final _results = GlobalKey<OmniResultsState>();

  @override
  Widget build(BuildContext context) {
    final groups = groupedServices(widget.services, _query);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.services.isEmpty ? 'Pencarian konten' : 'Semua Layanan',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('catalog-search'),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  // The IME can finish editing before onChanged's rebuild.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && value == _query) {
                      _results.currentState?.search();
                    }
                  });
                  WidgetsBinding.instance.ensureVisualUpdate();
                },
                decoration: InputDecoration(
                  labelText: widget.services.isEmpty
                      ? 'Cari konten SAMUDERA'
                      : 'Cari layanan SAMUDERA',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 24),
              if (widget.api != null)
                OmniResults(key: _results, api: widget.api!, query: _query)
              else
                const Text(guestContentSearchHint),
              if (widget.services.isNotEmpty && groups.isEmpty)
                const Text('Layanan tidak ditemukan.'),
              for (final entry in groups.entries) ...[
                Text(
                  entry.key.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ServiceGrid(services: entry.value),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
