import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class IconCredit {
  const IconCredit(this.label, this.author, this.asset, this.url);
  final String label, author, asset, url;
  String get licenseUrl => url.contains('pexels.com')
      ? 'https://www.pexels.com/license/'
      : 'https://www.flaticon.com/legal';
}

const iconCredits = <IconCredit>[
  IconCredit(
    'Analisa Usaha',
    'AB Design',
    'assets/icons/services/analisa_usaha.png',
    'https://www.flaticon.com/free-icon/computer-graphic_2962235',
  ),
  IconCredit(
    'Pasar Ikan',
    'Magnific',
    'assets/icons/services/pasar.png',
    'https://www.flaticon.com/free-icon/fish-market_6044130',
  ),
  IconCredit(
    'Katalog Ikan',
    'smalllikeart',
    'assets/icons/services/katalog_ikan.png',
    'https://www.flaticon.com/free-icon/fish_3111276',
  ),
  IconCredit(
    'Forum Komunitas',
    'Smashicons',
    'assets/icons/services/forum.png',
    'https://www.flaticon.com/free-icon/forum_943706',
  ),
  IconCredit(
    'Info KKP (sebelumnya juga Berita / Info Dinas)',
    'AB Design',
    'assets/icons/services/informasi.png',
    'https://www.flaticon.com/free-icon/report_2962344',
  ),
  IconCredit(
    'Cuaca',
    'Smashicons',
    'assets/icons/services/cuaca.png',
    'https://www.flaticon.com/free-icon/cloudy_774659',
  ),
  IconCredit(
    'Daftar TPI',
    'Smashicons',
    'assets/icons/services/tpi.png',
    'https://www.flaticon.com/free-icon/fishing-boat_1979713',
  ),
  IconCredit(
    'Pesanan Grosir',
    'AB Design',
    'assets/icons/services/pesanan.png',
    'https://www.flaticon.com/free-icon/clipboard_2962247',
  ),
  IconCredit(
    'Analisis Foto',
    'Smashicons',
    'assets/icons/services/analisis_foto.png',
    'https://www.flaticon.com/free-icon/camera_6256546',
  ),
  IconCredit(
    'SOS Bahari',
    'smalllikeart',
    'assets/icons/services/sos.png',
    'https://www.flaticon.com/free-icon/lifebuoy_3111351',
  ),
];

const additionalIconCredits = <IconCredit>[
  IconCredit(
    'Perizinan — Certificate (Special Flat, Harbour)',
    'Magnific',
    'assets/icons/services/perizinan.png',
    'https://www.flaticon.com/free-icon/certificate_9095982',
  ),
  IconCredit(
    'Forum Saya — Online Chat (mikan933 Flat)',
    'mikan933',
    'assets/icons/services/forum_saya.png',
    'https://www.flaticon.com/free-icon/online-chat_2854894',
  ),
  IconCredit(
    'Semua Komoditas — Fish (Basic Rounded Flat)',
    'Magnific',
    'assets/icons/services/semua_komoditas.png',
    'https://www.flaticon.com/free-icon/fish_752851',
  ),
  IconCredit(
    'Berita',
    'Smashicons',
    'assets/icons/services/berita.png',
    'https://www.flaticon.com/free-icon/newspaper_660628',
  ),
  IconCredit(
    'Harga Pasar',
    'Smashicons',
    'assets/icons/services/harga_pasar.png',
    'https://www.flaticon.com/free-icon/price-tag_4116340',
  ),
  IconCredit(
    'Konsultasi',
    'Assia Benkerroum',
    'assets/icons/services/konsultasi.png',
    'https://www.flaticon.com/free-icon/consultation_8469077',
  ),
];

const discoveryPhotoCredits = <IconCredit>[
  IconCredit(
    'Pengolah — Woman Working in Fishing Industry (Vietnam)',
    'Quang Nguyen Vinh',
    'assets/images/discovery/pengolah.jpg',
    'https://www.pexels.com/photo/woman-working-in-fishing-industry-11669737/',
  ),
  IconCredit(
    'Pembudidaya Air Tawar',
    'HONG SON',
    'assets/images/discovery/pembudidaya_tawar.jpg',
    'https://www.pexels.com/photo/fisherman-feeding-fish-on-a-floating-fish-farm-37052316/',
  ),
  IconCredit(
    'Tambak & Laut',
    'Tom Fisk',
    'assets/images/discovery/tambak_laut.jpg',
    'https://www.pexels.com/photo/artificial-ponds-with-fish-on-farm-in-daytime-5774415/',
  ),
  IconCredit(
    'Nelayan',
    'setengah lima sore',
    'assets/images/discovery/nelayan.jpg',
    'https://www.pexels.com/photo/fishermen-working-on-traditional-fishing-boat-30733108/',
  ),
  IconCredit(
    'Pedagang & Pengepul',
    'Mitchell Soeharsono',
    'assets/images/discovery/pedagang.jpg',
    'https://www.pexels.com/photo/fresh-fish-market-display-in-surabaya-36618308/',
  ),
];

class IconCreditsScreen extends StatefulWidget {
  const IconCreditsScreen({super.key});
  @override
  State<IconCreditsScreen> createState() => _IconCreditsScreenState();
}

class _IconCreditsScreenState extends State<IconCreditsScreen> {
  bool _opening = false;
  Future<void> _open(String source) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!await launchUrl(
        Uri.parse(source),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Unable to open source');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tautan sumber belum dapat dibuka.')),
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kredit ilustrasi')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ilustrasi layanan SAMUDERA berasal dari Flaticon. Kredit pembuat dan sumber setiap aset tercantum di bawah. Aset bukan karya tim SAMUDERA dan bukan berlisensi MIT.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Logo Info Dinas: aset milik pengguna. Foto Pexels dipakai sebagai ilustrasi, bukan dokumentasi dinas atau dukungan orang yang terlihat. Sumber mengikuti manifest pengguna; bukti unduhan masih perlu dilengkapi.',
          ),
          const Text(
            'Forum Saya dan Semua Komoditas memakai ikon berbeda. Foto Pengolah adalah ilustrasi kegiatan di Vietnam, bukan Indramayu. Catatan sumber dan tautan ketentuan bukan dokumen lisensi unduhan; dokumen unduhan belum tersedia untuk dibandingkan.',
          ),
          for (final credit in [
            ...iconCredits,
            ...additionalIconCredits,
            ...discoveryPhotoCredits,
          ])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      credit.asset,
                      width: 48,
                      height: 48,
                      excludeFromSemantics: true,
                    ),
                    Text(
                      credit.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Dibuat oleh ${credit.author} • ${credit.url.contains('pexels.com') ? 'Pexels' : 'Flaticon'}',
                    ),
                    TextButton(
                      onPressed: () => _open(credit.url),
                      child: const Text('Buka sumber aset'),
                    ),
                    TextButton(
                      onPressed: () => _open(credit.licenseUrl),
                      child: const Text('Rujukan lisensi / ketentuan'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
