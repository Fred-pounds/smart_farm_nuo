import 'package:flutter/foundation.dart';

import '../data/crop_database.dart';
import '../models/crop.dart';
import '../models/planting.dart';
import '../services/settings_service.dart';

/// Tracks what is actually planted, and turns each planting's growth stage
/// into dated tasks.
class PlantingProvider extends ChangeNotifier {
  final SettingsService _settings = SettingsService();

  List<Planting> _plantings = const [];
  bool _loaded = false;

  List<Planting> get plantings => _plantings;
  bool get isLoaded => _loaded;
  bool get isEmpty => _loaded && _plantings.isEmpty;

  PlantingProvider() {
    _load();
  }

  Future<void> _load() async {
    final raw = await _settings.loadPlantings();
    _plantings =
        raw
            .map((json) {
              try {
                return Planting.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<Planting>()
            .toList()
          ..sort((a, b) => b.plantedOn.compareTo(a.plantedOn));
    _loaded = true;
    notifyListeners();
  }

  Future<void> add({
    required String cropId,
    required String fieldName,
    required DateTime plantedOn,
    required double areaSqm,
    String? notes,
  }) async {
    final planting = Planting(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      cropId: cropId,
      fieldName: fieldName,
      plantedOn: plantedOn,
      areaSqm: areaSqm,
      notes: notes,
    );

    _plantings = [planting, ..._plantings];
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _plantings = _plantings.where((p) => p.id != id).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() =>
      _settings.savePlantings(_plantings.map((p) => p.toJson()).toList());

  Crop? cropFor(Planting planting) => CropDatabase.byId(planting.cropId);

  GrowthStage? stageFor(Planting planting) =>
      cropFor(planting)?.stageForDay(planting.daysSincePlanting);

  /// Total planted area across all active plantings, used as the default
  /// field area for water estimates.
  double get totalAreaSqm => _plantings.fold(0.0, (sum, p) => sum + p.areaSqm);

  /// Builds the task list from every planting's current and next stage.
  ///
  /// Tasks in the current stage are dated to the stage's midpoint; tasks in
  /// the next stage are dated to when that stage begins. Sorted soonest first.
  List<FarmTask> get tasks {
    final result = <FarmTask>[];

    for (final planting in _plantings) {
      final crop = cropFor(planting);
      if (crop == null) continue;

      final day = planting.daysSincePlanting;
      final current = crop.stageForDay(day);
      if (current == null) continue;

      final currentIndex = crop.stages.indexOf(current);
      final upcoming =
          currentIndex >= 0 && currentIndex < crop.stages.length - 1
          ? crop.stages[currentIndex + 1]
          : null;

      for (final task in current.tasks) {
        final midpoint = ((current.startDay + current.endDay) / 2).round();
        result.add(
          FarmTask(
            plantingId: planting.id,
            cropName: crop.name,
            cropEmoji: crop.emoji,
            fieldName: planting.fieldName,
            title: task,
            stageName: current.name,
            dueDate: planting.plantedOn.add(Duration(days: midpoint)),
          ),
        );
      }

      if (upcoming != null) {
        for (final task in upcoming.tasks) {
          result.add(
            FarmTask(
              plantingId: planting.id,
              cropName: crop.name,
              cropEmoji: crop.emoji,
              fieldName: planting.fieldName,
              title: task,
              stageName: upcoming.name,
              dueDate: planting.plantedOn.add(
                Duration(days: upcoming.startDay),
              ),
            ),
          );
        }
      }
    }

    result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  /// Tasks that are overdue or due within the next week.
  List<FarmTask> get urgentTasks =>
      tasks.where((t) => t.daysUntilDue <= 7).toList();
}
