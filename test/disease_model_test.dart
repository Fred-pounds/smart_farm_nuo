import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/data/disease_database.dart';
import 'package:smart_farm/services/disease_service.dart';

/// Guards the contract between three files that must agree but have no
/// compiler relationship: the bundled `.tflite`, `labels.txt`, and the
/// treatment database.
///
/// Every failure mode below is silent at runtime — the app keeps working and
/// simply gives the wrong answer — which is why they are pinned here.
void main() {
  final labelsFile = File('assets/models/labels.txt');
  final modelFile = File('assets/models/plant_disease.tflite');
  final configFile = File('assets/models/model_config.json');

  List<String> readLabels() => labelsFile
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  group('bundled disease model', () {
    test('model and labels are both present', () {
      expect(
        modelFile.existsSync(),
        isTrue,
        reason: 'assets/models/plant_disease.tflite is missing — the Diagnose '
            'tab falls back to setup instructions without it.',
      );
      expect(labelsFile.existsSync(), isTrue);
    });

    test('labels.txt has the 38 PlantVillage classes the model outputs', () {
      // The interpreter itself checks this at load time and refuses to start
      // on a mismatch. Pinning the number here catches an edited labels file
      // before it ships rather than on the farmer's phone.
      expect(readLabels(), hasLength(38));
    });

    test('labels are unique', () {
      final labels = readLabels();
      expect(labels.toSet(), hasLength(labels.length));
    });

    test('every label resolves to real treatment guidance', () {
      // DiseaseDatabase.lookup never throws — an unmapped label degrades to a
      // parsed placeholder with empty advice. That is the right runtime
      // behaviour and the wrong thing to ship, so assert real coverage.
      final unmapped = <String>[];
      for (final label in readLabels()) {
        final info = DiseaseDatabase.lookup(label);
        final hasAdvice = info.isHealthy
            ? info.prevention.isNotEmpty
            : info.symptoms.isNotEmpty &&
                  info.prevention.isNotEmpty &&
                  (info.organicTreatment.isNotEmpty ||
                      info.chemicalTreatment.isNotEmpty);
        if (!hasAdvice) unmapped.add(label);
      }
      expect(
        unmapped,
        isEmpty,
        reason: 'These classes the model can predict have no guidance: '
            '$unmapped',
      );
    });

    test('label strings match the database keys exactly', () {
      // PlantVillage labels carry trailing underscores and parenthesised
      // names ("Corn_(maize)___Common_rust_"). A single character of drift
      // silently routes the class to the placeholder instead of its entry.
      for (final label in readLabels()) {
        expect(
          DiseaseDatabase.lookup(label).label,
          label,
          reason: '$label does not round-trip through the database',
        );
      }
    });
  });

  group('input scaling', () {
    test('config declares a scaling the app recognises', () {
      final raw = jsonDecode(configFile.readAsStringSync()) as Map;
      final declared = '${raw['inputScaling']}';
      expect(
        InputScaling.parse(declared),
        isNotNull,
        reason: '"$declared" is not a scaling the app knows how to apply',
      );
    });

    test('bundled model is declared raw255', () {
      // Measured, not assumed: raw255 scores 98.2% top-1 on 228 held-out
      // labelled images, unit and signed both score 3.1% against a 2.6%
      // chance baseline. Swapping the model without re-measuring this is how
      // the Diagnose tab starts returning confident nonsense.
      final raw = jsonDecode(configFile.readAsStringSync()) as Map;
      expect(raw['inputScaling'], 'raw255');
    });

    test('each scaling maps the 0-255 range as documented', () {
      expect(InputScaling.raw255.apply(0), 0);
      expect(InputScaling.raw255.apply(255), 255);

      expect(InputScaling.unit.apply(0), 0);
      expect(InputScaling.unit.apply(255), 1.0);

      expect(InputScaling.signed.apply(0), -1.0);
      expect(InputScaling.signed.apply(255), closeTo(1.0, 1e-9));
    });

    test('unrecognised scaling names are rejected rather than defaulted', () {
      expect(InputScaling.parse('imagenet'), isNull);
      expect(InputScaling.parse(''), isNull);
    });
  });
}
