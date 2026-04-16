import 'package:honey_utility/common/app_localizations.dart';
import 'package:honey_utility/views/config/general.dart';
import 'package:honey_utility/widgets/widgets.dart';
import 'package:flutter/material.dart';

class ConfigView extends StatelessWidget {
  const ConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: appLocalizations.basicConfig,
      body: generateListView(generalItems),
    );
  }
}
