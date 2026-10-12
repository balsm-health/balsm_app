/// Native apps are single-instance; there is no second tab to lose to.
Future<bool> claimDatabaseTab() async => true;

/// Web only.
void reloadPage() {}
