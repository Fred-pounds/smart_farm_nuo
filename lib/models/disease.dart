// Crop disease detection: the label the TFLite model emits, and everything
// we know about how to treat it.

enum DiseaseSeverity { healthy, low, moderate, high }

class DiseaseInfo {
  /// Matches the raw label in `assets/models/labels.txt`, e.g.
  /// `Tomato___Late_blight`.
  final String label;
  final String cropName;
  final String diseaseName;
  final DiseaseSeverity severity;
  final String description;
  final List<String> symptoms;
  final List<String> organicTreatment;
  final List<String> chemicalTreatment;
  final List<String> prevention;

  const DiseaseInfo({
    required this.label,
    required this.cropName,
    required this.diseaseName,
    required this.severity,
    required this.description,
    required this.symptoms,
    required this.organicTreatment,
    required this.chemicalTreatment,
    required this.prevention,
  });

  bool get isHealthy => severity == DiseaseSeverity.healthy;

  String get severityLabel => switch (severity) {
    DiseaseSeverity.healthy => 'Healthy',
    DiseaseSeverity.low => 'Low risk',
    DiseaseSeverity.moderate => 'Needs attention',
    DiseaseSeverity.high => 'Urgent',
  };

  /// Fallback used when the model emits a label we have no entry for — the
  /// label itself is still informative, so we parse it rather than fail.
  factory DiseaseInfo.unknown(String label) {
    final parts = label.split('___');
    final crop = parts.first.replaceAll('_', ' ').trim();
    final disease = parts.length > 1
        ? parts[1].replaceAll('_', ' ').trim()
        : 'Unrecognised condition';
    final healthy = disease.toLowerCase().contains('healthy');

    return DiseaseInfo(
      label: label,
      cropName: crop.isEmpty ? 'Unknown crop' : crop,
      diseaseName: disease,
      severity: healthy ? DiseaseSeverity.healthy : DiseaseSeverity.moderate,
      description: healthy
          ? 'No disease detected on this leaf.'
          : 'This condition is not yet in the local treatment database. '
                'Consult an extension officer before applying any chemical.',
      symptoms: const [],
      organicTreatment: const [],
      chemicalTreatment: const [],
      prevention: const [],
    );
  }
}

/// One class returned by the classifier, with its confidence.
class DiagnosisCandidate {
  final DiseaseInfo info;

  /// Softmax confidence, 0–1.
  final double confidence;

  const DiagnosisCandidate({required this.info, required this.confidence});

  int get confidencePercent => (confidence * 100).round();
}

class DiagnosisResult {
  final String imagePath;
  final List<DiagnosisCandidate> candidates;
  final DateTime diagnosedAt;
  final Duration inferenceTime;

  const DiagnosisResult({
    required this.imagePath,
    required this.candidates,
    required this.diagnosedAt,
    required this.inferenceTime,
  });

  DiagnosisCandidate get top => candidates.first;

  /// Below this the model is essentially guessing — the UI warns instead of
  /// presenting a confident diagnosis.
  static const double confidenceFloor = 0.55;

  bool get isConfident => top.confidence >= confidenceFloor;
}

/// Thrown when the model asset is missing or fails to load, so the UI can
/// show setup instructions rather than a raw stack trace.
class ModelNotAvailableException implements Exception {
  final String message;
  const ModelNotAvailableException(this.message);

  @override
  String toString() => message;
}
