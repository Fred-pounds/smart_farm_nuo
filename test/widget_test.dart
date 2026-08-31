import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/data/crop_database.dart';
import 'package:smart_farm/data/disease_database.dart';

void main() {
  group('CropDatabase', () {
    test('every crop has a unique id', () {
      final ids = CropDatabase.crops.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('byId resolves known crops and rejects unknown ones', () {
      expect(CropDatabase.byId('maize')?.name, 'Maize');
      expect(CropDatabase.byId('not_a_crop'), isNull);
    });

    test('growth stages cover day 0 through harvest without gaps', () {
      for (final crop in CropDatabase.crops) {
        expect(crop.stages, isNotEmpty, reason: '${crop.name} has no stages');
        expect(
          crop.stages.first.startDay,
          0,
          reason: '${crop.name} does not start at day 0',
        );

        for (var i = 0; i < crop.stages.length - 1; i++) {
          expect(
            crop.stages[i + 1].startDay,
            crop.stages[i].endDay + 1,
            reason:
                '${crop.name} has a gap or overlap after '
                '"${crop.stages[i].name}"',
          );
        }

        // The harvest date must land inside a defined stage, or the planting
        // tracker would show no stage at harvest time.
        expect(
          crop.stageForDay(crop.daysToHarvest),
          isNotNull,
          reason: '${crop.name} has no stage at day ${crop.daysToHarvest}',
        );
      }
    });

    test('agronomic bands are internally consistent', () {
      for (final crop in CropDatabase.crops) {
        expect(
          crop.minTempC,
          lessThan(crop.optimalMinTempC),
          reason: '${crop.name} temperature band',
        );
        expect(
          crop.optimalMinTempC,
          lessThan(crop.optimalMaxTempC),
          reason: '${crop.name} optimal band',
        );
        expect(
          crop.optimalMaxTempC,
          lessThan(crop.maxTempC),
          reason: '${crop.name} temperature band',
        );
        expect(
          crop.minSoilPh,
          lessThan(crop.maxSoilPh),
          reason: '${crop.name} pH band',
        );
        expect(
          crop.plantingMonths,
          isNotEmpty,
          reason: '${crop.name} has no planting months',
        );
        expect(
          crop.plantingMonths.every((m) => m >= 1 && m <= 12),
          isTrue,
          reason: '${crop.name} has an out-of-range planting month',
        );
      }
    });

    test('recommended thresholds track water need', () {
      // Higher raw reading means drier soil, so thirsty crops must be watered
      // at a lower threshold than drought-tolerant ones.
      final thirstiest = CropDatabase.crops
          .where((c) => c.waterNeed.name == 'high')
          .map((c) => c.recommendedThreshold)
          .reduce((a, b) => a > b ? a : b);
      final hardiest = CropDatabase.crops
          .where((c) => c.waterNeed.name == 'low')
          .map((c) => c.recommendedThreshold)
          .reduce((a, b) => a < b ? a : b);

      expect(thirstiest, lessThan(hardiest));
    });
  });

  group('DiseaseDatabase', () {
    test('known labels resolve to treatment guidance', () {
      final info = DiseaseDatabase.lookup('Tomato___Late_blight');
      expect(info.diseaseName, 'Late Blight');
      expect(info.organicTreatment, isNotEmpty);
      expect(info.isHealthy, isFalse);
    });

    test('healthy labels are flagged as healthy', () {
      expect(DiseaseDatabase.lookup('Tomato___healthy').isHealthy, isTrue);
    });

    // These two use crops deliberately outside the bundled PlantVillage 38.
    // Every one of those 38 is now mapped (see disease_model_test.dart), so a
    // label from the shipped set would exercise the real entry, not the
    // fallback. The fallback still matters: swap in a wider model and this is
    // what its extra classes land on.
    test('unmapped labels degrade to a parsed placeholder', () {
      final info = DiseaseDatabase.lookup('Mango___Anthracnose');
      expect(info.cropName, 'Mango');
      expect(info.diseaseName, 'Anthracnose');
      expect(info.organicTreatment, isEmpty);
      expect(info.isHealthy, isFalse);
    });

    test('unmapped healthy labels are still recognised as healthy', () {
      final info = DiseaseDatabase.lookup('Cassava___healthy');
      expect(info.cropName, 'Cassava');
      expect(info.isHealthy, isTrue);
    });
  });
}
