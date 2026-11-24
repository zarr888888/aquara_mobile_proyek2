const asistenMessageError =
    'Isi pesan 1–2000 karakter. Pesan kosong tidak dapat dikirim.';

// Laravel string max uses Unicode code points, not UTF-16 units or graphemes.
bool asistenMessageValid(String value) =>
    value.trim().isNotEmpty && value.runes.length <= 2000;

int _integer(Object? value, {bool zero = false}) {
  if (value is! int || value < (zero ? 0 : 1)) throw const FormatException();
  return value;
}

DateTime _timestamp(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
      ).hasMatch(value)) {
    throw const FormatException();
  }
  final date = DateTime.tryParse(value);
  if (date == null ||
      date.year < 1 ||
      date.toIso8601String().substring(0, 19) != value.substring(0, 19)) {
    throw const FormatException();
  }
  return date;
}

class AsistenChat {
  const AsistenChat._(
    this.id,
    this.question,
    this.answer,
    this.createdAt,
    this.isMock,
  );
  final bool isMock;
  final int id;
  final String question, answer;
  final DateTime createdAt;

  static AsistenChat parse(Object? raw, {bool post = false}) {
    if (raw is! Map ||
        ((post || raw.containsKey('is_mock')) && raw['is_mock'] is! bool)) {
      throw const FormatException();
    }
    final question = raw[post ? 'message' : 'pertanyaan'];
    final answer = raw[post ? 'reply' : 'jawaban'];
    if (question is! String ||
        !asistenMessageValid(question) ||
        answer is! String ||
        answer.trim().isEmpty) {
      throw const FormatException();
    }
    return AsistenChat._(
      _integer(raw['id']),
      question,
      answer,
      _timestamp(raw['created_at']),
      raw['is_mock'] != false,
    );
  }

  static List<AsistenChat> merge(
    Iterable<AsistenChat> old,
    Iterable<AsistenChat> incoming,
  ) {
    final byId = {
      for (final item in [...old, ...incoming]) item.id: item,
    };
    return byId.values.toList()..sort((a, b) {
      final time = a.createdAt.compareTo(b.createdAt);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
  }
}

class AsistenPage {
  const AsistenPage._(this.items, this.currentPage, this.lastPage, this.total);
  final List<AsistenChat> items;
  final int currentPage, lastPage, total;
  bool get hasNext => currentPage < lastPage;

  static AsistenPage parse(Object? raw) {
    if (raw is! Map || raw['data'] is! List || raw['per_page'] != 20) {
      throw const FormatException();
    }
    final items = List<AsistenChat>.unmodifiable(
      (raw['data'] as List).map(AsistenChat.parse),
    );
    final current = _integer(raw['current_page']);
    final last = _integer(raw['last_page']);
    final total = _integer(raw['total'], zero: true);
    final from = raw['from'];
    final to = raw['to'];
    if (last != (total == 0 ? 1 : (total + 19) ~/ 20) ||
        items.length > 20 ||
        (items.isEmpty && (from != null || to != null)) ||
        (items.isNotEmpty &&
            (from is! int ||
                to is! int ||
                from != (current - 1) * 20 + 1 ||
                to - from + 1 != items.length ||
                to > total))) {
      throw const FormatException();
    }
    return AsistenPage._(items, current, last, total);
  }
}
