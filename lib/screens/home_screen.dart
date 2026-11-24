import '../widgets/commodity_card.dart';
import '../widgets/reference_list_builder.dart';
import '../widgets/samudera_branding.dart';
import '../services/api_result.dart';
import '../widgets/session_boundary.dart';
import '../services/session_service.dart';
import '../models/reference_data.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'analysis_screen.dart';
import 'catalog_screen.dart';
import 'market_price_screen.dart';
import 'info_dinas_screen.dart';
import 'forum_screen.dart';
import 'consultation_screen.dart';
import 'ai_fisho_screen.dart';
import 'pre_order_screen.dart';
import 'icon_credits_screen.dart';
import 'perizinan_screen.dart';
import '../widgets/home_services.dart';
import '../widgets/service_discovery.dart';
import '../widgets/home_news_preview.dart';
import '../widgets/support_banners.dart';
import 'berita_screen.dart';
import 'pasar_screen.dart';
import 'login_screen.dart';
import 'profil_screen.dart';
import 'semua_komoditas_screen.dart';
import 'notifikasi_screen.dart';
import 'sos_screen.dart';
import 'external_info_screen.dart';
import 'asisten_samudera_screen.dart';
import '../widgets/gombyang.dart';
import '../models/external_info.dart';
import 'package:image_picker/image_picker.dart';
import '../services/sos_api.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.api, this.pickSosPhoto});
  final ApiService? api;
  final Future<XFile?> Function(ImageSource)? pickSosPhoto;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: false,
    builder: (_) => _HomeScreenContent(api: api, pickSosPhoto: pickSosPhoto),
  );
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent({this.api, this.pickSosPhoto});
  final ApiService? api;
  final Future<XFile?> Function(ImageSource)? pickSosPhoto;

  @override
  State<_HomeScreenContent> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreenContent>
    with SessionOwnedState<_HomeScreenContent> {
  late final ApiService _apiService = widget.api ?? ApiService();
  @override
  get stateSession => _apiService.session;
  Future<ApiResult<List<dynamic>>> _loadReference(
    Future<ApiResult<List<dynamic>>> Function({
      required SessionSnapshot expectedSession,
    })
    fetch,
  ) async {
    try {
      final owner = await _apiService.session.snapshot();
      if (!sessionActive || owner.revision != _apiService.session.revision) {
        return ApiResult.failure(
          ApiFailure(kind: ApiErrorKind.staleSession, message: 'Sesi berubah.'),
        );
      }
      return fetch(expectedSession: owner);
    } catch (_) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.session,
          message: 'Data tidak dapat dimuat. Silakan coba kembali.',
        ),
      );
    }
  }

  late Future<ApiResult<List<dynamic>>> _fishList;

  int _selectedIndex = 0;
  bool _supportPaused = false;
  bool _isLoggedIn = false;
  String _userName = "";
  String _fotoProfil = "";

  final PageController _bannerController = PageController(
    viewportFraction: 0.92,
  );

  int _currentBannerIndex = 0;

  StreamSubscription<int>? _metadataSubscription;
  bool _discoveryOpen = false;
  bool _routeOpen = false;
  bool _catalogOpen = false;
  final _searchFocus = FocusNode();
  bool _sosOpen = false;
  bool _externalInfoOpen = false;

  Future<void> _openExternalInfo(ExternalInfoKind kind) async {
    if (!sessionActive || _externalInfoOpen || _routeOpen || _sosOpen) return;
    _externalInfoOpen = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ExternalInfoScreen(kind: kind, api: _apiService),
        ),
      );
    } finally {
      if (mounted) _externalInfoOpen = false;
    }
  }

  Future<void> _openSos() async {
    if (!sessionActive || _sosOpen || _routeOpen || _externalInfoOpen) return;
    _sosOpen = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => SosScreen(api: _apiService)),
      );
    } finally {
      if (sessionActive) _sosOpen = false;
    }
  }

  Future<void> _openSosCamera() async {
    if (!sessionActive ||
        _sosOpen ||
        _routeOpen ||
        _externalInfoOpen ||
        _catalogOpen) {
      return;
    }
    _sosOpen = true;
    try {
      final owner = await stateSession.snapshot();
      if (!mounted ||
          !sessionActive ||
          owner.revision != stateSession.revision) {
        return;
      }
      if (!owner.isAuthenticated) {
        SessionNavigation.leave(context);
        return;
      }
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Foto SOS — belum mengirim laporan'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Ambil Foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (!sessionActive || !stateSession.owns(owner) || source == null) return;
      final file =
          await (widget.pickSosPhoto?.call(source) ??
              ImagePicker().pickImage(source: source));
      if (!sessionActive || !stateSession.owns(owner) || file == null) return;
      final photo = await SosPhoto.read(file);
      if (!mounted || !sessionActive || !stateSession.owns(owner)) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SosScreen(
            api: _apiService,
            initialPhoto: photo,
            photoOwner: owner,
            pickPhoto: widget.pickSosPhoto,
          ),
        ),
      );
    } catch (_) {
      if (mounted && sessionActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Foto tidak dapat dipilih. Periksa izin kamera/galeri dan gunakan JPEG/PNG maksimal 2048 KB.',
            ),
          ),
        );
      }
    } finally {
      if (sessionActive) _sosOpen = false;
    }
  }

  Future<void> _openDiscovery(Widget page) async {
    if (!sessionActive ||
        _discoveryOpen ||
        _routeOpen ||
        _catalogOpen ||
        _sosOpen ||
        _externalInfoOpen) {
      return;
    }
    _discoveryOpen = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );
    } finally {
      if (mounted) _discoveryOpen = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fishList = _loadReference(_apiService.fetchFishTypes);
    _checkLoginStatus();
    _metadataSubscription = _apiService.session.changes.listen((_) {
      if (sessionActive) _checkLoginStatus();
    });
  }

  @override
  void dispose() {
    _metadataSubscription?.cancel();
    _bannerController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted || !sessionActive) return;
    final metadata = _apiService.session.metadata;
    setState(() {
      _isLoggedIn = _apiService.session.hasSession;
      _userName = metadata['user_name'] ?? "Pembudidaya";
      _fotoProfil = metadata['foto_profil'] ?? "";
    });
  }

  String formatRupiah(dynamic price) {
    try {
      double priceDouble = double.parse(price.toString());
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(priceDouble);
    } catch (e) {
      return "Rp -";
    }
  }

  Future<void> _openPage(Widget page) async {
    if (!sessionActive || _routeOpen || _sosOpen || _externalInfoOpen) return;
    _routeOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );
    } finally {
      if (mounted) _routeOpen = false;
    }
  }

  List<HomeService> get _services {
    HomeService item(
      String id,
      String label,
      String asset,
      ServiceGroup group,
      int order,
      Widget page, {
      bool private = true,
    }) => HomeService(
      id: id,
      label: label,
      asset: 'assets/icons/services/$asset.png',
      group: group,
      order: order,
      requiresSession: private,
      onTap: () => _openPage(page),
    );
    return [
      HomeService.perizinan(onTap: () => _openPage(const PerizinanScreen())),
      item(
        'analysis',
        'Analisa Usaha',
        'analisa_usaha',
        ServiceGroup.primary,
        0,
        AnalysisScreen(api: _apiService),
      ),
      item(
        'market',
        'Pasar Ikan',
        'pasar',
        ServiceGroup.primary,
        1,
        PasarScreen(api: _apiService),
      ),
      item(
        'fish',
        'Katalog Ikan',
        'katalog_ikan',
        ServiceGroup.primary,
        2,
        CatalogScreen(api: _apiService),
      ),
      item(
        'forum',
        'Forum Komunitas',
        'forum',
        ServiceGroup.primary,
        3,
        ForumScreen(api: _apiService),
      ),
      for (final kind in ExternalInfoKind.values)
        HomeService(
          id: 'external-info-${kind.name}',
          label: kind == ExternalInfoKind.cuaca ? 'Cuaca' : kind.label,
          asset:
              'assets/icons/services/${switch (kind) {
                ExternalInfoKind.kkp => 'informasi',
                ExternalInfoKind.cuaca => 'cuaca',
                ExternalInfoKind.tpi => 'tpi',
              }}.png',
          group: ServiceGroup.secondary,
          order: kind.index,
          badge: null,
          requiresSession: false,
          onTap: () {
            if (!_routeOpen) _openExternalInfo(kind);
          },
        ),
      item(
        'orders',
        'Pesanan Grosir',
        'pesanan',
        ServiceGroup.secondary,
        3,
        PreOrderScreen(api: _apiService, view: PreOrderView.history),
      ),
      item(
        'photo',
        'Analisis Foto',
        'analisis_foto',
        ServiceGroup.secondary,
        4,
        AiFishoScreen(api: _apiService),
      ),
      item(
        'my-forum',
        'Forum Saya',
        'forum_saya',
        ServiceGroup.secondary,
        5,
        ForumScreen(api: _apiService, mine: true),
      ),
      item(
        'news',
        'Berita',
        'berita',
        ServiceGroup.secondary,
        6,
        BeritaScreen(api: _apiService),
      ),
      item(
        'department',
        'Info Dinas',
        'info_dinas',
        ServiceGroup.additional,
        0,
        InfoDinasScreen(api: _apiService),
      ),
      item(
        'prices',
        'Harga Pasar',
        'harga_pasar',
        ServiceGroup.additional,
        1,
        MarketPriceScreen(api: _apiService),
      ),
      item(
        'consultation',
        'Konsultasi',
        'konsultasi',
        ServiceGroup.additional,
        2,
        const ConsultationScreen(),
        private: false,
      ),
      item(
        'commodities',
        'Semua Komoditas',
        'semua_komoditas',
        ServiceGroup.additional,
        3,
        SemuaKomoditasScreen(api: _apiService),
      ),
      HomeService(
        id: 'sos',
        label: 'SOS Bahari',
        asset: 'assets/icons/services/sos.png',
        group: ServiceGroup.emergency,
        order: 0,
        onTap: () {
          if (!_routeOpen) _openSos();
        },
      ),
    ];
  }

  Future<void> _openCatalog() async {
    if (!sessionActive ||
        _catalogOpen ||
        _routeOpen ||
        _sosOpen ||
        _externalInfoOpen) {
      return;
    }
    _catalogOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SessionBoundary(
            api: _apiService,
            private: false,
            builder: (_) =>
                ServiceCatalogScreen(services: _services, api: _apiService),
          ),
        ),
      );
    } finally {
      if (mounted) _catalogOpen = false;
    }
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildBeranda() {
    _userName = _apiService.session.metadata['user_name'] ?? 'Pembudidaya';
    _fotoProfil =
        referenceImage({
          'image': _apiService.session.metadata['foto_profil'],
        }) ??
        '';
    final services = _services;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const Key('home-scroll'),
        padding: const EdgeInsets.only(bottom: 88),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: const Key('home-photo-header'),
              constraints: BoxConstraints(
                minHeight: (MediaQuery.sizeOf(context).width * .75).clamp(
                  240,
                  320,
                ),
              ),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/home/samudera_hero.jpg'),
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.asset(
                                    samuderaLogoAsset,
                                    width: 94,
                                    height: 94,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Logo SAMUDERA',
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SAMUDERA',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                        ),
                                        Text(
                                          _isLoggedIn
                                              ? 'Hallo, $_userName '
                                              : 'Selamat datang',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Text(
                                          'Kabupaten Indramayu',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    color: Colors.white,
                                    tooltip: _isLoggedIn
                                        ? 'Notifikasi'
                                        : 'Login',
                                    onPressed: () => _openPage(
                                      _isLoggedIn
                                          ? NotifikasiScreen(api: _apiService)
                                          : const LoginScreen(),
                                    ),
                                    icon: Icon(
                                      _isLoggedIn
                                          ? Icons.notifications_outlined
                                          : Icons.login,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isLoggedIn)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    color: Colors.white,
                                    tooltip: 'Profil saya',
                                    onPressed: () =>
                                        setState(() => _selectedIndex = 3),
                                    icon: _fotoProfil.isEmpty
                                        ? const Icon(Icons.person_outline)
                                        : ClipOval(
                                            child: Image.network(
                                              _fotoProfil,
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, error, stack) =>
                                                  const Icon(
                                                    Icons.person_outline,
                                                  ),
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Material(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          key: const Key('home-search'),
                          focusNode: _searchFocus,
                          readOnly: true,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          onTap: _openCatalog,
                          decoration: const InputDecoration(
                            labelText: 'Cari layanan SAMUDERA',
                            labelStyle: TextStyle(color: Colors.white),
                            hintStyle: TextStyle(color: Colors.white),
                            prefixIcon: Icon(Icons.search, color: Colors.white),
                            filled: false,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heading('Layanan utama'),
                  ServiceGrid(
                    services: services
                        .where((s) => s.group == ServiceGroup.primary)
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    children: [
                      Text(
                        'Layanan untukmu',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: _openCatalog,
                        child: const Text('Lihat semua'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ServiceGrid(
                    services: [
                      ...services.where(
                        (s) => s.group == ServiceGroup.secondary,
                      ),
                      HomeService(
                        id: 'all',
                        label: 'Semua Layanan',
                        group: ServiceGroup.secondary,
                        order: 7,
                        requiresSession: false,
                        onTap: _openCatalog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: const Color(0xFF009FE3),
                    surfaceTintColor: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Image.asset(
                        'assets/icons/services/sos.png',
                        width: 48,
                        height: 48,
                        excludeFromSemantics: true,
                      ),
                      title: Text(
                        'SOS Bahari / Lapor Darurat',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Buka formulir laporan. Tidak mengirim otomatis.',
                        style: const TextStyle(color: Colors.black),
                      ),
                      onTap: () {
                        if (!_routeOpen) _openSos();
                      },
                    ),
                  ),
                  _heading('Cari Layanan Sesuai Kebutuhanmu'),
                  PersonaChoices(
                    onSelected: (persona) => _openDiscovery(
                      PersonaDetailScreen(persona: persona, services: services),
                    ),
                  ),
                  _heading('Mendukung Pembudidaya'),
                  SupportBanners(
                    initialPaused: _supportPaused,
                    onPausedChanged: (paused) => _supportPaused = paused,
                    onSelected: (index) => _openPage(switch (index) {
                      0 => AnalysisScreen(api: _apiService),
                      1 => PasarScreen(api: _apiService),
                      2 => ForumScreen(api: _apiService),
                      _ => const ConsultationScreen(),
                    }),
                  ),
                  _heading('Panduan Aplikasi'),
                  SizedBox(
                    height: 210 + MediaQuery.textScalerOf(context).scale(230),
                    child: PageView.builder(
                      controller: _bannerController,
                      itemCount: appGuides.length,
                      onPageChanged: (index) =>
                          setState(() => _currentBannerIndex = index),
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GuideBanner(
                          guide: appGuides[index],
                          onTap: () => _openDiscovery(
                            AppGuideScreen(guide: appGuides[index]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Banner sebelumnya',
                        onPressed: () => _bannerController.previousPage(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('${_currentBannerIndex + 1} / ${appGuides.length}'),
                      IconButton(
                        tooltip: 'Banner berikutnya',
                        onPressed: () => _bannerController.nextPage(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  _heading('Berita & wawasan'),
                  Card(
                    color: const Color(0xFF009FE3),
                    surfaceTintColor: Colors.transparent,
                    child: ListTile(
                      textColor: Colors.black,
                      leading: Image.asset(
                        'assets/icons/services/berita.png',
                        width: 40,
                        height: 40,
                        excludeFromSemantics: true,
                      ),
                      title: const Text('Info Diskanla & Umum Terkini'),
                      subtitle: const Text(
                        'Info penyuluhan & berita perikanan',
                      ),
                      onTap: () => _openPage(BeritaScreen(api: _apiService)),
                    ),
                  ),
                  HomeNewsPreview(api: _apiService, openPage: _openPage),
                  _heading('Analisa Komoditas'),
                  TextButton(
                    onPressed: () =>
                        _openPage(SemuaKomoditasScreen(api: _apiService)),
                    child: const Text('Semua komoditas'),
                  ),
                  ReferenceListBuilder(
                    future: _fishList,
                    retry: () => _loadReference(_apiService.fetchFishTypes),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(
                              color: const Color(0xFF009FE3),
                            ),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                                size: 30,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Gagal terhubung ke Server.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Text(
                            "Belum ada data ikan.",
                            style: GoogleFonts.poppins(),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length > 2
                            ? 2
                            : snapshot.data!.length,
                        itemBuilder: (context, index) {
                          var ikan = snapshot.data![index];
                          String nama = ikan['name'] ?? 'Tanpa Nama';
                          String fcr = ikan['fcr_ratio']?.toString() ?? '-';
                          String panen =
                              ikan['harvest_duration_days']?.toString() ?? '-';
                          var harga = ikan['market_price_per_kg'];
                          String? imageUrl = ikan['image_url'];

                          return GestureDetector(
                            onTap: () {
                              _openPage(
                                AnalysisScreen(
                                  api: _apiService,
                                  autoFishName: nama,
                                  autoPrice: harga.toString(),
                                  autoFcr: fcr,
                                  autoPeriod: panen,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CommodityCard(
                                name: nama,
                                specs: "FCR $fcr • Panen $panen Hari",
                                price: formatRupiah(harga),
                                imageUrl: imageUrl,
                                home: true,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => _openPage(const IconCreditsScreen()),
                    child: const Text('Kredit ilustrasi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildBeranda(),
      BeritaScreen(api: _apiService),
      PasarScreen(api: _apiService),
      _isLoggedIn ? ProfilScreen(api: _apiService) : const LoginScreen(),
    ];
    return Scaffold(
      body: pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? GombyangButton(
              key: const Key('home-asisten'),
              onPressed: () =>
                  _openPage(AsistenSamuderaScreen(api: _apiService)),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex < 2 ? _selectedIndex : _selectedIndex + 1,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF009FE3),
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 2) {
            _openSosCamera();
            return;
          }
          if (_sosOpen || _routeOpen || _catalogOpen || _externalInfoOpen) {
            return;
          }
          setState(() => _selectedIndex = index < 2 ? index : index - 1);
          _checkLoginStatus();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'Berita'),
          BottomNavigationBarItem(
            icon: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF7941D),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  key: Key('sos-camera'),
                  color: Colors.black,
                ),
              ),
            ),
            label: 'SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            label: 'Pasar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
