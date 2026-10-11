/// Session-memory value only. A refreshed GET always replaces local read state.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.referenceId,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final int? referenceId;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Object? value) {
    if (value is! Map ||
        value['id'] is! int ||
        value['id'] <= 0 ||
        value['title'] is! String ||
        value['message'] is! String) {
      throw const FormatException();
    }
    final read = value['is_read'];
    final bool normalized;
    if (read is bool) {
      normalized = read;
    } else if (read is num && (read == 0 || read == 1)) {
      normalized = read == 1;
    } else {
      throw const FormatException();
    }
    final reference = value['reference_id'];
    return AppNotification(
      id: value['id'] as int,
      title: value['title'] as String,
      message: value['message'] as String,
      type: value['type'] is String ? value['type'] as String : '',
      isRead: normalized,
      referenceId: reference is int && reference > 0 ? reference : null,
      createdAt: value['created_at'] is String
          ? DateTime.tryParse(value['created_at'] as String)
          : null,
    );
  }

  AppNotification asRead() => AppNotification(
    id: id,
    title: title,
    message: message,
    type: type,
    isRead: true,
    referenceId: referenceId,
    createdAt: createdAt,
  );
}
