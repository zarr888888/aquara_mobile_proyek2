import '../widgets/samudera_theme.dart';
import '../widgets/session_boundary.dart';
import '../widgets/profile_identity.dart';
import '../widgets/pasar_operation_state.dart';
import '../models/pasar_item.dart';
import '../services/omni_search.dart';
import '../widgets/home_services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'tambah_jualan_screen.dart';
import 'edit_jualan_screen.dart';
import 'pre_order_screen.dart';
import 'retail_screen.dart';

class PasarScreen extends StatelessWidget {
  final Map<String, dynamic>? product;
  final int? targetItemId;
  final int? targetOwnerId;
  const PasarScreen({
    super.key,
    this.product,
    this.targetItemId,
    this.targetOwnerId,
    this.api,
    this.clock,
  });
  final DateTime Function()? clock;
  final ApiService? api;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) => _PasarScreenContent(
      product: product,
      targetItemId: targetItemId,
      targetOwnerId: targetOwnerId,
      api: api,
      clock: clock,
    ),
  );
}

class _PasarScreenContent extends StatefulWidget {
  final Map<String, dynamic>? product;
  final int? targetItemId;
  final int? targetOwnerId;
  const _PasarScreenContent({
    this.product,
    this.targetItemId,
    this.targetOwnerId,
    this.api,
    this.clock,
  });
  final DateTime Function()? clock;
  final ApiService? api;

  @override
  _PasarScreenState createState() => _PasarScreenState();
}

