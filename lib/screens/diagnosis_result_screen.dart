import 'dart:io';

import 'package:flutter/material.dart';

import '../models/disease.dart';
import '../theme/theme.dart';

/// Presents the classifier output as an actionable diagnosis: what it is, how
/// sure the model is, and what to do about it.
///
/// The ordering is deliberate and is the whole design of the screen. The
/// photograph is first, so the farmer can see the model looked at the right
/// leaf. The verdict and its confidence are second, together — a disease name
/// without a confidence figure invites a farmer to spend money on a guess.
/// Treatment comes after that, organic before chemical, because the cheaper
/// and safer option should be the one read first.
class DiagnosisResultScreen extends StatelessWidget {
  final DiagnosisResult result;

  const DiagnosisResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final info = result.top.info;
    final colors = context.farmColors;

    return GlassScaffold(
      title: 'Diagnosis',
      subtitle: '${info.cropName} · ${info.diseaseName}',
      insideShell: false,
      builder: (context, contentPadding) => ListView(
        padding: contentPadding,
        children: [
          FadeSlideIn(index: 0, child: _ImagePreview(path: result.imagePath)),
          const SizedBox(height: Tokens.space3),
          FadeSlideIn(index: 1, child: _Verdict(result: result)),

          if (!result.isConfident) ...[
            const SizedBox(height: Tokens.space3),
            const FadeSlideIn(index: 2, child: _LowConfidenceWarning()),
          ],

          if (info.symptoms.isNotEmpty) ...[
            const SizedBox(height: Tokens.space3),
            _TreatmentCard(
              title: 'Symptoms to confirm',
              icon: Icons.visibility_rounded,
              color: colors.inkSecondary,
              items: info.symptoms,
            ),
          ],
          if (info.organicTreatment.isNotEmpty) ...[
            const SizedBox(height: Tokens.space3),
            _TreatmentCard(
              title: 'Organic treatment',
              icon: Icons.spa_rounded,
              color: colors.growth,
              items: info.organicTreatment,
            ),
          ],
          if (info.chemicalTreatment.isNotEmpty) ...[
            const SizedBox(height: Tokens.space3),
            _TreatmentCard(
              title: 'Chemical treatment',
              icon: Icons.science_rounded,
              color: colors.water,
              items: info.chemicalTreatment,
              footnote:
                  'Always follow the label rate and the pre-harvest '
                  'interval. Wear protective equipment.',
            ),
          ],
          if (info.prevention.isNotEmpty) ...[
            const SizedBox(height: Tokens.space3),
            _TreatmentCard(
              title: 'Prevent it next season',
              icon: Icons.shield_rounded,
              color: colors.sun,
              items: info.prevention,
            ),
          ],

          const SizedBox(height: Tokens.space3),
          _OtherCandidates(result: result),
          const SizedBox(height: Tokens.space5),
          _Disclaimer(inferenceMs: result.inferenceTime.inMilliseconds),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String path;

  const _ImagePreview({required this.path});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusLg),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => ColoredBox(
            color: colors.panelMuted,
            child: Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: colors.inkTertiary,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The answer: crop, disease, severity, and how sure the model is.
class _Verdict extends StatelessWidget {
  final DiagnosisResult result;

  const _Verdict({required this.result});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final info = result.top.info;

    final accent = switch (info.severity) {
      DiseaseSeverity.healthy => colors.growth,
      DiseaseSeverity.low => colors.soilWet,
      DiseaseSeverity.moderate => colors.sun,
      DiseaseSeverity.high => colors.alert,
    };

    return Panel(
      raised: true,
      accentBorder: accent.withValues(alpha: 0.35),
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  info.isHealthy
                      ? Icons.verified_rounded
                      : Icons.coronavirus_rounded,
                  color: accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: Tokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(info.cropName),
                    const SizedBox(height: 4),
                    Text(
                      info.diseaseName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Tokens.space2),
              StatusPill(label: info.severityLabel, color: accent),
            ],
          ),
          const SizedBox(height: Tokens.space5),

          // Confidence gets its own ring rather than a bar. It is the number
          // that decides whether the farmer acts on the rest of the screen,
          // and a thin progress bar reads as decoration next to a disease
          // name in title type.
          Row(
            children: [
              ScoreRing(
                score: result.top.confidencePercent,
                accent: accent,
                size: 58,
              ),
              const SizedBox(width: Tokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Model confidence',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      result.isConfident
                          ? 'Above the threshold the app treats as reliable.'
                          : 'Below the reliable threshold — see the note '
                                'below.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (info.description.isNotEmpty) ...[
            const SizedBox(height: Tokens.space5),
            Text(
              info.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LowConfidenceWarning extends StatelessWidget {
  const _LowConfidenceWarning();

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return InsightCard(
      headline: 'Treat this as a suggestion',
      detail:
          'Confidence is below '
          '${(DiagnosisResult.confidenceFloor * 100).round()}%. Retake the '
          'photo closer and in better light, and compare the alternatives '
          'lower down before treating anything.',
      accent: colors.sun,
      icon: Icons.warning_rounded,
    );
  }
}

class _TreatmentCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final String? footnote;

  const _TreatmentCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.footnote,
  });

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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: Tokens.space2),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          for (final item in items)
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
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          if (footnote != null)
            PanelWell(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_rounded, size: 14, color: colors.sun),
                  const SizedBox(width: Tokens.space2),
                  Expanded(
                    child: Text(
                      footnote!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The runners-up.
///
/// Shown rather than hidden because a classifier's second guess is often the
/// right one on a marginal photo, and a farmer comparing two candidates
/// against the leaf in their hand is doing better diagnosis than the model.
class _OtherCandidates extends StatelessWidget {
  final DiagnosisResult result;

  const _OtherCandidates({required this.result});

  @override
  Widget build(BuildContext context) {
    final others = result.candidates.skip(1).toList();
    if (others.isEmpty) return const SizedBox.shrink();

    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Other possibilities', style: theme.textTheme.titleMedium),
          const SizedBox(height: Tokens.space4),
          for (final candidate in others)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.info.diseaseName,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          candidate.info.cropName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.inkTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  SizedBox(
                    width: 76,
                    child: MeterBar(
                      value: candidate.confidence,
                      accent: colors.inkTertiary,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${candidate.confidencePercent}%',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkTertiary,
                        fontFeatures: Tokens.tabular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final int inferenceMs;

  const _Disclaimer({required this.inferenceMs});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontSize: 10.5, color: colors.inkTertiary);

    return Column(
      children: [
        Text('Analysed on-device in $inferenceMs ms', style: style),
        const SizedBox(height: 6),
        Text(
          'Image classification is an aid, not a substitute for an extension '
          'officer. Confirm before applying any chemical.',
          textAlign: TextAlign.center,
          style: style,
        ),
      ],
    );
  }
}
