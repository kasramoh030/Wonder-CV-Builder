import 'package:flutter/material.dart';

import '../../core/widgets/under_construction.dart';
import '../../l10n/app_localizations.dart';

/// CV analysis report: scores, ATS checks and prioritised recommendations.
class AnalyserScreen extends StatelessWidget {
  const AnalyserScreen({required this.resumeId, super.key});

  final String resumeId;

  @override
  Widget build(BuildContext context) => UnderConstruction(
        title: AppLocalizations.of(context).analyzerTitle,
        subtitle: resumeId,
      );
}
