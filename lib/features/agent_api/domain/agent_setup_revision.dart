/// Version of the Agent setup contract shipped by this build.
///
/// Bump this only when connected Agents must receive the setup prompt again.
/// Ordinary app releases and dynamically delivered Prompt/Skill changes do not
/// require a bump.
const int currentAgentSetupRevision = 2;

/// First setup contract tracked by DingDong's update reminder.
///
/// Keeping this fixed lets a future build distinguish an older connected
/// installation from a brand-new installation that has no stored revision.
const int firstTrackedAgentSetupRevision = 1;

int resolveAcknowledgedAgentSetupRevision({
  required Object? storedValue,
  required bool hasSeenAgentAccess,
  int requiredRevision = currentAgentSetupRevision,
}) {
  if (storedValue is int) {
    return storedValue < 0 ? 0 : storedValue;
  }
  return hasSeenAgentAccess ? firstTrackedAgentSetupRevision : requiredRevision;
}