class _PasarScreenState extends State<_PasarScreenContent>
    with
        SessionOwnedState<_PasarScreenContent>,
        WidgetsBindingObserver,
        PasarOperationState<_PasarScreenContent> {
  late final ApiService _apiService = widget.api ?? ApiService();
  @override
  get stateSession => _apiService.session;
  @override
  ApiService get pasarApi => _apiService;
  @override
  DateTime pasarNow() => (widget.clock ?? DateTime.now)();
  List<dynamic> _items = [];
  bool _loading = true;
  String? _category, _saleType;
  bool get _isLoggedIn => pasarActive;
  String? get currentUserId => stateSession.metadata['user_id'];

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    await openPasar();
    if (pasarActive && widget.product != null) {
      setState(() {
        _items = [widget.product!];
        _loading = false;
      });
      return;
    }
    if (pasarActive) await _refresh();
  }

  @override
  void clearPasarPrivate() {
    _items = [];
  }

  bool _reading = false;
  Future<void> _openRetail([Map<String, dynamic>? product]) async {
    if (!pasarActive || _preOrderOpening) return;
    _preOrderOpening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RetailScreen(api: _apiService, product: product),
        ),
      );
      if (pasarActive && product != null) await _refresh();
    } finally {
      _preOrderOpening = false;
    }
  }

  bool _preOrderOpening = false;
  Future<void> _openPreOrder({int? productId}) async {
    if (!pasarActive || _preOrderOpening) return;
    _preOrderOpening = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreOrderScreen(
          api: _apiService,
          view: productId == null ? PreOrderView.history : PreOrderView.form,
          id: productId,
          clock: widget.clock,
        ),
      ),
    );
    if (pasarActive) _preOrderOpening = false;
  }

  Future<void> _refresh({bool afterMutation = false}) async {
    if (!pasarActive || _reading || pasarRemaining > 0) return;
    _reading = true;
    setState(() => _loading = true);
    if (widget.product != null) {
      final result = await _apiService.contentDetail(
        ContentKind.pasar,
        widget.product!['id'],
        pasarOwner!,
      );
      if (!pasarActive) return;
      setState(() {
        _reading = false;
        _loading = false;
        _items = [if (result.isSuccess) result.data!];
        if (result.failure != null) {
          pasarFailure(result.failure!);
        } else {
          pasarUncertain = false;
          pasarMessage = null;
        }
      });
      return;
    }
    final result = await _apiService.fetchPasar(expectedSession: pasarOwner!);
    if (!pasarActive) return;
    _reading = false;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _items = List.of(result.data!);
        pasarUncertain = false;
        pasarMessage = afterMutation
            ? 'Aksi berhasil. Daftar diperbarui.'
            : null;
      } else {
        pasarFailure(result.failure!);
        if (afterMutation) {
          pasarMessage =
              'Aksi sudah berhasil, tetapi daftar belum tersinkron. Jangan ulangi aksi. $pasarMessage';
          pasarUncertain = true;
        }
      }
    });
  }

  Future<void> _editor({Map<String, dynamic>? item}) async {
    if (pasarBlocked ||
        _loading ||
        (item != null && !ownsPasar(item, currentUserId))) {
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => item == null
            ? TambahJualanScreen(api: _apiService)
            : EditJualanScreen(jualan: item, api: _apiService),
      ),
    );
    if (!pasarActive) return;
    if (result == true) await _refresh(afterMutation: true);
    if (result == 'check') await _refresh();
  }

  String formatRupiah(int price) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(price);
  }

  void _hubungiPenjual(String nomor, String namaIkan, String harga) async {
    if (!pasarActive || !RegExp(r'^\+?[0-9 ()-]+$').hasMatch(nomor)) return;
    String nomorClean = nomor.replaceAll(RegExp(r'[^0-9]'), '');
    if (nomorClean.isEmpty) return;
    if (nomorClean.startsWith('0')) {
      nomorClean = '62${nomorClean.substring(1)}';
    }

    String pesan =
        "Halo Bapak/Ibu, saya tertarik dengan *$namaIkan* seharga *$harga* yang ada di aplikasi AQUARA. Apakah masih tersedia?";
    String url = "https://wa.me/$nomorClean?text=${Uri.encodeComponent(pesan)}";

    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (!mounted || !sessionActive) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal membuka WhatsApp")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.product != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produk Pasar')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            pasarStatus(checkList: _refresh),
            if (_loading) const LinearProgressIndicator(),
            for (final item in _items) _buildPasarCard(item),
            if (!_loading && _items.isEmpty)
              TextButton(onPressed: _refresh, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.targetItemId == null ? 'Pasar Ikan Indramayu' : 'Produk Pasar',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: indramayuBlue,
        elevation: 0,
        actions: [
          ContentSearchAction(api: _apiService),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'Riwayat pre-order',
            onPressed: () => _openPreOrder(),
          ),
          IconButton(
            tooltip: 'Riwayat eceran',
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () => _openRetail(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Muat ulang Pasar',
            onPressed: _loading || pasarBusy || pasarRemaining > 0
                ? null
                : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          pasarStatus(checkList: _refresh),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              children: [
                DropdownButton<String>(
                  isExpanded: true,
                  value: _category,
                  hint: const Text('Semua kategori'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Semua kategori'),
                    ),
                    ...pasarCategories.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _saleType,
                  hint: const Text('Semua tipe'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Semua tipe'),
                    ),
                    ...pasarSaleTypes.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _saleType = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_loading) {
                  return Center(
                    child: CircularProgressIndicator(color: indramayuBlue),
                  );
                } else if (_items.isEmpty && pasarMessage != null) {
                  return Center(
                    child: TextButton(
                      onPressed: pasarRemaining > 0 ? null : _refresh,
                      child: const Text('Coba lagi'),
                    ),
                  );
                }

                List<dynamic> pasarItems = _items
                    .where(
                      (item) =>
                          (widget.targetItemId == null ||
                              item['id'] == widget.targetItemId) &&
                          (widget.targetOwnerId == null ||
                              item['user_id'] == widget.targetOwnerId) &&
                          (_category == null ||
                              item['kategori'] == _category) &&
                          (_saleType == null ||
                              item['tipe_penjualan'] == _saleType),
                    )
                    .toList();
                if (pasarItems.isEmpty) {
                  return Center(
                    child: Text(
                      widget.targetItemId == null
                          ? 'Belum ada jualan yang sesuai.'
                          : 'Produk tidak tersedia atau sudah dihapus.',
                    ),
                  );
                }

                if (widget.targetItemId != null) {
                  int targetIndex = pasarItems.indexWhere(
                    (item) => item['id'] == widget.targetItemId,
                  );
                  if (targetIndex != -1) {
                    var targetItem = pasarItems.removeAt(targetIndex);
                    pasarItems.insert(0, targetItem);
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pasarItems.length,
                  itemBuilder: (context, index) {
                    var item = pasarItems[index];
                    return _buildPasarCard(item);
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: _isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: pasarBlocked || _loading ? null : () => _editor(),
              label: Text(
                "Jual Hasil Tambak",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.add_shopping_cart),
              backgroundColor: const Color(0xFF8CC63F),
            )
          : null,
    );
  }

  Future<void> _confirmDeleteProduct(int id) async {
    if (pasarBlocked ||
        !_items.any(
          (item) => item['id'] == id && ownsPasar(item, currentUserId),
        )) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Hapus Jualan?"),
          content: const Text(
            "Anda yakin ingin menghapus ikan ini dari pasar?",
          ),
          actions: [
            TextButton(
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text(
                "Hapus",
                style: TextStyle(
                  color: SamuderaColors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );
    if (!pasarActive || pasarBlocked || confirmed != true) return;
    setState(() => pasarBusy = true);
    final result = await _apiService.deletePasarItem(
      id,
      expectedSession: pasarOwner!,
    );
    if (!pasarActive) return;
    if (result.isSuccess) {
      await _refresh(afterMutation: true);
    } else {
      pasarFailure(result.failure!, mutation: true);
    }
    if (pasarActive) setState(() => pasarBusy = false);
  }

  Widget _buildPasarCard(dynamic item) {
    String fotoUrl = pasarImage(item['foto']) ?? '';
    String namaIkan = item['nama_ikan'] ?? 'Ikan Tanpa Nama';
    String hargaFormatted = formatRupiah(item['harga']);
    String penjual = item['user'] != null
        ? item['user']['name']
        : 'Petani Anonim';
    String lokasi = item['lokasi'] ?? 'Indramayu';
    String deskripsi =
        item['deskripsi'] ?? 'Tidak ada keterangan spesifikasi/minimal order.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: fotoUrl.isNotEmpty
                ? Image.network(
                    fotoUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => const SizedBox(
                      height: 180,
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
                  )
                : Container(
                    height: 180,
                    width: double.infinity,
                    color: SamuderaColors.blue,
                    child: const Icon(
                      Icons.image,
                      size: 50,
                      color: SamuderaColors.blue,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        namaIkan,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hargaFormatted,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF009FE3),
                        ),
                      ),
                    ),

                    if (ownsPasar(item, currentUserId))
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: PopupMenuButton<String>(
                          enabled: !pasarBlocked && !_loading,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await _editor(item: item);
                            } else if (value == 'delete') {
                              _confirmDeleteProduct(item['id']);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text("Edit Jualan"),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                "Hapus Jualan",
                                style: TextStyle(color: SamuderaColors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  'Stok: ${item['stok'] ?? 'Tidak tersedia'} • Kategori: ${pasarCategories.contains(item['kategori']) ? item['kategori'] : 'Tidak diketahui'} • Tipe: ${pasarSaleTypes.contains(item['tipe_penjualan']) ? item['tipe_penjualan'] : 'Tidak diketahui'}',
                ),
                Row(
                  children: [
                    Flexible(
                      child: ProfileIdentity(
                        api: _apiService,
                        profile: item['profile'],
                        fallbackName: penjual,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: SamuderaColors.orange,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        lokasi,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SamuderaColors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SamuderaColors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: SamuderaColors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deskripsi,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 24),

                if (item['tipe_penjualan'] == 'grosir')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          _openPreOrder(productId: item['id'] as int),
                      child: const Text('Ajukan pre-order'),
                    ),
                  ),
                if (item['tipe_penjualan'] == 'eceran')
                  TextButton(
                    onPressed:
                        ownsPasar(item, currentUserId) ||
                            (item['satuan_jual'] != null && item['harga'] > 0)
                        ? () => _openRetail(Map<String, dynamic>.from(item))
                        : null,
                    child: Text(
                      ownsPasar(item, currentUserId)
                          ? 'Atur harga dan satuan'
                          : item['satuan_jual'] == null
                          ? 'Satuan belum ditetapkan penjual'
                          : 'Pesan eceran (${item['satuan_jual']})',
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _hubungiPenjual(
                      item['nomor_wa'],
                      namaIkan,
                      hargaFormatted,
                    ),
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: Text(
                      "NEGO VIA WHATSAPP",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8CC63F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
