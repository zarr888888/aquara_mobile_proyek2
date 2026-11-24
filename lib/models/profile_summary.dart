import 'reference_data.dart';

/// Allowlisted relation only. Never infer a profile from legacy IDs or names.
Map<String, dynamic>? profileRelation(Object? raw, Object? owner) {
  if (raw is! Map ||
      raw['id'] is! int ||
      raw['id'] <= 0 ||
      raw['name'] is! String ||
      '${raw['id']}' != '$owner' ||
      (raw['foto_profil'] != null && raw['foto_profil'] is! String)) {
    return null;
  }
  return Map.unmodifiable({
    'id': raw['id'],
    'name': raw['name'],
    'foto_profil': referenceImage({'image': raw['foto_profil']}),
  });
}

class ProfileSummary {
  const ProfileSummary(this.id, this.name, this.photo, [this.focus]);
  final int id;
  final String name;
  final String? photo;
  final String? focus;

  factory ProfileSummary.parse(Object? raw, int target) {
    final relation = profileRelation(raw, target);
    if (relation == null) throw const FormatException();
    final focus = (raw as Map)['fokus_budidaya'];
    if (focus != null && focus is! String) throw const FormatException();
    return ProfileSummary(
      relation['id'],
      relation['name'],
      relation['foto_profil'],
      focus,
    );
  }
}
