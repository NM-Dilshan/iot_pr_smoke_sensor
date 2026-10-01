enum ContactRelationship {
  family,
  parent,
  spouse,
  friend,
  supervisor,
  other;

  String get label => name[0].toUpperCase() + name.substring(1);
}

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phoneNumber,
    required this.relationship,
  });
  final String name;
  final String phoneNumber;
  final ContactRelationship relationship;
}
