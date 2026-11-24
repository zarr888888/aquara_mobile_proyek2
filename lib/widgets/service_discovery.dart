import 'package:flutter/material.dart';
import 'home_services.dart';

class ServicePersona {
  const ServicePersona(
    this.id,
    this.title,
    this.intro,
    this.photo,
    this.services,
  );
  final String id, title, intro;
  final String? photo;
  final List<String> services;
}

const servicePersonas = <ServicePersona>[
  ServicePersona(
    'tawar',
    'Pembudidaya Air Tawar',
    'Temukan alat perencanaan usaha, informasi komoditas, dan ruang berdiskusi untuk kegiatan budidayamu.',
    'pembudidaya_tawar',
    ['analysis', 'fish', 'market', 'forum', 'consultation'],
  ),
  ServicePersona(
    'laut',
    'Pembudidaya Tambak & Laut',
    'Jelajahi informasi komoditas dan layanan yang membantu kegiatan tambak maupun budidaya laut.',
    'tambak_laut',
    ['commodities', 'market', 'forum', 'consultation'],
  ),
  ServicePersona(
    'nelayan',
    'Nelayan',
    'Temukan akses informasi kelautan, pasar, komunitas, dan formulir laporan dalam satu tempat. Informasi simulasi bukan panduan keselamatan.',
    'nelayan',
    [
      'external-info-cuaca',
      'external-info-tpi',
      'external-info-kkp',
      'market',
      'sos',
    ],
  ),
  ServicePersona(
    'pengolah',
    'Pengolah Hasil Perikanan',
    'Cari bahan baku dan informasi yang relevan, lalu terhubung dengan komunitas perikanan. Ketersediaan produk mengikuti produk yang tercatat di Pasar.',
    'pengolah',
    ['market', 'news', 'forum', 'consultation'],
  ),
  ServicePersona(
    'pedagang',
    'Pedagang & Pengepul',
    'Jelajahi produk, informasi harga, dan pengajuan pesanan grosir yang tersedia.',
    'pedagang',
    ['market', 'prices', 'orders', 'fish'],
  ),
];

class DiscoveryPhoto extends StatelessWidget {
  const DiscoveryPhoto({
    super.key,
    required this.photo,
    this.height = 200,
    this.round = false,
  });
  final String? photo;
  final double height;
  final bool round;
  @override
  Widget build(BuildContext context) {
    final child = photo == null
        ? SizedBox(
            height: height,
            width: round ? height : double.infinity,
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined),
            ),
          )
        : Image.asset(
            'assets/images/discovery/$photo.jpg',
            height: height,
            width: round ? height : double.infinity,
            cacheWidth: round ? 240 : 1200,
            fit: round ? BoxFit.cover : BoxFit.contain,
            alignment: photo == 'pembudidaya_tawar'
                ? const Alignment(-.45, 0)
                : Alignment.center,
            semanticLabel: 'Foto ilustrasi',
          );
    return round ? ClipOval(child: child) : child;
  }
}

