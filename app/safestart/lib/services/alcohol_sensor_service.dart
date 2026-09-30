/// Supplies a raw sensor value without classification, units, or storage.
abstract class AlcoholSensorService {
  Future<double> readAlcoholLevel();
}
