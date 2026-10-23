import 'package:esugid/emergency_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emergency categories route to the intended response agency', () {
    expect(EmergencyService.routeFor('Fire').key, 'bfp');
    expect(EmergencyService.routeFor('Medical').key, 'health');
    expect(EmergencyService.routeFor('Crime or Threat').key, 'pnp');
    expect(EmergencyService.routeFor('Flood or Disaster').key, 'mdrrmo');
    expect(EmergencyService.routeFor('Electrical Hazard').key, 'cebeco');
    expect(EmergencyService.routeFor('Other Emergency').key, 'barangay');
  });
}
