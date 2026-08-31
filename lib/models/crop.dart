// A crop in the knowledge base, with the agronomic envelope the recommender
// scores live conditions against.

enum WaterNeed { low, moderate, high }

enum SunNeed { fullSun, partialShade }

class GrowthStage {
  final String name;

  /// Day the stage starts, counted from planting.
  final int startDay;
  final int endDay;
  final String focus;
  final List<String> tasks;

  const GrowthStage({
    required this.name,
    required this.startDay,
    required this.endDay,
    required this.focus,
    required this.tasks,
  });

  bool contains(int dayFromPlanting) =>
      dayFromPlanting >= startDay && dayFromPlanting <= endDay;
}

class Crop {
  final String id;
  final String name;
  final String emoji;
  final String category;

  /// Temperature band the crop will survive in, and the narrower band where
  /// it actually thrives.
  final double minTempC;
  final double maxTempC;
  final double optimalMinTempC;
  final double optimalMaxTempC;

  /// Rainfall the crop wants across a full season, in mm.
  final int seasonalRainfallMm;
  final WaterNeed waterNeed;
  final SunNeed sunNeed;

  /// Raw capacitive-sensor reading (higher = drier) at which this crop should
  /// be watered. Written to `/farm/threshold` when the user applies a preset.
  final int recommendedThreshold;

  final double minSoilPh;
  final double maxSoilPh;
  final String soilType;

  final int daysToHarvest;

  /// Months (1-12) when planting is advised. Tuned for the West African
  /// major (Mar–Jul) and minor (Sep–Nov) rainy seasons.
  final List<int> plantingMonths;

  final String spacing;
  final String description;
  final List<String> tips;
  final List<String> commonPests;
  final List<GrowthStage> stages;

  const Crop({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.minTempC,
    required this.maxTempC,
    required this.optimalMinTempC,
    required this.optimalMaxTempC,
    required this.seasonalRainfallMm,
    required this.waterNeed,
    required this.sunNeed,
    required this.recommendedThreshold,
    required this.minSoilPh,
    required this.maxSoilPh,
    required this.soilType,
    required this.daysToHarvest,
    required this.plantingMonths,
    required this.spacing,
    required this.description,
    required this.tips,
    required this.commonPests,
    required this.stages,
  });

  String get waterNeedLabel => switch (waterNeed) {
    WaterNeed.low => 'Low water',
    WaterNeed.moderate => 'Moderate water',
    WaterNeed.high => 'High water',
  };

  String get phRange =>
      '${minSoilPh.toStringAsFixed(1)}–${maxSoilPh.toStringAsFixed(1)}';

  String get tempRange =>
      '${optimalMinTempC.round()}–${optimalMaxTempC.round()}°C';

  GrowthStage? stageForDay(int dayFromPlanting) {
    for (final s in stages) {
      if (s.contains(dayFromPlanting)) return s;
    }
    return stages.isEmpty ? null : stages.last;
  }
}

/// A scored recommendation produced by [CropRecommender].
class CropRecommendation {
  final Crop crop;

  /// 0–100 suitability against current conditions.
  final int score;

  /// Human-readable reasons the score came out where it did.
  final List<String> positives;
  final List<String> concerns;

  const CropRecommendation({
    required this.crop,
    required this.score,
    required this.positives,
    required this.concerns,
  });

  String get verdict => switch (score) {
    >= 80 => 'Excellent match',
    >= 65 => 'Good match',
    >= 45 => 'Possible',
    _ => 'Not advised now',
  };
}
