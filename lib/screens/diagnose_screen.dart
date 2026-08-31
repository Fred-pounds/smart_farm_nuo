import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/disease.dart';
import '../services/disease_service.dart';
import '../widgets/scan_animation.dart';
import 'diagnosis_result_screen.dart';
import '../theme/theme.dart';

/// Camera/gallery entry point for on-device disease classification.
///
/// The flow is deliberately three states and no more: **ready** → **scanning**
/// → **result**. The scanning state gets a real animation rather than a
/// spinner because inference on a mid-range phone takes a second or two, and
/// a spinner over that duration reads as a stall — where a scan line moving
/// over the farmer's own photograph reads as work being done on it.
class DiagnoseScreen extends StatefulWidget {
  const DiagnoseScreen({super.key});

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen> {
  final _service = DiseaseService();
  final _picker = ImagePicker();

  bool _modelReady = false;
  bool _checkingModel = true;

  /// The photo currently being classified. Held so the scanning state can
  /// show what is actually being looked at.
  File? _analysing;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final ready = await _service.load();
    if (!mounted) return;
    setState(() {
      _modelReady = ready;
      _checkingModel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Diagnose',
      subtitle: _modelReady ? 'On-device · no internet needed' : null,
      actions: [
        if (_modelReady)
          IconButton(
            tooltip: 'Model info',
            icon: const Icon(Icons.info_outline_rounded, size: 21),
            onPressed: _showModelInfo,
          ),
      ],
      builder: (context, contentPadding) {
        if (_checkingModel) {
          return ListView(
            padding: contentPadding,
            children: const [ChartSkeleton(height: 200)],
          );
        }
        if (_analysing != null) {
          return _ScanningView(photo: _analysing!);
        }
        if (!_modelReady) {
          return _SetupView(
            error: _service.loadError,
            contentPadding: contentPadding,
            onRetry: () {
              setState(() => _checkingModel = true);
              _checkModel();
            },
          );
        }
        return _ReadyView(
          contentPadding: contentPadding,
          onCapture: () => _pick(ImageSource.camera),
          onGallery: () => _pick(ImageSource.gallery),
        );
      },
    );
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        // Downscaling here keeps decode fast; the model resizes to its own
        // input size anyway.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;

      final file = File(picked.path);
      Haptics.success();
      setState(() => _analysing = file);

      final result = await _service.diagnose(file);
      if (!mounted) return;
      setState(() => _analysing = null);
      Haptics.success();

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DiagnosisResultScreen(result: result),
        ),
      );
    } on ModelNotAvailableException catch (e) {
      if (!mounted) return;
      setState(() => _analysing = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _analysing = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not analyse that photo: $e')),
      );
    }
  }

  void _showModelInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Input size: ${_service.inputDescription}'),
            const SizedBox(height: 6),
            Text('Classes: ${_service.labels.length}'),
            const SizedBox(height: 6),
            const Text('Runs entirely on this device — no internet needed.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// The idle state: what this does, and the two ways to start it.
class _ReadyView extends StatelessWidget {
  final EdgeInsets contentPadding;
  final VoidCallback onCapture;
  final VoidCallback onGallery;

  const _ReadyView({
    required this.contentPadding,
    required this.onCapture,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return ListView(
      padding: contentPadding,
      children: [
        FadeSlideIn(
          index: 0,
          child: Panel(
            raised: true,
            padding: const EdgeInsets.fromLTRB(
              Tokens.space5,
              Tokens.space6,
              Tokens.space5,
              Tokens.space5,
            ),
            child: Column(
              children: [
                const FarmIllustration(art: FarmArt.aiScan, size: 168),
                const SizedBox(height: Tokens.space5),
                Text(
                  'Photograph an affected leaf',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: Tokens.space2),
                Text(
                  'The classifier identifies the disease, and the app matches '
                  'it to organic and chemical treatment options.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.inkSecondary,
                  ),
                ),
                const SizedBox(height: Tokens.space6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Haptics.selection();
                      onCapture();
                    },
                    icon: const Icon(Icons.photo_camera_rounded, size: 20),
                    label: const Text('Take a photo'),
                  ),
                ),
                const SizedBox(height: Tokens.space3),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Haptics.selection();
                      onGallery();
                    },
                    icon: const Icon(Icons.photo_library_rounded, size: 20),
                    label: const Text('Choose from gallery'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.space3),
        const FadeSlideIn(index: 1, child: _PhotoTipsCard()),
        const SizedBox(height: Tokens.space3),
        const FadeSlideIn(index: 2, child: _PrivacyNote()),
      ],
    );
  }
}

/// The scanning state.
///
/// Shows the farmer's own photograph under a moving scan line, with the
/// stages of the work named beneath it. Naming the stages matters: "Analysing"
/// alone gives no way to tell a slow model from a hung one.
class _ScanningView extends StatelessWidget {
  final File photo;

  const _ScanningView({required this.photo});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScanFrame(photo: photo, size: 240),
            const SizedBox(height: Tokens.space6),
            Text('Analysing leaf', style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.space2),
            Text(
              'Running on this device. Nothing is uploaded.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkSecondary,
              ),
            ),
            const SizedBox(height: Tokens.space5),
            const ScanStages(),
          ],
        ),
      ),
    );
  }
}

