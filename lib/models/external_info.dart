enum ExternalInfoKind {
  kkp('Info KKP'),
  cuaca('Info Cuaca'),
  tpi('Daftar TPI');

  const ExternalInfoKind(this.label);
  final String label;
  String get path => 'info/$name';
}

const externalInfoWarning =
    'DATA SIMULASI — bukan informasi resmi atau panduan keselamatan pelayaran.';

String _text(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid information text');
  }
  return value;
}

DateTime? _date(Map<String, dynamic> map, String key, {bool nullable = false}) {
  if (!map.containsKey(key)) throw const FormatException('Missing date');
  final value = map[key];
  if (nullable && value == null) return null;
  if (value is! String) throw const FormatException('Invalid date');
  final parsed = DateTime.tryParse(value);
  // DateTime.parse normalizes impossible calendar dates; reject those too.
  final calendar = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (parsed == null || calendar == null) {
    throw const FormatException('Invalid date');
  }
  final year = int.parse(calendar[1]!);
  final month = int.parse(calendar[2]!);
  final day = int.parse(calendar[3]!);
  final check = DateTime.utc(year, month, day);
  if (check.year != year || check.month != month || check.day != day) {
    throw const FormatException('Invalid calendar date');
  }
  return parsed;
}

num _number(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! num || !value.isFinite) {
    throw const FormatException('Invalid number');
  }
  return value;
}

sealed class ExternalInfoItem {
  const ExternalInfoItem(this.id);
  final String id;
}

class KkpInfoItem extends ExternalInfoItem {
  KkpInfoItem(Map<String, dynamic> map)
    : title = _text(map, 'judul'),
      publisher = _text(map, 'penerbit'),
      sourceUrl = _official(map, 'source_url'),
      summary = _text(map, 'ringkasan'),
      publishedAt = _date(map, 'published_at', nullable: true),
      super(_text(map, 'id'));
  final String title;
  final String publisher;
  final Uri sourceUrl;
  final String summary;
  final DateTime? publishedAt;
}

DateTime _instant(Map<String, dynamic> map, String key) {
  final date = _date(map, key)!;
  if (!date.isUtc) throw const FormatException('Missing time zone');
  return date;
}

class WeatherInfoItem extends ExternalInfoItem {
  WeatherInfoItem(Map<String, dynamic> map)
    : validAt = _instant(map, 'valid_at'),
      condition = _optionalText(map, 'kondisi'),
      direction = _optionalText(map, 'angin_dari'),
      category = _optionalText(map, 'kategori_gelombang'),
      temperature = _optionalNumber(map, 'suhu_c'),
      wind = _optionalNumber(map, 'kecepatan_angin_knot'),
      windKmh = _optionalNumber(map, 'kecepatan_angin_kmh'),
      gust = _optionalNumber(map, 'hembusan_angin_knot'),
      wave = _optionalNumber(map, 'tinggi_gelombang_m'),
      tide = _optionalNumber(map, 'pasang_surut_m'),
      super(_text(map, 'id'));
  final DateTime validAt;
  final String? condition, direction, category;
  final num? temperature, wind, windKmh, gust, wave, tide;

  static num? _optionalNumber(Map<String, dynamic> m, String k) =>
      m[k] == null ? null : _number(m, k);
  static String? _optionalText(Map<String, dynamic> m, String k) =>
      m[k] == null ? null : _text(m, k);
}

class WeatherBulletin extends ExternalInfo {
  WeatherBulletin._(
    String message,
    this.location,
    this.upcoming,
    this.from,
    this.to,
    this.slots,
    DateTime generated,
  ) : super._(message, 'BMKG', generated, slots);
  @override
  bool get isMock => false;
  final String location;
  final bool upcoming;
  final DateTime from, to;
  final List<WeatherInfoItem> slots;

