import 'package:honey_utility/enum/enum.dart';
import 'package:honey_utility/models/models.dart';
import 'package:honey_utility/views/views.dart';
import 'package:honey_utility/views/profiles/catalog.dart';
import 'package:flutter/material.dart';

class Navigation {
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) {
    return [
      NavigationItem(
        keep: false,
        icon: Icon(Icons.space_dashboard),
        label: PageLabel.dashboard,
        builder: (_) =>
            const DashboardView(key: GlobalObjectKey(PageLabel.dashboard)),
      ),

      NavigationItem(
        icon: Icon(Icons.folder),
        label: PageLabel.profiles,
        builder: (_) =>
            const ProfileCatalogView(key: GlobalObjectKey(PageLabel.profiles)),
      ),

      NavigationItem(
        icon: Icon(Icons.storage),
        label: PageLabel.resources,
        description: 'resourcesDesc',
        builder: (_) =>
            const ResourcesView(key: GlobalObjectKey(PageLabel.resources)),
        modes: [NavigationItemMode.more],
      ),
      NavigationItem(
        icon: const Icon(Icons.terminal),
        label: PageLabel.logs,
        builder: (_) => const LogsView(key: GlobalObjectKey(PageLabel.logs)),
        description: 'logsDesc',
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      NavigationItem(
        icon: Icon(Icons.construction),
        label: PageLabel.tools,
        builder: (_) => const ToolsView(key: GlobalObjectKey(PageLabel.tools)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      NavigationItem(
        icon: Icon(Icons.storefront_outlined),
        label: PageLabel.store,
        builder: (_) => const StoreView(key: GlobalObjectKey(PageLabel.store)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
