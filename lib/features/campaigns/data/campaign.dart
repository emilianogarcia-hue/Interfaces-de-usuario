/// Campaña o jornada ecológica de la tabla `campaigns`.
class Campaign {
  const Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.participantsCount,
    required this.joined,
    this.colony,
    this.category,
  });

  factory Campaign.fromJson(Map<String, dynamic> json, {required bool joined}) {
    return Campaign(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      colony: json['colony']?.toString(),
      category: json['category']?.toString(),
      startsAt: DateTime.parse(json['starts_at'].toString()).toLocal(),
      endsAt: DateTime.parse(json['ends_at'].toString()).toLocal(),
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
      joined: joined,
    );
  }

  final int id;
  final String title;
  final String description;
  final String location;
  final String? colony;
  final String? category;
  final DateTime startsAt;
  final DateTime endsAt;
  final int participantsCount;
  final bool joined;

  bool isHappeningAt(DateTime moment) {
    return !moment.isBefore(startsAt) && moment.isBefore(endsAt);
  }

  Campaign copyWith({bool? joined, int? participantsCount}) {
    return Campaign(
      id: id,
      title: title,
      description: description,
      location: location,
      colony: colony,
      category: category,
      startsAt: startsAt,
      endsAt: endsAt,
      participantsCount: participantsCount ?? this.participantsCount,
      joined: joined ?? this.joined,
    );
  }
}
