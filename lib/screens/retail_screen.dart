import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/api_result.dart';
import '../services/retail_api.dart';
import '../widgets/session_boundary.dart';
import '../widgets/profile_cooldown_state.dart';
import '../models/pasar_item.dart';

class RetailScreen extends StatelessWidget {
  const RetailScreen({super.key, required this.api, this.product});
  final ApiService api;
  final Map<String, dynamic>? product;
  @override
  Widget build(BuildContext context) =>
      SessionBoundary(api: api, builder: (_) => _Retail(api, product));
}

class _Retail extends StatefulWidget {
  const _Retail(this.api, this.product);
  final ApiService api;
  final Map<String, dynamic>? product;
  @override
  State<_Retail> createState() => _RetailState();
}

class _RetailState extends State<_Retail>
    with
        SessionOwnedState<_Retail>,
        WidgetsBindingObserver,
        ProfileCooldownState<_Retail> {
  @override
  get stateSession => widget.api.session;
  final input = TextEditingController();
  String? unit, message;
  bool busy = false, done = false;
  int page = 1, last = 1;
  List<RetailRow> rows = [];
  bool get seller =>
      widget.product != null &&
      ownsPasar(widget.product!, stateSession.metadata['user_id']);
  @override
  void initState() {
    super.initState();
    openProfileCooldown();
    unit = widget.product?['satuan_jual'];
    if (widget.product == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sessionActive) run();
      });
    }
  }

  @override
  void dispose() {
    input.dispose();
    rows = [];
    super.dispose();
  }

  Future<void> run({int? next, int? confirm, bool submit = false}) async {
    if (!sessionActive || busy || profileWait > 0 || (submit && done)) return;
    setState(() {
      busy = true;
      message = null;
    });
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;
    final p = widget.product;
    ApiFailure? failure;
    if (submit && p != null) {
      final text = input.text.trim().replaceAll(',', '.');
      if (seller) {
        final price = int.tryParse(text);
        if (unit == null || price == null || price < 1 || price > 999999999) {
          setState(() {
            busy = false;
            message = 'Pilih satuan dan isi harga rupiah bulat positif.';
          });
          return;
        }
        final r = await widget.api.retailOffer(owner, p['id'], unit!, price);
        failure = r.failure;
        if (!sessionActive) return;
        if (r.isSuccess) {
          done = true;
          message = 'Penawaran tersimpan.';
        }
      } else {
        if (unit == null || !validRetailQuantity(unit!, text)) {
          setState(() {
            busy = false;
            message = 'Jumlah tidak valid untuk satuan ini.';
          });
          return;
        }
        final r = await widget.api.retailBuy(
          owner,
          p['id'],
          unit!,
          p['harga'],
          text,
        );
        failure = r.failure;
        if (!sessionActive) return;
        if (r.isSuccess) {
          done = true;
          rows = [r.data!];
          message = 'Pesanan tersimpan.';
        } else if (r.statusCode == 409) {
          done = true;
          message = 'Penawaran berubah. Kembali dan muat ulang Pasar.';
        } else if (r.statusCode == null ||
            r.statusCode == 201 ||
            (r.statusCode ?? 0) >= 500) {
          done = true;
          message = 'Hasil belum pasti. Periksa riwayat sebelum memesan lagi.';
        }
      }
    } else if (confirm != null) {
      final r = await widget.api.retailConfirm(owner, confirm);
      failure = r.failure;
      if (!sessionActive) return;
      if (r.isSuccess) {
        rows = [
          for (final row in rows)
            if (row['id'] == confirm) r.data! else row,
        ];
      }
    } else {
      final n = next ?? 1;
      final r = await widget.api.retailHistory(owner, n);
      failure = r.failure;
      if (!sessionActive) return;
      if (r.isSuccess) {
        rows = r.data!.rows;
        page = n;
        last = r.data!.last;
      }
    }
    if (!sessionActive) return;
    setState(() {
      busy = false;
      if (failure != null) {
        recordProfileFailure(failure);
        message ??= failure.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final enabled = !busy && profileWait == 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan eceran')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Pembayaran langsung kepada penjual. Konfirmasi bukan bukti pembayaran.',
            ),
            if (p != null) ...[
              Text('${p['nama_ikan']}'),
              if (seller)
                DropdownButton<String>(
                  hint: const Text('Pilih satuan jual'),
                  value: unit,
                  items: [
                    for (final u in ['kg', 'ekor', 'kemasan'])
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: enabled && !done
                      ? (v) => setState(() => unit = v)
                      : null,
                )
              else
                Text('Rp ${p['harga']} / $unit'),
              TextField(
                controller: input,
                enabled: enabled && !done,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !seller && unit == 'kg',
                ),
                decoration: InputDecoration(
                  labelText: seller
                      ? 'Harga rupiah per satuan'
                      : 'Jumlah ($unit)',
                  helperText: !seller && unit == 'kg'
                      ? 'Maksimal 3 angka desimal'
                      : null,
                ),
              ),
              FilledButton(
                onPressed: enabled && !done ? () => run(submit: true) : null,
                child: Text(
                  seller ? 'Simpan harga dan satuan' : 'Pesan kepada penjual',
                ),
              ),
            ] else
              TextButton(
                onPressed: enabled ? () => run(next: page) : null,
                child: const Text('Muat ulang riwayat'),
              ),
            if (busy) const LinearProgressIndicator(),
            if (message != null) Text(message!),
            if (profileWait > 0) Text(profileWaitMessage),
            if (p == null && !busy && message == null && rows.isEmpty)
              const Text('Belum ada pesanan eceran.'),
            for (final r in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${r['id']} · ${r['nama_ikan']}'),
                      Text(
                        '${r['jumlah']} ${r['satuan_jual']} × Rp ${r['harga_satuan']} · Total Rp ${r['total_harga']}',
                      ),
                      Text(
                        '${r['confirmed_at'] == null ? 'Menunggu konfirmasi' : 'Dikonfirmasi penjual'} · ${r['status_bayar']}',
                      ),
                      if (r['seller_id'].toString() ==
                              stateSession.metadata['user_id'] &&
                          r['confirmed_at'] == null)
                        FilledButton(
                          onPressed: enabled
                              ? () => run(confirm: r['id'])
                              : null,
                          child: const Text('Konfirmasi pesanan'),
                        ),
                    ],
                  ),
                ),
              ),
            if (page > 1)
              TextButton(
                onPressed: enabled ? () => run(next: page - 1) : null,
                child: const Text('Sebelumnya'),
              ),
            if (page < last)
              TextButton(
                onPressed: enabled ? () => run(next: page + 1) : null,
                child: const Text('Berikutnya'),
              ),
          ],
        ),
      ),
    );
  }
}
