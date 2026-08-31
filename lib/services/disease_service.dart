import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../data/disease_database.dart';
import '../models/disease.dart';

/// How pixel values must be scaled before they reach the model.
///
/// This is a property of how the model was *trained*, and a `.tflite` file
/// does not record it — only the input shape and dtype, which are identical
/// across all three options below. So it cannot be inferred and must be
/// declared in `model_config.json`.
///
/// It matters more than it looks. Measured on the bundled classifier against
/// 228 held-out labelled PlantVillage images:
///
/// | Scaling | Top-1 |
/// |---|---|
/// | `raw255` (correct for this model) | 98.2% |
/// | `unit` | 3.1% |
/// | `signed` | 3.1% |
///
/// Chance is 2.6% over 38 classes. A wrong choice does not throw — it returns
/// a confident, wrong diagnosis, which is the worst failure this app has.
enum InputScaling {
  /// Pixels stay 0–255. Correct for models carrying their own `Rescaling`
  /// layer, which is the Keras default when you build one in.
  raw255,

  /// Pixels mapped to 0–1.
  unit,

  /// Pixels mapped to -1–1. The classic `mobilenet.preprocess_input`.
  signed;

  static InputScaling? parse(String raw) => switch (raw.trim()) {
    'raw255' => raw255,
    'unit' => unit,
    'signed' => signed,
    _ => null,
  };

  /// Applies the scaling to one 0–255 channel value.
  double apply(num channel) => switch (this) {
    raw255 => channel.toDouble(),
    unit => channel / 255.0,
    signed => channel / 127.5 - 1.0,
  };
}

/// On-device crop disease classifier.
///
/// Loads a TensorFlow Lite image-classification model from
/// `assets/models/plant_disease.tflite` with class names in
/// `assets/models/labels.txt` (one per line, in the model's output order) and
/// its pixel scaling from `assets/models/model_config.json`.
///
/// Input shape, input type and class count are all read from the model at
/// load time, so any standard PlantVillage-style classifier drops in without
/// code changes — float32 or uint8-quantised. Scaling is the one thing the
/// file cannot tell us; see [InputScaling].
class DiseaseService {
  static final DiseaseService _instance = DiseaseService._internal();
  factory DiseaseService() => _instance;
  DiseaseService._internal();

  static const String modelAsset = 'assets/models/plant_disease.tflite';
  static const String labelsAsset = 'assets/models/labels.txt';
  static const String configAsset = 'assets/models/model_config.json';

  /// How many ranked guesses to return.
  static const int topK = 3;

  Interpreter? _interpreter;
  List<String> _labels = const [];
  int _inputWidth = 224;
  int _inputHeight = 224;
  bool _quantizedInput = false;
  InputScaling _scaling = InputScaling.raw255;
  String? _loadError;

  bool get isReady => _interpreter != null;
  String? get loadError => _loadError;
  List<String> get labels => _labels;
  String get inputDescription => '$_inputWidth × $_inputHeight';

  /// Loads the model. Safe to call repeatedly — only the first call does work.
  ///
  /// Returns false (rather than throwing) when the asset is absent, so the UI
  /// can show setup instructions.
  Future<bool> load() async {
    if (_interpreter != null) return true;

    try {
      _labels = await _loadLabels();
      _scaling = await _loadScaling();

      final interpreter = await Interpreter.fromAsset(
        modelAsset,
        options: InterpreterOptions()..threads = 2,
      );

      final inputTensor = interpreter.getInputTensor(0);
      final shape = inputTensor.shape;
      if (shape.length != 4 || shape[3] != 3) {
        interpreter.close();
        throw ModelNotAvailableException(
          'Unsupported model input shape $shape. Expected [1, height, width, 3].',
        );
      }

      _inputHeight = shape[1];
      _inputWidth = shape[2];
      _quantizedInput = inputTensor.type == TensorType.uint8;

      final outputClasses = interpreter.getOutputTensor(0).shape.last;
      if (_labels.length != outputClasses) {
        interpreter.close();
        throw ModelNotAvailableException(
          'Model outputs $outputClasses classes but labels.txt has '
          '${_labels.length} lines. They must match.',
        );
      }

      _interpreter = interpreter;
      _loadError = null;
      return true;
    } on ModelNotAvailableException catch (e) {
      _loadError = e.message;
      return false;
    } catch (e) {
      _loadError = 'Could not load the disease model.\n\n$e';
      return false;
    }
  }

  /// Reads the declared pixel scaling.
  ///
  /// A missing config file is not fatal — a model dropped in by hand should
  /// still run — but an unreadable or unrecognised *value* is. Silently
  /// guessing here is how you get a diagnosis that is wrong at 99%
  /// confidence, so a bad declaration fails loudly instead.
  Future<InputScaling> _loadScaling() async {
    final String raw;
    try {
      raw = await rootBundle.loadString(configAsset);
    } catch (_) {
      return InputScaling.raw255;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      throw ModelNotAvailableException('model_config.json is not valid JSON.');
    }

    if (decoded is! Map || !decoded.containsKey('inputScaling')) {
      return InputScaling.raw255;
    }

    final parsed = InputScaling.parse('${decoded['inputScaling']}');
    if (parsed == null) {
      throw ModelNotAvailableException(
        'model_config.json sets inputScaling to "${decoded['inputScaling']}", '
        'which is not one of: '
        '${InputScaling.values.map((s) => s.name).join(', ')}.',
      );
    }
    return parsed;
  }

