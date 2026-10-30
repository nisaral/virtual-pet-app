import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_pet_app/vale/models.dart';

void main() {
  test('the glen has three original kin with glb models', () {
    expect(SpeciesCatalog.all.map((species) => species.name), ['Pipkin', 'Marrow', 'Solbit']);
    expect(kinGlb(SpeciesId.pipkin), 'assets/models/sproutkit.glb');
    expect(kinGlb(SpeciesId.marrow), 'assets/models/aquapup.glb');
    expect(kinGlb(SpeciesId.solbit), 'assets/models/embercub.glb');
    expect(clipForPose(KinPose.eat), 'Eat');
    expect(clipForPose(KinPose.sleep), 'Sleep');
  });
}
