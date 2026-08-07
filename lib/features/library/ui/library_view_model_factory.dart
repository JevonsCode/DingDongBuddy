import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/library_import_history.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';

/// Builds the desktop library model with the same online capabilities in every
/// window engine.
LibraryViewModel createDesktopLibraryViewModel(
  ResourceStore repository, {
  ResourceUpdateFetcher? updateFetcher,
  SkillPackageInstaller? skillPackageInstaller,
  TriggerGroupStore? triggerGroupStore,
  LibraryImportHistoryStore? importHistoryStore,
  DataRevisionBus? revisions,
}) {
  return LibraryViewModel(
    repository,
    updateFetcher: updateFetcher ?? HttpResourceUpdateFetcher(),
    skillPackageInstaller:
        skillPackageInstaller ??
        GitHubSkillPackageInstaller(
          AppDataPaths.current().skillPackagesDirectory,
        ),
    triggerGroupStore: triggerGroupStore,
    importHistoryStore:
        importHistoryStore ??
        FileLibraryImportHistoryStore(
          AppDataPaths.current().libraryImportHistoryFile,
        ),
    revisions: revisions,
  );
}
