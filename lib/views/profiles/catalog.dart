import 'package:honey_utility/common/common.dart';
import 'package:honey_utility/controller.dart';
import 'package:honey_utility/models/models.dart';
import 'package:honey_utility/models/common.dart';
import 'package:honey_utility/providers/providers.dart';
import 'package:honey_utility/state.dart';
import 'package:honey_utility/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
import 'profiles.dart';
import '../proxies/proxies.dart';

/// Combined tab: profile list → servers view with nested Navigator.
class ProfileCatalogView extends StatelessWidget {
  const ProfileCatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => const _ProfileListPage(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level 1: Profile list
// ---------------------------------------------------------------------------

class _ProfileListPage extends ConsumerStatefulWidget {
  const _ProfileListPage();

  @override
  ConsumerState<_ProfileListPage> createState() => _ProfileListPageState();
}

class _ProfileListPageState extends ConsumerState<_ProfileListPage> {
  bool _isUpdating = false;

  void _handleShowAddExtendPage() {
    showExtend(
      globalState.navigatorKey.currentState!.context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          body: AddProfileView(
            context: globalState.navigatorKey.currentState!.context,
          ),
          title: '${appLocalizations.add}${appLocalizations.profile}',
        );
      },
    );
  }

  Future<void> _updateProfiles(List<Profile> profiles) async {
    if (_isUpdating) return;
    _isUpdating = true;
    final List<UpdatingMessage> messages = [];
    await Future.wait(profiles.map<Future>((profile) async {
      if (profile.type == ProfileType.file) return;
      try {
        await appController.updateProfile(profile, showLoading: true);
      } catch (e) {
        messages.add(UpdatingMessage(label: profile.realLabel, message: e.toString()));
      }
    }));
    if (messages.isNotEmpty) globalState.showAllUpdatingMessagesDialog(messages);
    _isUpdating = false;
  }

  void _openServers(BuildContext context, Profile profile) {
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
    appController.applyProfileDebounce();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const _ProfileServersPage(),
    ));
  }

  List<Widget> _buildActions(List<Profile> profiles) {
    if (profiles.isEmpty) return [];
    return [
      IconButton(
        onPressed: () => _updateProfiles(profiles),
        icon: const Icon(Icons.sync),
      ),
      IconButton(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_, type) => ReorderableProfilesSheet(
              type: type,
              profiles: profiles,
            ),
          );
        },
        icon: const Icon(Icons.sort),
        iconSize: 26,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
        final state = ref.watch(profilesStateProvider);
        final spacing = 14.mAp;
        return CommonScaffold(
          isLoading: isLoading,
          title: appLocalizations.profiles,
          floatingActionButton: CommonFloatingActionButton(
            onPressed: _handleShowAddExtendPage,
            icon: const Icon(Icons.add),
            label: context.appLocalizations.addProfile,
          ),
          actions: _buildActions(state.profiles),
          body: state.profiles.isEmpty
              ? NullStatus(
                  label: appLocalizations.nullProfileDesc,
                  illustration: ProfileEmptyIllustration(),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    key: profilesStoreKey,
                    padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 88,
                    ),
                    child: Grid(
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      crossAxisCount: state.columns,
                      children: [
                        for (int i = 0; i < state.profiles.length; i++)
                          GridItem(
                            child: ProfileItem(
                              key: Key(state.profiles[i].id.toString()),
                              profile: state.profiles[i],
                              groupValue: state.currentProfileId,
                              onChanged: (profileId) {
                                _openServers(context, state.profiles[i]);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Level 2: Servers / proxies page
// ---------------------------------------------------------------------------

class _ProfileServersPage extends StatelessWidget {
  const _ProfileServersPage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ProxiesView(),
        Positioned(
          bottom: 16,
          left: 16,
          child: SizedBox(
            height: 56,
            child: CommonFloatingActionButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: appLocalizations.profiles,
            ),
          ),
        ),
      ],
    );
  }
}
