// disclosure package — public API barrel

export 'src/domain/aggregates/disclosure_acceptance.dart';
export 'src/domain/events/disclosure_accepted.dart';
export 'src/domain/value_objects/ids.dart';
export 'src/application/use_cases/accept_disclosure_use_case.dart';
// Infrastructure — read access for app-shell seams (the post-sign-in disclosure
// gate reads acceptance to decide whether the consolidated disclosure must be
// shown). Acceptance rows are PHI-free regardless of who reads the DAO.
export 'src/infrastructure/drift/disclosure_dao.dart';
export 'src/presentation/screens/consolidated_disclosure_screen.dart';
export 'src/presentation/routes.dart';
// Module copy — the app shell reuses the same reviewed legal sections for the
// tappable terms / privacy sheet on the auth footer.
export 'src/i18n/strings.dart';
