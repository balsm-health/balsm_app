import 'package:core/core.dart';

import '../../domain/aggregates/member_group.dart';

/// Persistence port for [MemberGroup]s, partitioned by the owning account
/// (core [UserDataSource] scope semantics). Reads leave soft-deleted groups
/// out and list groups in display order. [delete] is soft; [clear] removes
/// an account's rows outright (account wipe). The drift implementation lives
/// in `infrastructure/drift/`.
abstract class MemberGroupsDataSource extends UserDataSource<MemberGroupId, MemberGroup>
    implements WatchableScopedDataSource<MemberGroupId, MemberGroup, UserId> {}
