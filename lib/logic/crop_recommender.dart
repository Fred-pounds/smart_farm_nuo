import '../data/crop_database.dart';
import '../models/crop.dart';
import '../models/weather.dart';

/// Scores every crop in [CropDatabase] against live farm conditions.
///
/// The score is a weighted sum of four independent fits, so a crop can lose
/// points on season while still ranking well on climate — and the reasons
/// surfaced to the user explain exactly where the points went.
class CropRecommender {
  const CropRecommender._();

  static const int _tempWeight = 40;
  static const int _seasonWeight = 25;
  static const int _soilWeight = 20;
  static const int _rainWeight = 15;

  static List<CropRecommendation> recommend({
    required int soilMoistureRaw,
    WeatherReport? weather,
    DateTime? now,
    List<Crop>? crops,
  }) {
    final today = now ?? DateTime.now();
    final avgTempC = weather?.averageMaxTempNext7Days ?? 28.0;
    final rain7dMm = weather?.totalRainfallNext7Days ?? 0.0;
    final hasWeather = weather != null;

    final results = (crops ?? CropDatabase.crops)
        .map(
          (crop) => _score(
            crop: crop,
            soilMoistureRaw: soilMoistureRaw,
            avgTempC: avgTempC,
            rain7dMm: rain7dMm,
            month: today.month,
            hasWeather: hasWeather,
          ),
        )
        .toList();

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  static CropRecommendation _score({
    required Crop crop,
    required int soilMoistureRaw,
    required double avgTempC,
    required double rain7dMm,
    required int month,
    required bool hasWeather,
  }) {
    final positives = <String>[];
    final concerns = <String>[];
    var total = 0;

    // --- Temperature -------------------------------------------------------
    if (avgTempC >= crop.optimalMinTempC && avgTempC <= crop.optimalMaxTempC) {
      total += _tempWeight;
      positives.add(
        'Temperature (${avgTempC.round()}°C) is in the ideal ${crop.tempRange} band',
      );
    } else if (avgTempC >= crop.minTempC && avgTempC <= crop.maxTempC) {
      // Linear falloff from the edge of optimal to the edge of survivable.
      final distance = avgTempC < crop.optimalMinTempC
          ? crop.optimalMinTempC - avgTempC
          : avgTempC - crop.optimalMaxTempC;
      final headroom = avgTempC < crop.optimalMinTempC
          ? (crop.optimalMinTempC - crop.minTempC)
          : (crop.maxTempC - crop.optimalMaxTempC);
      final fit = headroom <= 0
          ? 0.0
          : (1 - distance / headroom).clamp(0.0, 1.0);
      total += (_tempWeight * fit).round();
      concerns.add(
        avgTempC < crop.optimalMinTempC
            ? 'A little cool at ${avgTempC.round()}°C — growth will be slower'
            : 'A little hot at ${avgTempC.round()}°C — expect some heat stress',
      );
    } else {
      concerns.add(
        avgTempC > crop.maxTempC
            ? 'Too hot — ${avgTempC.round()}°C exceeds the ${crop.maxTempC.round()}°C limit'
            : 'Too cold — ${avgTempC.round()}°C is below the ${crop.minTempC.round()}°C minimum',
      );
    }

    // --- Planting season ---------------------------------------------------
    if (crop.plantingMonths.contains(month)) {
      total += _seasonWeight;
      positives.add(
        '${_monthName(month)} is inside the recommended planting window',
      );
    } else if (crop.plantingMonths.contains(_shift(month, -1)) ||
        crop.plantingMonths.contains(_shift(month, 1))) {
      total += (_seasonWeight * 0.6).round();
      concerns.add('Just outside the ideal planting window — plant soon');
    } else {
      concerns.add(
        'Out of season — best planted in ${crop.plantingMonths.map(_monthName).join(", ")}',
      );
    }

    // --- Current soil moisture --------------------------------------------
    // Higher raw reading = drier soil, so the gap is signed: positive means
    // the soil is drier than this crop wants.
    final gap = soilMoistureRaw - crop.recommendedThreshold;
    if (soilMoistureRaw <= 0) {
      total += (_soilWeight * 0.5).round();
      concerns.add('No soil reading yet — moisture fit not assessed');
    } else if (gap.abs() <= 300) {
      total += _soilWeight;
      positives.add('Current soil moisture matches this crop closely');
    } else if (gap.abs() <= 700) {
      total += (_soilWeight * 0.6).round();
      concerns.add(
        gap > 0
            ? 'Soil is drier than ideal — plan to irrigate more often'
            : 'Soil is wetter than ideal — make sure drainage is good',
      );
    } else {
      total += (_soilWeight * 0.2).round();
      concerns.add(
        gap > 0
            ? 'Soil is much drier than this crop wants — needs heavy irrigation'
            : 'Soil is much wetter than this crop wants — risk of root rot',
      );
    }

    // --- Rainfall ----------------------------------------------------------
    if (!hasWeather) {
      total += (_rainWeight * 0.5).round();
    } else {
      // Rainfall the crop wants per week, spread across its full season.
      final weeksInSeason = crop.daysToHarvest / 7;
      final weeklyNeedMm = crop.seasonalRainfallMm / weeksInSeason;
      final ratio = weeklyNeedMm <= 0 ? 1.0 : rain7dMm / weeklyNeedMm;

      if (ratio >= 0.7 && ratio <= 1.6) {
        total += _rainWeight;
        positives.add(
          'Forecast rain (${rain7dMm.round()} mm this week) covers most of its water need',
        );
      } else if (ratio > 1.6) {
        total += (_rainWeight * 0.5).round();
        concerns.add(
          'Heavy rain forecast (${rain7dMm.round()} mm) — ensure the field drains',
        );
      } else if (ratio >= 0.3) {
        total += (_rainWeight * 0.6).round();
        concerns.add(
          'Rainfall is short of its needs — irrigation will be required',
        );
      } else {
        total += (_rainWeight * 0.25).round();
        concerns.add(
          crop.waterNeed == WaterNeed.high
              ? 'Very little rain forecast and this is a thirsty crop'
              : 'Little rain forecast — irrigation will do most of the work',
        );
      }
    }

    // Drought-tolerant crops get credit when conditions are dry, since that is
    // precisely when they are the smart choice.
    if (crop.waterNeed == WaterNeed.low && rain7dMm < 15 && hasWeather) {
      positives.add('Drought-tolerant — a safe pick in these dry conditions');
    }

    return CropRecommendation(
      crop: crop,
      score: total.clamp(0, 100),
      positives: positives,
      concerns: concerns,
    );
  }

  static int _shift(int month, int delta) {
    final m = (month + delta - 1) % 12;
    return (m < 0 ? m + 12 : m) + 1;
  }

  static String _monthName(int m) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][(m - 1).clamp(0, 11)];
}
