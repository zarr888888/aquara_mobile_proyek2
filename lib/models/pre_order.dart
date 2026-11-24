/// Integer hundredths keep validation and display independent of binary doubles.
int? preOrderHundredths(String text) {
  if (!RegExp(r'^[0-9]{1,8}(,[0-9]{1,2})?$').hasMatch(text)) return null;
  final parts = text.split(',');
  final value =
      int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  return value > 0 && value <= 9999999999 ? value : null;
}

bool preOrderDateValid(String text) {
  if (!RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(text)) return false;
  final date = DateTime.tryParse(text);
  return date != null &&
      date.year > 0 &&
      date.toIso8601String().substring(0, 10) == text;
}

const preOrderTonError =
    'Isi tonase > 0 hingga 99999999,99; koma desimal, maksimal 2 angka, tanpa pemisah ribuan.';
const preOrderDateError =
    'Isi tanggal kalender YYYY-MM-DD, hari ini atau sesudahnya menurut server.';

int _integer(Object? value, {bool zero = false}) {
  if (value is! int || value < (zero ? 0 : 1)) {
    throw const FormatException();
  }
  return value;
}

class PreOrder {
  const PreOrder._(
    this.id,
    this.userId,
    this.pasarId,
    this.hundredths,
    this.pickupDate,
    this.paymentStatus,
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.canConfirm,
  );
  final int id, userId, pasarId, hundredths;
  final String pickupDate, paymentStatus;
  final String? createdAt, updatedAt;
  final String? confirmedAt;
  final bool canConfirm;
  String get tonnage =>
      '${hundredths ~/ 100},${(hundredths % 100).toString().padLeft(2, '0')}';
  String get statusLabel =>
      const ['Belum Bayar', 'DP', 'Lunas'].contains(paymentStatus)
      ? paymentStatus
      : 'Status belum dikenal';

  static PreOrder parse(Object? raw) {
    if (raw is! Map) throw const FormatException();
    final ton = raw['total_tonase'];
    final date = raw['tgl_pengambilan'];
    final status = raw['status_bayar'];
    if (ton is! String ||
        !RegExp(r'^[0-9]{1,8}\.[0-9]{2}$').hasMatch(ton) ||
        date is! String ||
        !preOrderDateValid(date) ||
        status is! String ||
        status.trim().isEmpty) {
      throw const FormatException();
    }
    final amount = preOrderHundredths(ton.replaceAll('.', ','));
    if (amount == null) throw const FormatException();
    String? timestamp(String key) {
      final value = raw[key];
      if (value == null) return null;
      if (value is! String || DateTime.tryParse(value) == null) {
        throw const FormatException();
      }
      return value;
    }

    return PreOrder._(
      _integer(raw['id']),
      _integer(raw['user_id']),
      _integer(raw['pasar_id']),
      amount,
      date,
      status,
      timestamp('created_at'),
      timestamp('updated_at'),
      timestamp('confirmed_at'),
      raw['can_confirm'] == true,
    );
  }
}

class PreOrderPage {
  const PreOrderPage._(
    this.items,
    this.currentPage,
    this.lastPage,
    this.total,
    this.from,
    this.to,
  );
  final List<PreOrder> items;
  final int currentPage, lastPage, total;
  final int? from, to;
  bool get hasNext => currentPage < lastPage;

  static PreOrderPage parse(Object? raw) {
    if (raw is! Map || raw['data'] is! List || raw['per_page'] != 20) {
      throw const FormatException();
    }
    final items = List<PreOrder>.unmodifiable(
      (raw['data'] as List).map(PreOrder.parse),
    );
    final current = _integer(raw['current_page']);
    final last = _integer(raw['last_page']);
    final total = _integer(raw['total'], zero: true);
    final from = raw['from'] == null ? null : _integer(raw['from']);
    final to = raw['to'] == null ? null : _integer(raw['to']);
    final expectedLast = total == 0 ? 1 : (total + 19) ~/ 20;
    if (last != expectedLast ||
        items.length > 20 ||
        (items.isEmpty && (from != null || to != null)) ||
        (items.isNotEmpty &&
            (from == null ||
                to == null ||
                to < from ||
                to - from + 1 != items.length ||
                from != (current - 1) * 20 + 1 ||
                to > total))) {
      throw const FormatException();
    }
    return PreOrderPage._(items, current, last, total, from, to);
  }
}
