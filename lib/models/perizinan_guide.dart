/// Editorial snapshot, not live eligibility or application data.
class GuideSource {
  const GuideSource(
    this.id,
    this.name,
    this.url,
    this.action, {
    this.published,
  });
  final String id, name, url, action;
  final String? published;
  String get checked => '27 Oktober 2026';
}

class PerizinanTopic {
  const PerizinanTopic(
    this.id,
    this.title,
    this.summary,
    this.steps,
    this.caution,
    this.sources,
  );
  final String id, title, summary, caution;
  final List<String> steps;
  final List<GuideSource> sources;
}

const diskanlaAssistance = GuideSource(
  'diskanla',
  'Diskanla Kabupaten Indramayu',
  'https://diskanla.indramayukab.go.id/sample-page/kontak-kami/',
  'Buka kontak pendampingan Diskanla',
);

const perizinanTopics = <PerizinanTopic>[
  PerizinanTopic(
    'kusuka',
    'KUSUKA',
    'KUSUKA merupakan identitas pelaku usaha dan pelaku pendukung sektor kelautan dan perikanan. KUSUKA bukan SIPI/SIKPI dan bukan bukti kepesertaan asuransi.',
    [
      'Baca pengertian KUSUKA pada glosarium JDIH KKP dan penjelasan akses pada FAQ STELINA.',
      'FAQ STELINA menunjuk tautan KUSUKA di footer. Saat diperiksa, tautan tersebut membuka dashboard informasi, bukan formulir pendaftaran yang dapat dipastikan.',
      'Untuk memastikan jalur pendaftaran yang sesuai, buka kontak Diskanla dan minta arahan petugas atau penyuluh. Jangan mengirim dokumen melalui SAMUDERA.',
    ],
    'Jalur pendaftaran langsung belum terverifikasi. Panduan registrasi STELINA tidak boleh dianggap sebagai persyaratan registrasi KUSUKA.',
    [
      GuideSource(
        'jdih',
        'JDIH KKP — Glosarium KUSUKA',
        'https://jdih.kkp.go.id/Homedev/KamusHukum/2200',
        'Baca pengertian KUSUKA',
      ),
      GuideSource(
        'stelina',
        'KKP — FAQ STELINA',
        'https://stelina.kkp.go.id/public/faq',
        'Baca panduan akses KUSUKA',
      ),
    ],
  ),
  PerizinanTopic(
    'kapal',
    'Perizinan kapal — SIPI/SIKPI',
    'SIPI/SIKPI berkaitan dengan perizinan kegiatan penangkapan dan pengangkutan ikan. Layanan ini berbeda dari identitas KUSUKA.',
    [
      'Mulai dari portal perizinan KKP untuk melihat layanan dan informasi perizinan penangkapan serta pengangkutan ikan.',
      'Buka FAQ, lalu cari panduan SIPI/SIKPI pada bagian SILAT atau SIMKADA. Tersedia topik permohonan baru, perpanjangan, dan panduan OSS terkait.',
      'Minta pendampingan Diskanla untuk memastikan jalur, kewenangan, dan persyaratan sesuai kegiatan serta kondisi kapal sebelum mengajukan melalui layanan resmi.',
    ],
    'Panduan ini tidak menentukan kewenangan hanya dari ukuran kapal. Ketentuan dan panduan dapat berubah; konfirmasikan kepada petugas. Tidak ada jaminan persetujuan atau lama proses.',
    [
      GuideSource(
        'portal',
        'KKP — Portal Perizinan',
        'https://perizinan.kkp.go.id/',
        'Buka portal perizinan KKP',
      ),
      GuideSource(
        'faq',
        'KKP — FAQ Perizinan',
        'https://perizinan.kkp.go.id/faq.php',
        'Baca panduan SIPI/SIKPI',
      ),
    ],
  ),
  PerizinanTopic(
    'perlindungan',
    'Asuransi dan perlindungan nelayan',
    'Perlindungan membantu menghadapi risiko kerja. BPJS Ketenagakerjaan menyediakan informasi program Bukan Penerima Upah (BPU), tetapi kategori kepesertaan setiap nelayan perlu dipastikan sesuai kondisi pekerjaannya.',
    [
      'Baca informasi BPU pada situs BPJS Ketenagakerjaan untuk mengenali program dan petunjuk kepesertaan resmi.',
      'Konfirmasikan kategori, program yang sesuai, ketentuan dan prosedur kepada BPJS Ketenagakerjaan; gunakan pendampingan Diskanla bila membutuhkan arahan.',
      'Berita Diskanla mencatat sosialisasi dan verifikasi data BPJS nelayan di Sukahaji, Patrol. Tanyakan langsung kepada dinas mengenai ketersediaan program pendampingan saat ini.',
    ],
    'Berita kegiatan bukan pengumuman bantuan sedang dibuka. Tidak semua nelayan otomatis masuk kategori BPU atau memenuhi syarat bantuan. SAMUDERA tidak menjamin subsidi, manfaat pertanggungan, atau kepesertaan.',
    [
      GuideSource(
        'bpjs',
        'BPJS Ketenagakerjaan — BPU',
        'https://www.bpjsketenagakerjaan.go.id/bukan-penerima-upah.html',
        'Baca informasi perlindungan BPU',
      ),
      GuideSource(
        'berita-asuransi',
        'Diskanla — Sosialisasi Asuransi BPJS ke Nelayan',
        'https://diskanla.indramayukab.go.id/sosialisasi-asuransi-nelayan/',
        'Baca berita sosialisasi (bukan pendaftaran)',
        published: '10 Februari 2026',
      ),
    ],
  ),
];

/// Exact catalog URLs only: no dynamic path, query, fragment or credentials.
bool isApprovedGuideUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.hasPort) {
    return false;
  }
  return [
    diskanlaAssistance,
    ...perizinanTopics.expand((t) => t.sources),
  ].any((source) => source.url == value);
}
