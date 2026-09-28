import 'package:flutter/material.dart';

import '../../core/widgets/under_construction.dart';
import '../../l10n/app_localizations.dart';

/// Job advert analysis and CV-to-role matching.
class JobMatchScreen extends StatelessWidget {
  const JobMatchScreen({required this.resumeId, super.key});

  final String resumeId;

  @override
  Widget build(BuildContext context) => UnderConstruction(
        title: AppLocalizations.of(context).jobDescriptionTitle,
        subtitle: resumeId,
      );
}
