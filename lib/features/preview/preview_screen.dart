import 'package:flutter/material.dart';

import '../../core/widgets/under_construction.dart';
import '../../l10n/app_localizations.dart';

/// Paginated preview of the generated PDF.
///
/// Rendered by the same engine that produces the exported file, so what the
/// user approves here is byte-for-byte what they send to an employer.
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({required this.resumeId, super.key});

  final String resumeId;

  @override
  Widget build(BuildContext context) => UnderConstruction(
        title: AppLocalizations.of(context).previewTitle,
        subtitle: resumeId,
      );
}
