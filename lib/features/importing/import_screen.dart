import 'package:flutter/material.dart';

import '../../core/widgets/under_construction.dart';
import '../../l10n/app_localizations.dart';

/// Import an existing CV from a file on the device.
class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) => UnderConstruction(
        title: AppLocalizations.of(context).importTitle,
      );
}
