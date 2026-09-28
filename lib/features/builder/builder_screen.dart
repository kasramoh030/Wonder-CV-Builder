import 'package:flutter/material.dart';

import '../../core/widgets/under_construction.dart';
import '../../l10n/app_localizations.dart';

/// The CV editor.
///
/// Owns a single [Resume] being edited and provides a two-pane experience on
/// wide screens (form + live preview) and a tabbed experience on phones.
class BuilderScreen extends StatelessWidget {
  const BuilderScreen({required this.resumeId, super.key});

  final String resumeId;

  @override
  Widget build(BuildContext context) => UnderConstruction(
        title: AppLocalizations.of(context).builderTitle,
        subtitle: resumeId,
      );
}
