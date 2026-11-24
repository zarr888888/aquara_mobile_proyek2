import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Loads only when displayed; no startup work or version fallback constants.
class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key, this.style});
  final TextStyle? style;

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _info,
    builder: (context, snapshot) {
      final info = snapshot.data;
      final label = snapshot.connectionState != ConnectionState.done
          ? 'Memuat versi aplikasi…'
          : snapshot.hasError ||
                info == null ||
                info.version.trim().isEmpty ||
                info.buildNumber.trim().isEmpty
          ? 'Versi build belum tersedia'
          : 'Versi ${info.version} (${info.buildNumber})';
      return Text(label, textAlign: TextAlign.center, style: widget.style);
    },
  );
}
