class Reminder {
  final int id;
  final String title;
  final String dateTime;
  final int? categoryId;
  final bool isCompleted;

  const Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    this.categoryId,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateTime': dateTime,
    'categoryId': categoryId,
    'isCompleted': isCompleted,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'] as int,
    title: json['title'] as String,
    dateTime: json['dateTime'] as String,
    categoryId: json['categoryId'] as int?,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}
