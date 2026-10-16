class AttendanceSyncOutcome {
  final String state;
  final bool terminal;
  final bool discardEvidence;
  final bool recorded;
  const AttendanceSyncOutcome(
    this.state,
    this.terminal,
    this.discardEvidence,
    this.recorded,
  );
  factory AttendanceSyncOutcome.fromResult(Map<String, dynamic> result) {
    final status = result['status'];
    if (status == 'SYNCED' && result['serverRecordId'] != null) {
      return const AttendanceSyncOutcome('SYNCED', true, true, true);
    }
    if (status == 'SKIPPED' && result['serverRecordId'] != null) {
      return const AttendanceSyncOutcome('SYNCED', true, true, false);
    }
    if (status == 'PENDING_REVIEW' && result['reviewId'] != null) {
      return const AttendanceSyncOutcome('PENDING_REVIEW', true, true, false);
    }
    if (status == 'REJECTED' && result['reviewId'] != null) {
      return const AttendanceSyncOutcome('REJECTED', true, true, false);
    }
    return const AttendanceSyncOutcome('PENDING_SYNC', false, false, false);
  }
}
