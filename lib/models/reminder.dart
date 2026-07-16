class Reminder {
  final int id;
  final String title;
  final String dateTime;
  final String? repeatWeekdays;
  final String? repeatEndDate;
  final int? categoryId;
  final bool isCompleted;

  const Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    this.repeatWeekdays,
    this.repeatEndDate,
    this.categoryId,
    this.isCompleted = false,
  });

  bool get isRepeating => repeatWeekdays != null && repeatWeekdays!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateTime': dateTime,
    'repeatWeekdays': repeatWeekdays,
    'repeatEndDate': repeatEndDate,
    'categoryId': categoryId,
    'isCompleted': isCompleted,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'] as int,
    title: json['title'] as String,
    dateTime: json['dateTime'] as String,
    repeatWeekdays: json['repeatWeekdays'] as String?,
    repeatEndDate: json['repeatEndDate'] as String?,
    categoryId: json['categoryId'] as int?,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}
