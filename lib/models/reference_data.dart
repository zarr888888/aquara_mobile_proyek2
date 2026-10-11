import '../services/auth_service.dart';

/// Legacy storage convention, derived from the configured API origin.
String? referenceImage(Map data) {
  for (final value in [data['image'], data['image_url']]) {
    if (value is! String || value.isEmpty) continue;
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty) {
      return value;
    }
  }
  final value = data['image'];
  if (value is! String || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      value.startsWith('/') ||
      value.contains('..') ||
      value.contains('\\')) {
    return null;
  }
  return Uri.parse(
    AuthService.apiBaseUrl,
  ).resolve('/storage/$value').toString();
}

List<dynamic> parseReferenceList(Object? payload, String path) {
  if (payload is! Map ||
      (path == 'fish-types'
          ? payload['status'] != 'success'
          : payload['success'] != true) ||
      payload['data'] is! List) {
    throw const FormatException();
  }
  return List.unmodifiable(
    (payload['data'] as List).map((raw) {
      if (raw is! Map<String, dynamic> || raw['id'] is! int) {
        throw const FormatException();
      }
      final item = Map<String, dynamic>.from(raw);
      final textFields = switch (path) {
        'fish-types' => ['name'],
        'stocks' => ['pengepul_name', 'location', 'phone_number'],
        _ => ['title', 'content', 'category', 'author'],
      };
      for (final key in textFields) {
        if (item[key] != null && item[key] is! String) {
          throw const FormatException();
        }
        item[key] ??= '-';
      }
      final numericFields = switch (path) {
        'fish-types' => [
          'fcr_ratio',
          'harvest_duration_days',
          'market_price_per_kg',
          'standard_density_per_m2',
          'survival_rate',
          'feed_price_per_kg',
        ],
        'stocks' => ['amount_kg'],
        _ => <String>[],
      };
      for (final key in numericFields) {
        final value = num.tryParse(item[key].toString());
        if (value == null || !value.isFinite) throw const FormatException();
      }
      for (final key in ['created_at', 'updated_at']) {
        final value = item[key];
        item[key] = value is String && DateTime.tryParse(value) != null
            ? value
            : '';
      }
      if (path == 'stocks') {
        final fish = item['fish_type'];
        if (fish != null && fish is! Map<String, dynamic>) {
          throw const FormatException();
        }
        item['fish_type'] = fish == null
            ? null
            : {
                ...fish,
                'name': fish['name'] is String ? fish['name'] : '-',
                'image_url': referenceImage(fish),
              };
      }
      item['image_url'] = referenceImage(item);
      return item;
    }),
  );
}
