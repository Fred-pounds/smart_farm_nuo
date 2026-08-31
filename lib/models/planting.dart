// A crop the user has actually planted, tracked from sowing to harvest.

class Planting {
  final String id;
  final String cropId;
  final String fieldName;
  final DateTime plantedOn;
  final double areaSqm;
  final String? notes;

  const Planting({
    required this.id,
    required this.cropId,
    required this.fieldName,
    required this.plantedOn,
    required this.areaSqm,
    this.notes,
  });

  int get daysSincePlanting =>
      DateTime.now().difference(plantedOn).inDays.clamp(0, 100000);

  DateTime harvestDateFor(int daysToHarvest) =>
      plantedOn.add(Duration(days: daysToHarvest));

  int daysToHarvestFrom(int daysToHarvest) => daysToHarvest - daysSincePlanting;

  double progressFor(int daysToHarvest) => daysToHarvest == 0
      ? 0
      : (daysSincePlanting / daysToHarvest).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'cropId': cropId,
    'fieldName': fieldName,
    'plantedOn': plantedOn.toIso8601String(),
    'areaSqm': areaSqm,
    'notes': notes,
  };

  factory Planting.fromJson(Map<String, dynamic> json) => Planting(
    id: json['id'] as String,
    cropId: json['cropId'] as String,
    fieldName: json['fieldName'] as String? ?? 'Field 1',
    plantedOn: DateTime.parse(json['plantedOn'] as String),
    areaSqm: (json['areaSqm'] as num?)?.toDouble() ?? 100,
    notes: json['notes'] as String?,
  );
}

/// A dated task derived from a planting's current growth stage.
class FarmTask {
  final String plantingId;
  final String cropName;
  final String cropEmoji;
  final String fieldName;
  final String title;
  final String stageName;
  final DateTime dueDate;

  const FarmTask({
    required this.plantingId,
    required this.cropName,
    required this.cropEmoji,
    required this.fieldName,
    required this.title,
    required this.stageName,
    required this.dueDate,
  });

  int get daysUntilDue {
    final today = DateTime.now();
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return due.difference(now).inDays;
  }

  bool get isOverdue => daysUntilDue < 0;
  bool get isDueToday => daysUntilDue == 0;
}