class _PhotoTipsCard extends StatelessWidget {
  const _PhotoTipsCard();

  static const _tips = [
    'Fill the frame with a single leaf — background clutter confuses the model',
    'Shoot in bright, indirect daylight; avoid harsh shadows and flash',
    'Photograph the side showing symptoms, usually the upper surface',
    'Hold steady — a blurred photo produces a low-confidence guess',
    'Take two or three shots of different leaves and compare the results',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                size: 16,
                color: colors.sun,
              ),
              const SizedBox(width: Tokens.space2),
              Text(
                'Getting a good result',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          for (final tip in _tips)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 7, right: Tokens.space3),
                    decoration: BoxDecoration(
                      color: colors.sun,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(tip, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the photo goes, in one line.
///
/// Worth its own row: a farmer being asked to photograph a failing crop is
/// entitled to know whether that picture leaves the phone. It does not.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return PanelWell(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 15, color: colors.growth),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Text(
              'Photos are classified on this phone and never uploaded.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when no model asset is installed, with the exact steps to add one.
class _SetupView extends StatelessWidget {
  final String? error;
  final EdgeInsets contentPadding;
  final VoidCallback onRetry;

  const _SetupView({
    required this.error,
    required this.contentPadding,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return ListView(
      padding: contentPadding,
      children: [
        Panel(
          accentBorder: colors.sun.withValues(alpha: 0.35),
          tinted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IllustrationBanner(
                art: FarmArt.offline,
                accent: colors.sunBright,
                title: 'Model not installed',
                message:
                    error ??
                    'The classifier asset is missing, so disease detection '
                        'is unavailable. Everything else in the app works.',
              ),
              const SizedBox(height: Tokens.space5),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Check again'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space3),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to install a model',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: Tokens.space5),
              const _Step(
                number: 1,
                text:
                    'Get a TensorFlow Lite image classifier trained on '
                    'PlantVillage (or train your own with Teachable Machine '
                    'or Keras).',
              ),
              const _Step(
                number: 2,
                text:
                    'Save the model as '
                    'assets/models/plant_disease.tflite in this project.',
              ),
              const _Step(
                number: 3,
                text:
                    'Save the class names, one per line and in the same '
                    'order the model outputs them, as '
                    'assets/models/labels.txt',
              ),
              const _Step(
                number: 4,
                text:
                    'Rebuild the app. The input size and class count are '
                    'read from the model, so no code changes are needed.',
              ),
              PanelWell(
                child: Text(
                  'Label format: Crop___Disease_Name — for example '
                  'Tomato___Late_blight. The app maps these to its built-in '
                  'treatment guidance.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.water,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.growth.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.growth,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