class PersonaChoices extends StatelessWidget {
  const PersonaChoices({super.key, required this.onSelected});
  final ValueChanged<ServicePersona> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final persona in servicePersonas)
          SizedBox(
            width: 144,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('persona-${persona.id}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(persona),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        DiscoveryPhoto(
                          photo: persona.photo,
                          height: 80,
                          round: true,
                        ),
                        const SizedBox(height: 8),
                        Text(persona.title, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class PersonaDetailScreen extends StatelessWidget {
  const PersonaDetailScreen({
    super.key,
    required this.persona,
    required this.services,
  });
  final ServicePersona persona;
  final List<HomeService> services;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SAMUDERA')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spesial untuk kamu'),
            Text(
              persona.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            DiscoveryPhoto(photo: persona.photo),
            Text(
              persona.photo == null
                  ? 'Foto ilustrasi menunggu verifikasi sumber.'
                  : persona.id == 'pengolah'
                  ? 'Foto ilustrasi pengolahan ikan di Vietnam — bukan dokumentasi Indramayu atau dinas.'
                  : 'Foto ilustrasi — bukan dokumentasi dinas.',
            ),
            const SizedBox(height: 16),
            Text(persona.intro),
            const SizedBox(height: 16),
            const Text(
              'Pilihan ini tidak mengubah peran akun atau membatasi layanan lainnya.',
            ),
            const SizedBox(height: 24),
            Text(
              'Layanan untukmu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final id in persona.services)
              for (final service in services.where((s) => s.id == id))
                Card(
                  child: InkWell(
                    onTap: service.onTap,
                    key: ValueKey('persona-service-$id'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (service.asset != null)
                            Image.asset(
                              service.asset!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          Text(
                            service.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(serviceDescriptions[id]!),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}

class AppGuide {
  const AppGuide(this.id, this.title, this.photo, this.paragraphs);
  final String id, title, photo;
  final List<String> paragraphs;
}

const appGuides = <AppGuide>[
  AppGuide('budidaya', 'Kenali Layanan Budidaya di SAMUDERA', 'pembudidaya_tawar', [
    'SAMUDERA menyediakan beberapa pintasan untuk membantu pengguna menemukan informasi komoditas, membuat estimasi usaha, dan berdiskusi dengan komunitas. Mulailah dari katalog untuk melihat komoditas yang tersedia, lalu pilih layanan sesuai kebutuhanmu.',
    'Pada Analisa Usaha, masukkan data sesuai petunjuk form dan periksa kembali nilainya. Hasil perhitungan merupakan estimasi yang bergantung pada input dan asumsi yang ditampilkan. Gunakan bersama pertimbangan kondisi usaha serta konsultasi yang sesuai; hasilnya tidak menjamin keuntungan.',
    'Forum dapat digunakan untuk berbagi pertanyaan dan pengalaman. Gunakan komentar dan balasan agar pembahasan tetap mudah diikuti.',
  ]),
  AppGuide('nelayan', 'Temukan Layanan untuk Nelayan', 'nelayan', [
    'Melalui kelompok Nelayan, pengguna dapat menemukan pintasan menuju informasi kelautan, pasar, komunitas, dan formulir SOS Bahari yang tersedia di SAMUDERA.',
    'Info KKP memuat pilihan sumber pemerintah. Daftar TPI tetap mencantumkan fasilitas yang belum memiliki titik terverifikasi; hanya titik bersumber yang ditampilkan pada peta.',
    'SOS Bahari membuka formulir laporan. Laporan baru dikirim setelah pengguna melengkapi isian dan memilih Kirim. Fitur ini tidak menjanjikan pemantauan 24 jam atau waktu respons darurat tertentu.',
  ]),
  AppGuide('pasar', 'Jelajahi Pasar dan Pengajuan Grosir', 'pedagang', [
    'Pasar membantu pengguna melihat produk yang tersedia dan informasi yang diberikan penjual. Pilih produk untuk membaca keterangannya dan gunakan tindakan yang tersedia pada aplikasi.',
    'Pada produk grosir yang mendukung pre-order, pengguna dapat mengajukan jumlah tonase dan tanggal pengambilan sesuai petunjuk form. Pengajuan yang tercatat dapat diperiksa melalui riwayat dan detail pesanan.',
    'Pengajuan tersebut memerlukan konfirmasi dan tindak lanjut dengan penjual. Fitur pre-order tidak memproses pembayaran dan tidak menjamin stok sudah dicadangkan.',
  ]),
];

class AppGuideScreen extends StatelessWidget {
  const AppGuideScreen({super.key, required this.guide});
  final AppGuide guide;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Panduan Aplikasi')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Panduan Aplikasi • Tim SAMUDERA'),
            const SizedBox(height: 12),
            Text(guide.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            DiscoveryPhoto(photo: guide.photo),
            const Text('Foto ilustrasi — bukan dokumentasi dinas.'),
            for (final paragraph in guide.paragraphs)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(paragraph),
              ),
            const SizedBox(height: 24),
            const Text(
              'Sumber: Tim SAMUDERA. Bukan panduan keselamatan atau diagnosis penyakit.',
            ),
          ],
        ),
      ),
    ),
  );
}

class GuideBanner extends StatelessWidget {
  const GuideBanner({super.key, required this.guide, required this.onTap});
  final AppGuide guide;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('guide-${guide.id}'),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: DiscoveryPhoto(photo: guide.photo, height: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  guide.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Panduan Aplikasi • Baca panduan'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
