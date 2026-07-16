class DiaryEntry {
  final int id;
  final String date;
  final String? title;
  final String content;
  final int? checkInRecordId;

  const DiaryEntry({
    required this.id,
    required this.date,
    this.title,
    required this.content,
    this.checkInRecordId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'title': title,
    'content': content,
    'checkInRecordId': checkInRecordId,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as int,
    date: json['date'] as String,
    title: json['title'] as String?,
    content: json['content'] as String,
    checkInRecordId: json['checkInRecordId'] as int?,
  );
}
