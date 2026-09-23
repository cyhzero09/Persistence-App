class CheckInCategory {
  final int id;
  final String name;
  final String emoji;
  final String? description;
  final String? startTime;
  final String? endTime;
  final String? repeatWeekdays;

  /// 打卡提醒时间（HH:mm）；null = 未开启提醒
  final String? reminderTime;
  final bool isDefault;

  const CheckInCategory({
    required this.id,
    required this.name,
    required this.emoji,
    this.description,
    this.startTime,
    this.endTime,
    this.repeatWeekdays,
    this.reminderTime,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'description': description,
    'startTime': startTime,
    'endTime': endTime,
    'repeatWeekdays': repeatWeekdays,
    'reminderTime': reminderTime,
    'isDefault': isDefault,
  };

  factory CheckInCategory.fromJson(Map<String, dynamic> json) => CheckInCategory(
    id: json['id'] as int,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    description: json['description'] as String?,
    startTime: json['startTime'] as String?,
    endTime: json['endTime'] as String?,
    repeatWeekdays: json['repeatWeekdays'] as String?,
    reminderTime: json['reminderTime'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
  );

  bool get isRepeating => repeatWeekdays != null && repeatWeekdays!.isNotEmpty;

  /// 是否开启了打卡提醒
  bool get hasReminder => reminderTime != null && reminderTime!.isNotEmpty;
}
