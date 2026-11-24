import 'package:flutter/material.dart';
import '../models/reference_data.dart';
import '../screens/member_profile_screen.dart';
import '../screens/profil_screen.dart';
import '../services/api_service.dart';
import 'session_boundary.dart';

class ProfileNavigation {
  static final _opening = Expando<bool>();

  static Future<void> open(BuildContext context, ApiService api, int id) async {
    final navigator = Navigator.of(context);
    if (id <= 0 || _opening[navigator] == true) return;
    _opening[navigator] = true;
    final revision = api.session.revision;
    try {
      final owner = await api.session.snapshot();
      if (!context.mounted || revision != api.session.revision) return;
      if (!api.session.owns(owner)) {
        SessionNavigation.leaveNavigator(navigator);
        return;
      }
      final self = int.tryParse(api.session.metadata['user_id'] ?? '') == id;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => self
              ? ProfilScreen(api: api)
              : MemberProfileScreen(api: api, userId: id),
        ),
      );
    } finally {
      _opening[navigator] = false;
    }
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.photo, this.size = 40});
  final String? photo;
  final double size;
  @override
  Widget build(BuildContext context) {
    final url = referenceImage({'image': photo});
    final fallback = Icon(Icons.person_outline, size: size * .7);
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  // No API headers, token, or authenticated transport for images.
                  errorBuilder: (_, error, stack) => fallback,
                ),
        ),
      ),
    );
  }
}

class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({
    super.key,
    required this.api,
    required this.profile,
    required this.fallbackName,
  });
  final ApiService api;
  final Map<String, dynamic>? profile;
  final String fallbackName;
  @override
  Widget build(BuildContext context) {
    final id = profile?['id'];
    final enabled = id is int && id > 0;
    final name = profile?['name'] as String? ?? fallbackName;
    return Tooltip(
      message: enabled ? 'Buka profil $name' : 'Profil penulis tidak tersedia',
      child: Semantics(
        button: enabled,
        child: InkWell(
          onTap: enabled
              ? () => ProfileNavigation.open(context, api, id)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Row(
              children: [
                ProfileAvatar(photo: profile?['foto_profil'] as String?),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
