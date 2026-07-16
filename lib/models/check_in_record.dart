class CheckInRecord {
  final int id;
  final int categoryId;
  final String date;
  final bool isCompleted;
  final String? note;
  final String? completedAt;

  const CheckInRecord({
    required this.id,
    required this.categoryId,
    required this.date,
    this.isCompleted = false,
    this.note,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'date': date,
    'isCompleted': isCompleted,
    'note': note,
    'completedAt': completedAt,
  };

  factory CheckInRecord.fromJson(Map<String, dynamic> json) => CheckInRecord(
    id: json['id'] as int,
    categoryId: json['categoryId'] as int,
    date: json['date'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    note: json['note'] as String?,
    completedAt: json['completedAt'] as String?,
  );
}
