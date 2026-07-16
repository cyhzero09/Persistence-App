class CheckInCategory {
  final int id;
  final String name;
  final String emoji;
  final String? description;
  final String? startTime;
  final String? endTime;
  final String? repeatWeekdays;
  final bool isDefault;

  const CheckInCategory({
    required this.id,
    required this.name,
    required this.emoji,
    this.description,
    this.startTime,
    this.endTime,
    this.repeatWeekdays,
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
    isDefault: json['isDefault'] as bool? ?? false,
  );

  bool get isRepeating => repeatWeekdays != null && repeatWeekdays!.isNotEmpty;
}
