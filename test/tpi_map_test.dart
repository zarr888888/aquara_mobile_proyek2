import 'dart:convert';
import 'dart:typed_data';
import 'package:aquara_mobile/models/external_info.dart';
import 'package:aquara_mobile/widgets/curated_info.dart';
import 'package:aquara_mobile/widgets/tpi_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _Tiles extends TileProvider {
  _Tiles({bool broken = false})
    : image = MemoryImage(
        broken
            ? Uint8List(0)
            : base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/5ZkAAAAASUVORK5CYII=',
              ),
      );
  final MemoryImage image;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      image;
}

void main() {
  testWidgets(
    'Eretan: daftar dan pin menuju ID sama, tanpa koordinat tetap terdaftar',
    (t) async {
      final data = ExternalInfo.parse({
        'success': true,
        'message': 'Kurasi',
        'data': {
          'is_mock': false,
          'source': 'Fixture',
          'generated_at': '2026-11-22',
          'items': [
            for (final id in ['a', 'b', 'c'])
              {
                'id': id,
                'nama': 'Fasilitas $id',
                'alamat': 'Alamat $id',
                'desa': id == 'c' ? 'Lain' : 'Eretan',
                'kecamatan': 'Kandanghaur',
                'lat': id == 'a' ? -6.43 : null,
                'lng': id == 'a' ? 108.18 : null,
                'coordinate_source_url': id == 'a'
                    ? 'https://indramayukab.go.id/'
                    : null,
              },
          ],
        },
      }, ExternalInfoKind.tpi);
      await t.pumpWidget(
        MaterialApp(
          home: CuratedInfo(
            kind: ExternalInfoKind.tpi,
            data: data,
            busy: false,
            failure: false,
            wait: null,
            reload: null,
            tileProvider: _Tiles(),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'Eretan');
      await t.pump();
      expect(find.text('Fasilitas b'), findsOneWidget);
      expect(find.text('Fasilitas c'), findsNothing);
      await t.tap(find.text('Fasilitas a'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-a')), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.text('Peta'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-b')), findsNothing);
      await t.tap(find.byKey(const ValueKey('pin-a')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-a')), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.text('Daftar'));
      await t.pump();
      expect(find.text('Eretan'), findsOneWidget);
      expect(find.text('Fasilitas c'), findsNothing);
    },
  );
  for (final allowed in [true, false]) {
    testWidgets('Lokasi hanya setelah tombol, izin $allowed', (t) async {
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TpiMap(
              rows: const [],
              open: (_) {},
              tileProvider: _Tiles(),
              locate: () async {
                calls++;
                if (!allowed) {
                  throw const LocationNotice('Izin lokasi ditolak.');
                }
                return const LatLng(-6.4, 108.2);
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(calls, 0);
      await t.tap(find.text('Lokasi saya'));
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.bySemanticsLabel('Posisi Anda'),
        allowed ? findsOneWidget : findsNothing,
      );
      if (!allowed) expect(find.text('Izin lokasi ditolak.'), findsOneWidget);
    });
  }
  testWidgets('Tile gagal: pesan, peta tetap dapat digeser', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TpiMap(
            rows: const [],
            open: (_) {},
            tileProvider: _Tiles(broken: true),
          ),
        ),
      ),
    );
    await t.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await t.pump();
    await t.pump();
    expect(find.text('Peta gagal dimuat · Coba lagi'), findsOneWidget);
    final map = t.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    final old = map.camera.center;
    await t.drag(find.byType(FlutterMap), const Offset(80, 30));
    await t.pump();
    expect(map.camera.center, isNot(old));
  });
}
