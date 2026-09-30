enum TestType {
  vehicle,
  office;

  String get label => switch (this) {
    vehicle => 'Vehicle',
    office => 'Office',
  };
}
