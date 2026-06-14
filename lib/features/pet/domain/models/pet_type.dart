enum PetType {
  whale('whale', '🐳'),
  cow('cow', '🐄'),
  snake('snake', '🐍');

  const PetType(this.id, this.emoji);

  final String id;
  final String emoji;

  static PetType fromId(String id) {
    return PetType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => PetType.whale,
    );
  }

  String get displayName => switch (this) {
        PetType.whale => 'Whale',
        PetType.cow => 'Cow',
        PetType.snake => 'Snake',
      };
}