  Future<List<String>> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString(labelsAsset);
      final labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (labels.isEmpty) {
        throw const ModelNotAvailableException('labels.txt is empty.');
      }
      return labels;
    } on ModelNotAvailableException {
      rethrow;
    } catch (_) {
      throw const ModelNotAvailableException(
        'No model installed yet.\n\n'
        'Add a TensorFlow Lite plant-disease classifier at\n'
        'assets/models/plant_disease.tflite\n'
        'and its class names at assets/models/labels.txt',
      );
    }
  }

  /// Classifies a leaf photo and returns the top [topK] candidates with
  /// treatment guidance attached.
  Future<DiagnosisResult> diagnose(File imageFile) async {
    if (!await load()) {
      throw ModelNotAvailableException(
        _loadError ?? 'Disease model is not available.',
      );
    }

    final stopwatch = Stopwatch()..start();

    final decoded = img.decodeImage(await imageFile.readAsBytes());
    if (decoded == null) {
      throw const ModelNotAvailableException(
        'That image could not be read. Try taking the photo again.',
      );
    }

    final resized = img.copyResize(
      decoded,
      width: _inputWidth,
      height: _inputHeight,
      interpolation: img.Interpolation.linear,
    );

    final input = _buildInput(resized);
    final scores = _runInference(input);

    stopwatch.stop();

    final ranked = List.generate(
      scores.length,
      (i) => (index: i, score: scores[i]),
    )..sort((a, b) => b.score.compareTo(a.score));

    final candidates = ranked.take(topK).map((entry) {
      final label = entry.index < _labels.length
          ? _labels[entry.index]
          : 'class_${entry.index}';
      return DiagnosisCandidate(
        info: DiseaseDatabase.lookup(label),
        confidence: entry.score,
      );
    }).toList();

    return DiagnosisResult(
      imagePath: imageFile.path,
      candidates: candidates,
      diagnosedAt: DateTime.now(),
      inferenceTime: stopwatch.elapsed,
    );
  }

  /// Builds the [1, h, w, 3] tensor, matching the model's expected numeric
  /// type and its declared [InputScaling].
  ///
  /// A uint8-quantised input takes raw bytes: the scaling is baked into the
  /// tensor's own quantisation parameters, so applying it again here would
  /// double-scale it.
  Object _buildInput(img.Image image) {
    if (_quantizedInput) {
      return [
        List.generate(
          _inputHeight,
          (y) => List.generate(_inputWidth, (x) {
            final p = image.getPixel(x, y);
            return [p.r.toInt(), p.g.toInt(), p.b.toInt()];
          }),
        ),
      ];
    }

    return [
      List.generate(
        _inputHeight,
        (y) => List.generate(_inputWidth, (x) {
          final p = image.getPixel(x, y);
          return [
            _scaling.apply(p.r),
            _scaling.apply(p.g),
            _scaling.apply(p.b),
          ];
        }),
      ),
    ];
  }

  List<double> _runInference(Object input) {
    final interpreter = _interpreter!;
    final outputTensor = interpreter.getOutputTensor(0);
    final classCount = outputTensor.shape.last;
    final quantizedOutput = outputTensor.type == TensorType.uint8;

    if (quantizedOutput) {
      final output = [List.filled(classCount, 0)];
      interpreter.run(input, output);
      // Quantised classifiers emit 0–255; rescaling is enough to rank and to
      // read as a confidence.
      final raw = output.first.map((v) => v / 255.0).toList();
      return _normalize(raw);
    }

    final output = [List.filled(classCount, 0.0)];
    interpreter.run(input, output);
    return _normalize(output.first.cast<double>());
  }

  /// Models vary in whether they include a softmax layer. If the vector is
  /// already a distribution we leave it alone; otherwise we apply softmax.
  List<double> _normalize(List<double> scores) {
    if (scores.isEmpty) return scores;

    final sum = scores.fold(0.0, (a, b) => a + b);
    final hasNegative = scores.any((s) => s < 0);
    final looksLikeDistribution = !hasNegative && (sum - 1.0).abs() < 0.05;

    if (looksLikeDistribution) return scores;

    if (!hasNegative && sum > 0) {
      return scores.map((s) => s / sum).toList();
    }

    final maxScore = scores.reduce(math.max);
    final exps = scores.map((s) => math.exp(s - maxScore)).toList();
    final expSum = exps.fold(0.0, (a, b) => a + b);
    return exps.map((e) => e / expSum).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
