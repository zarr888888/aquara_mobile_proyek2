import 'reference_data.dart';

const sosTypes = ['Wabah Penyakit', 'Pencemaran Limbah', 'Cuaca Ekstrem'];

class SosReport {
  const SosReport(
    this.id,
    this.type,
    this.description,
    this.status,
    this.photo,
    this.createdAt,
  );
  final int id;
  final String type;
  final String description;
  final String status;
  final String? photo;
  final DateTime? createdAt;

  factory SosReport.parse(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! int ||
        raw['id'] <= 0 ||
        raw['jenis_sos'] is! String ||
        raw['deskripsi'] is! String ||
        raw['status_laporan'] is! String) {
      throw const FormatException();
    }
    final status = raw['status_laporan'] as String;
    return SosReport(
      raw['id'],
      raw['jenis_sos'],
      raw['deskripsi'],
      const ['Pending', 'Diproses', 'Selesai'].contains(status)
          ? status
          : 'Status belum tersedia',
      referenceImage({'image': raw['foto']}),
      raw['created_at'] is String ? DateTime.tryParse(raw['created_at']) : null,
    );
  }
}
