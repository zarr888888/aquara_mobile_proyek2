import 'reference_data.dart';

const pasarCategories = ['tawar', 'laut', 'olahan'];
const pasarSaleTypes = ['eceran', 'grosir'];

int? pasarInteger(Object? value) {
  if (value is int) return value >= 0 && value <= 999999999 ? value : null;
  if (value is String && RegExp(r'^[0-9]+$').hasMatch(value)) {
    final parsed = int.tryParse(value);
    return parsed != null && parsed <= 999999999 ? parsed : null;
  }
  return null;
}

String? pasarNumberError(String? value, {bool optional = false}) {
  if (optional && (value == null || value.isEmpty)) return null;
  return pasarInteger(value) == null
      ? 'Gunakan bilangan bulat 0–999999999 tanpa titik atau koma.'
      : null;
}

String? pasarTextError(String? value, int maximum) =>
    value == null || value.trim().isEmpty
    ? 'Bagian ini wajib diisi.'
    : value.runes.length > maximum
    ? 'Maksimal $maximum karakter.'
    : null;

String? pasarImage(Object? value) => referenceImage({'image': value});

bool ownsPasar(Map item, String? userId) {
  final id = int.tryParse(userId ?? '');
  return id != null && id > 0 && item['user_id'] == id;
}

/// Keep only product fields and the seller's presentation name, not contacts
/// from the user relation. Unknown optional legacy values remain unknown.
Map<String, dynamic> parsePasarItem(Object? raw) {
  if (raw is! Map || raw['id'] is! int || (raw['id'] as int) <= 0) {
    throw const FormatException();
  }
  final result = <String, dynamic>{'id': raw['id']};
  for (final key in ['nama_ikan', 'deskripsi', 'nomor_wa', 'lokasi']) {
    if (raw[key] is! String) throw const FormatException();
    result[key] = raw[key];
  }
  final price = pasarInteger(raw['harga']);
  if (price == null) throw const FormatException();
  result['harga'] = price;
  result['stok'] = pasarInteger(raw['stok']);
  result['user_id'] = raw['user_id'] is int && raw['user_id'] > 0
      ? raw['user_id']
      : null;
  for (final key in ['kategori', 'tipe_penjualan']) {
    result[key] = raw[key] is String ? raw[key] : null;
  }
  result['foto'] = raw['foto'] is String ? raw['foto'] : null;
  for (final key in ['created_at', 'updated_at']) {
    final value = raw[key];
    result[key] = value is String && DateTime.tryParse(value) != null
        ? value
        : null;
  }
  final user = raw['user'];
  result['user'] = user is Map && user['name'] is String
      ? {'name': user['name']}
      : null;
  return Map.unmodifiable(result);
}
