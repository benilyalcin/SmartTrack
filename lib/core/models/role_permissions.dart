enum AppRole { driver, company, police }

class RolePermissions {
  final bool viewOwnDataOnly;

  final bool viewAllDrivers;

  final bool viewViolations;

  final bool viewCardHolderPii;

  final bool canManualEntry;

  final bool canExportPdf;

  const RolePermissions({
    required this.viewOwnDataOnly,
    required this.viewAllDrivers,
    required this.viewViolations,
    required this.viewCardHolderPii,
    required this.canManualEntry,
    required this.canExportPdf,
  });

  factory RolePermissions.forRole(AppRole role) {
    switch (role) {
      case AppRole.driver:
        return const RolePermissions(
          viewOwnDataOnly: true,
          viewAllDrivers: false,
          viewViolations: true,
          viewCardHolderPii: true,
          canManualEntry: true,
          canExportPdf: true,
        );
      case AppRole.company:
        return const RolePermissions(
          viewOwnDataOnly: false,
          viewAllDrivers: true,
          viewViolations: true,
          viewCardHolderPii: true,
          canManualEntry: false,
          canExportPdf: true,
        );
      case AppRole.police:
        return const RolePermissions(
          viewOwnDataOnly: false,
          viewAllDrivers: true,
          viewViolations: true,
          viewCardHolderPii: true,
          canManualEntry: false,
          canExportPdf: true,
        );
    }
  }
}

extension AppRoleCodec on AppRole {
  String get code {
    switch (this) {
      case AppRole.driver:
        return 'Sürücü';
      case AppRole.company:
        return 'Şirket';
      case AppRole.police:
        return 'Polis';
    }
  }

  static AppRole fromCode(String code) {
    switch (code) {
      case 'Şirket':
        return AppRole.company;
      case 'Polis':
        return AppRole.police;
      case 'Sürücü':
      default:
        return AppRole.driver;
    }
  }
}
