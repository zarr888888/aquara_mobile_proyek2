import '../widgets/session_boundary.dart';
import '../widgets/profile_cooldown_state.dart';
import 'dart:async';
import '../models/reference_data.dart';
import '../widgets/reference_list_builder.dart';
import '../services/api_result.dart';
import '../models/pasar_item.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

import 'edit_profil_screen.dart';
import 'pasar_screen.dart';
import 'pengaturan_screen.dart';
import 'forum_screen.dart';

class ProfilScreen extends StatelessWidget {
  final String? publicUserId;
  final String? publicUserName;

  const ProfilScreen({
    super.key,
    this.publicUserId,
    this.publicUserName,
    this.api,
    this.clock,
  });
  final ApiService? api;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) => _ProfilScreenContent(
      api: api,
      clock: clock,
      publicUserId: publicUserId,
      publicUserName: publicUserName,
    ),
  );
}

class _ProfilScreenContent extends StatefulWidget {
  final String? publicUserId;
  final String? publicUserName;

  const _ProfilScreenContent({
    this.publicUserId,
    this.publicUserName,
    this.api,
    this.clock,
  });
  final ApiService? api;
  final DateTime Function()? clock;

  @override
  _ProfilScreenState createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<_ProfilScreenContent>
    with
        SessionOwnedState<_ProfilScreenContent>,
        WidgetsBindingObserver,
        ProfileCooldownState<_ProfilScreenContent> {
  @override
  DateTime profileNow() => (widget.clock ?? DateTime.now)();
  late final ApiService _apiService = widget.api ?? ApiService();
  @override
  get stateSession => _apiService.session;
  StreamSubscription<int>? _metadataSubscription;
  bool _profileLoading = false;
  String? _profileError;

  String _currentUserId = '';
  String _currentUserName = '';
  bool _isMyProfile = true;

  String _fokusBudidaya = "Memuat data...";
  String _fotoProfilUrl = "";

  Future<ApiResult<List<dynamic>>>? _stokIkanFuture;

  @override
  void initState() {
    super.initState();
    openProfileCooldown();
    _loadProfileData();
    _metadataSubscription = stateSession.changes.listen((_) {
      if (!sessionActive) return;
      setState(_syncMetadata);
    });
  }

  void _syncMetadata() {
    final metadata = stateSession.metadata;
    _currentUserId = metadata['user_id'] ?? '';
    _currentUserName = metadata['user_name'] ?? '';
    _fotoProfilUrl = referenceImage({'image': metadata['foto_profil']}) ?? '';
  }

  @override
  void dispose() {
    _metadataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (!sessionActive || _profileLoading || profileWait > 0) return;
    _syncMetadata();
    if (widget.publicUserId != null && widget.publicUserId != _currentUserId) {
      setState(() => _isMyProfile = false);
      return;
    }
    _profileLoading = true;
    _stokIkanFuture ??= _loadPasar();
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;
    final result = await _apiService.currentUser(expectedSession: owner);
    if (!sessionActive || !stateSession.owns(owner)) return;
    setState(() {
      _profileLoading = false;
      if (!result.isSuccess) recordProfileFailure(result.failure!);
      _syncMetadata();
      _profileError = result.isSuccess
          ? null
          : 'Pembaruan profil gagal. ${result.failure!.message}';
      if (result.isSuccess) {
        final user = result.data as Map;
        _fokusBudidaya = user['fokus_budidaya'] ?? 'Belum ada fokus budidaya';
      }
    });
  }

  Future<ApiResult<List<dynamic>>> _loadPasar() async {
    final owner = await _apiService.session.snapshot();
    if (!sessionActive || !_apiService.session.owns(owner)) {
      return ApiResult.failure(
        ApiFailure(kind: ApiErrorKind.staleSession, message: 'Sesi berubah.'),
      );
    }
    final result = await _apiService.fetchPasar(expectedSession: owner);
    if (!sessionActive || !_apiService.session.owns(owner)) {
      return ApiResult.failure(
        ApiFailure(kind: ApiErrorKind.staleSession, message: 'Sesi berubah.'),
      );
    }
    if (!result.isSuccess) return result;
    return ApiResult.success(
      data: result.data!
          .where((item) => item['user_id']?.toString() == _currentUserId)
          .toList(),
      statusCode: 200,
    );
  }

  Future<void> _handleLogout() async {
    final result = await _apiService.logout();
    if (!mounted || !sessionActive) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Keluar lokal; pencabutan sesi server belum terkonfirmasi. ${result.failure!.message}',
          ),
        ),
      );
    }
    // SessionBoundary coordinates the single stack reset.
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMyProfile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Profil pengguna lain tidak tersedia.')),
      );
    }
    final indramayuBlue = const Color(0xFF009FE3);
    final indramayuGreen = const Color(0xFF8CC63F);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          _isMyProfile ? "Profil Saya" : "Informasi Penambak",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: indramayuBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isMyProfile)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PengaturanScreen(),
                  ),
                );
              },
            ),
          if (_isMyProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      "Keluar Akun",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      "Apakah Anda yakin ingin keluar?",
                      style: GoogleFonts.poppins(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Batal"),
                      ),
                      TextButton(
                        onPressed: _handleLogout,
                        child: Text(
                          "Keluar",
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _currentUserId.isEmpty && _isMyProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (profileWait > 0) Text(profileWaitMessage),
                  if (_profileError != null)
                    ListTile(
                      title: Text(_profileError!),
                      trailing: TextButton(
                        onPressed: _profileLoading || profileWait > 0
                            ? null
                            : _loadProfileData,
                        child: const Text('Muat ulang'),
                      ),
                    ),
                  if (_isMyProfile)
                    ListTile(
                      leading: const Icon(Icons.forum_outlined),
                      title: const Text('Forum Saya'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (!sessionActive) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ForumScreen(api: _apiService, mine: true),
                          ),
                        );
                      },
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                    decoration: BoxDecoration(
                      color: indramayuBlue,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_fotoProfilUrl.isNotEmpty) {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: const EdgeInsets.all(16),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        InteractiveViewer(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Image.network(
                                              _fotoProfilUrl,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: -10,
                                          right: -10,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: _fotoProfilUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.network(
                                      _fotoProfilUrl,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                            Icons.person,
                                            size: 60,
                                            color: indramayuBlue,
                                          ),
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 60,
                                    color: indramayuBlue,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentUserName,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.set_meal,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      "Fokus Budidaya:",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fokusBudidaya,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_isMyProfile)
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 45),
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditProfilScreen(
                                      api: _apiService,
                                      currentName: _currentUserName,
                                      currentFokus:
                                          _fokusBudidaya ==
                                              "Belum ada fokus budidaya"
                                          ? ""
                                          : _fokusBudidaya,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _loadProfileData();
                                }
                              },
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: Text(
                                "EDIT PROFIL LENGKAP",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isMyProfile ? "Stok Panen Saya" : "Stok Ikan Tersedia",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 300,
                    child: _stokIkanFuture == null
                        ? const Center(child: CircularProgressIndicator())
                        : ReferenceListBuilder(
                            clock: widget.clock ?? DateTime.now,
                            future: _stokIkanFuture!,
                            retry: _loadPasar,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return const Center(
                                  child: Text("Gagal memuat stok."),
                                );
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 50,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Belum ada stok ikan.",
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  var item = snapshot.data![index];
                                  return Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 1,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PasarScreen(
                                              api: _apiService,
                                              targetItemId: item['id'],
                                            ),
                                          ),
                                        );
                                        if (!sessionActive) return;
                                        final refreshed = _loadPasar();
                                        setState(() {
                                          _stokIkanFuture = refreshed;
                                        });
                                      },
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: pasarImage(item['foto']) != null
                                            ? Image.network(
                                                pasarImage(item['foto']) ?? '',
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      width: 50,
                                                      height: 50,
                                                      color: indramayuBlue
                                                          .withOpacity(0.1),
                                                      child: const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        color: Color(
                                                          0xFF009FE3,
                                                        ),
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                width: 50,
                                                height: 50,
                                                color: indramayuBlue
                                                    .withOpacity(0.1),
                                                child: const Icon(
                                                  Icons.water_drop,
                                                  color: Color(0xFF009FE3),
                                                ),
                                              ),
                                      ),
                                      title: Text(
                                        item['nama_ikan'] ?? '-',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "${item['harga']}/Kg",
                                        style: GoogleFonts.poppins(
                                          color: indramayuGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
