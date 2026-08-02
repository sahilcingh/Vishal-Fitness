import 'package:flutter/foundation.dart';
import '../../main.dart';

/// Records member_events audit rows for mutations that otherwise overwrite
/// data in place with no history (status changes, discount edits,
/// subscription edits, profile edits). Mirrors logMemberEvent in the
/// website's src/lib/member-events.ts so both platforms feed the same
/// Ledger. Best-effort: a logging failure must never surface as an error
/// for the mutation it's describing, which has already succeeded by the
/// time this is called.
Future<void> logMemberEvent({
  required String userId,
  String? subscriptionId,
  required String eventType,
  required String description,
}) async {
  try {
    await supabase.from('member_events').insert({
      'user_id': userId,
      'subscription_id': subscriptionId,
      'event_type': eventType,
      'description': description,
      'created_by': supabase.auth.currentUser?.id,
    });
  } catch (e) {
    debugPrint('logMemberEvent: insert failed: $e');
  }
}
