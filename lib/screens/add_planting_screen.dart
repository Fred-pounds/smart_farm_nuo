import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/crop_database.dart';
import '../models/crop.dart';
import '../providers/planting_provider.dart';
import '../theme/theme.dart';

/// Logs a new planting: which crop, where, when, and how big.
class AddPlantingScreen extends StatefulWidget {
  final String? preselectedCropId;

  const AddPlantingScreen({super.key, this.preselectedCropId});

  @override
  State<AddPlantingScreen> createState() => _AddPlantingScreenState();
}

class _AddPlantingScreenState extends State<AddPlantingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fieldController = TextEditingController(text: 'Field 1');
  final _areaController = TextEditingController(text: '100');
  final _notesController = TextEditingController();

  String? _cropId;
  DateTime _plantedOn = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cropId = widget.preselectedCropId;
  }

  @override
  void dispose() {
    _fieldController.dispose();
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final crop = _cropId == null ? null : CropDatabase.byId(_cropId!);

    return GlassScaffold(
      title: 'Log a planting',
      insideShell: false,
      builder: (context, contentPadding) => Form(
        key: _formKey,
        child: ListView(
          padding: contentPadding,
          children: [
            Text(
              'Crop',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _cropId,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select a crop',
                prefixIcon: Icon(Icons.eco_outlined),
              ),
              items: CropDatabase.crops
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.emoji}  ${c.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _cropId = value),
              validator: (value) =>
                  value == null ? 'Choose which crop you planted' : null,
            ),
            if (crop != null) ...[
              const SizedBox(height: 10),
              _CropHint(crop: crop, plantedOn: _plantedOn),
            ],
            const SizedBox(height: 22),
            Text(
              'Where and when',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _fieldController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Field or plot name',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give this plot a name'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _areaController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Area',
                suffixText: 'm²',
                prefixIcon: Icon(Icons.square_foot_outlined),
                helperText: 'Used to estimate water use and yield',
              ),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter the plot area in square metres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Planting date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  DateFormat('d MMMM yyyy').format(_plantedOn),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Variety, seed source, fertiliser applied…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save planting'),
            ),
            const SizedBox(height: 12),
            Text(
              'Plantings are stored on this device and drive your task '
              'schedule and harvest countdown.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantedOn,
      firstDate: now.subtract(const Duration(days: 400)),
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'When was this planted?',
    );
    if (picked != null) setState(() => _plantedOn = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    await context.read<PlantingProvider>().add(
      cropId: _cropId!,
      fieldName: _fieldController.text.trim(),
      plantedOn: _plantedOn,
      areaSqm: double.parse(_areaController.text),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${CropDatabase.byId(_cropId!)?.name ?? "Crop"} added to your farm',
        ),
      ),
    );
  }
}

/// Immediate feedback on the chosen crop: harvest date, and whether this is a
/// sensible month to be planting it.
class _CropHint extends StatelessWidget {
  final Crop crop;
  final DateTime plantedOn;

  const _CropHint({required this.crop, required this.plantedOn});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final inSeason = crop.plantingMonths.contains(plantedOn.month);
    final harvest = plantedOn.add(Duration(days: crop.daysToHarvest));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (inSeason ? colors.success : colors.warning).withValues(
          alpha: 0.09,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            inSeason ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            size: 16,
            color: inSeason ? colors.success : colors.warning,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              inSeason
                  ? '${DateFormat('MMMM').format(plantedOn)} is a good month '
                        'for ${crop.name}. Expect harvest around '
                        '${DateFormat('d MMM yyyy').format(harvest)}.'
                  : '${DateFormat('MMMM').format(plantedOn)} is outside the '
                        'usual window for ${crop.name}. Harvest would land '
                        'around ${DateFormat('d MMM yyyy').format(harvest)}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: inSeason ? colors.growth : colors.sun,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
