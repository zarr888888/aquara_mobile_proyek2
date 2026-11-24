import 'package:flutter/material.dart';
import 'profile_identity.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name, this.photo, this.focus});
  final String name;
  final String? photo, focus;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
    decoration: const BoxDecoration(
      color: Color(0xFF009FE3),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
    ),
    child: Column(
      children: [
        ProfileAvatar(photo: photo, size: 100),
        const SizedBox(height: 16),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fokus Usaha:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                focus == null || focus!.trim().isEmpty
                    ? 'Belum ada fokus usaha'
                    : focus!,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
