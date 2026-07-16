class CheckInCategory {
  final int id;
  final String name;
  final String emoji;
  final String? description;
  final String? startTime;
  final bool isDefault;

  const CheckInCategory({
    required this.id,
    required this.name,
    required this.emoji,
    this.description,
    this.startTime,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'description': description,
    'startTime': startTime,
    'isDefault': isDefault,
  };

  factory CheckInCategory.fromJson(Map<String, dynamic> json) => CheckInCategory(
    id: json['id'] as int,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    description: json['description'] as String?,
    startTime: json['startTime'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
  );
}
