import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/external_info.dart';
import 'samudera_theme.dart';

class LocationNotice implements Exception {
  const LocationNotice(this.message);
  final String message;
}

Future<LatLng> foregroundPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationNotice('GPS tidak aktif.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    throw const LocationNotice('Izin lokasi ditolak.');
  }
  final p = await Geolocator.getCurrentPosition(
    locationSettings: defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            forceLocationManager: true,
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 12),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
  );
  return LatLng(p.latitude, p.longitude);
}

class TpiMap extends StatefulWidget {
  const TpiMap({
    super.key,
    required this.rows,
    required this.open,
    this.locate = foregroundPosition,
    this.tileProvider,
  });
  final List<TpiInfoItem> rows;
  final ValueChanged<String> open;
  final Future<LatLng> Function() locate;
  final TileProvider? tileProvider;
  @override
  State<TpiMap> createState() => _TpiMapState();
}

class _TpiMapState extends State<TpiMap> {
  final controller = MapController();
  LatLng? position;
  bool busy = false, failed = false;
  int attempt = 0;
  Future<void> _locate() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final point = await widget.locate();
      if (!mounted) return;
      controller.move(point, 14);
      setState(() => position = point);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is LocationNotice ? e.message : 'Lokasi belum ditemukan.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = widget.rows.where((r) => r.coordinateSource != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pins.isEmpty) const Text('Titik TPI belum terverifikasi'),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: busy ? null : _locate,
            icon: const Icon(Icons.my_location),
            label: Text(busy ? 'Mencari lokasi…' : 'Lokasi saya'),
          ),
        ),
        if (failed)
          TextButton.icon(
            onPressed: () => setState(() {
              failed = false;
              attempt++;
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Peta gagal dimuat · Coba lagi'),
          ),
        Expanded(
          child: FlutterMap(
            mapController: controller,
            options: const MapOptions(
              initialCenter: LatLng(-6.43, 108.18),
              initialZoom: 8.5,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                key: ValueKey(attempt),
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.aquara.app.aquara_mobile',
                tileProvider: widget.tileProvider,
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                errorTileCallback: (tile, error, stack) {
                  if (!failed && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !failed) setState(() => failed = true);
                    });
                  }
                },
              ),
              MarkerLayer(
                markers: [
                  for (final r in pins)
                    Marker(
                      point: LatLng(
                        r.latitude!.toDouble(),
                        r.longitude!.toDouble(),
                      ),
                      width: 48,
                      height: 48,
                      child: IconButton(
                        key: ValueKey('pin-${r.id}'),
                        tooltip: r.name,
                        onPressed: () => widget.open(r.id),
                        icon: const Icon(
                          Icons.location_on,
                          color: Color(0xffad3024),
                          size: 32,
                        ),
                      ),
                    ),
                  if (position != null)
                    Marker(
                      point: position!,
                      child: const Icon(
                        Icons.my_location,
                        color: SamuderaColors.blue,
                        semanticLabel: 'Posisi Anda',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Text('© OpenStreetMap contributors', textAlign: TextAlign.end),
      ],
    );
  }
}