  factory WeatherBulletin.parse(
    String message,
    Map<String, dynamic> data,
    String code,
  ) {
    final loc = data['location'];
    final status = data['status'];
    final rows = data['items'];
    if (data['is_mock'] != false ||
        data['source'] != 'BMKG' ||
        loc is! Map<String, dynamic> ||
        loc['code'] != code ||
        (status != 'available' && status != 'upcoming') ||
        rows is! List) {
      throw const FormatException('Invalid bulletin');
    }
    final from = _instant(data, 'valid_from'), to = _instant(data, 'valid_to');
    if (!from.isBefore(to)) throw const FormatException('Invalid period');
    final slots = <WeatherInfoItem>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid slot');
      }
      final slot = WeatherInfoItem(row);
      if (!slot.validAt.isBefore(from) && slot.validAt.isBefore(to)) {
        slots.add(slot);
      }
    }
    slots.sort((a, b) => a.validAt.compareTo(b.validAt));
    return WeatherBulletin._(
      message,
      _text(loc, 'name'),
      status == 'upcoming',
      from,
      to,
      List.unmodifiable(slots),
      _instant(data, 'generated_at'),
    );
  }

  WeatherInfoItem? slotAt(DateTime now) {
    if (!now.isBefore(to)) return null;
    if (upcoming) return slots.where((s) => s.validAt.isAfter(now)).firstOrNull;
    if (now.isBefore(from)) return null;
    return slots.where((s) => !s.validAt.isAfter(now)).lastOrNull;
  }
}

Uri _official(Map<String, dynamic> map, String key) {
  final url = Uri.tryParse(_text(map, key));
  if (url == null ||
      url.scheme != 'https' ||
      !url.host.endsWith('.go.id') ||
      url.userInfo.isNotEmpty ||
      url.port != 443) {
    throw const FormatException('Invalid official source');
  }
  return url;
}

class TpiInfoItem extends ExternalInfoItem {
  TpiInfoItem(Map<String, dynamic> map)
    : name = _text(map, 'nama'),
      address = _text(map, 'alamat'),
      village = map['desa'] == null ? '' : _text(map, 'desa'),
      district = _text(map, 'kecamatan'),
      coordinateSource = map['coordinate_source_url'] == null
          ? null
          : _official(map, 'coordinate_source_url'),
      latitude = map['lat'] == null ? null : _number(map, 'lat'),
      longitude = map['lng'] == null ? null : _number(map, 'lng'),
      super(_text(map, 'id')) {
    if ((latitude == null) != (longitude == null) ||
        (latitude == null) != (coordinateSource == null) ||
        (latitude?.abs() ?? 0) > 90 ||
        (longitude?.abs() ?? 0) > 180) {
      throw const FormatException('Invalid coordinates');
    }
  }
  final String name;
  final String address;
  final String village, district;
  final Uri? coordinateSource;
  final num? latitude, longitude;
}

class ExternalInfo {
  ExternalInfo._(this.message, this.source, this.generatedAt, this.items);
  final String message;
  final String source;
  final DateTime generatedAt;
  bool get isMock => false;
  final List<ExternalInfoItem> items;

  factory ExternalInfo.parse(
    Object? payload,
    ExternalInfoKind kind, {
    String code = 'XJ022',
  }) {
    if (payload is! Map<String, dynamic> || payload['success'] != true) {
      throw const FormatException('Invalid envelope');
    }
    final message = _text(payload, 'message');
    final data = payload['data'];
    if (kind == ExternalInfoKind.cuaca && data is Map<String, dynamic>) {
      return WeatherBulletin.parse(message, data, code);
    }
    if (data is! Map<String, dynamic> || data['is_mock'] != false) {
      throw const FormatException('Expected curated data');
    }
    final source = _text(data, 'source');
    final generatedAt = _date(data, 'generated_at')!;
    final items = data['items'];
    if (items is! List) throw const FormatException('Invalid items');
    final ids = <String>{};
    return ExternalInfo._(
      message,
      source,
      generatedAt,
      List.unmodifiable(
        items.map((item) {
          if (item is! Map<String, dynamic> || !ids.add(_text(item, 'id'))) {
            throw const FormatException('Invalid item');
          }
          return switch (kind) {
            ExternalInfoKind.kkp => KkpInfoItem(item),
            ExternalInfoKind.cuaca => throw const FormatException(
              'Expected bulletin',
            ),
            ExternalInfoKind.tpi => TpiInfoItem(item),
          };
        }),
      ),
    );
  }
}
