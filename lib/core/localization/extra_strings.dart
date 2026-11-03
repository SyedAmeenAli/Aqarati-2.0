import 'agent_strings.dart';
import 'analytics_strings.dart';
import 'broker_strings.dart';
import 'ebroker_strings.dart';
import 'engagement_strings.dart';
import 'help_strings.dart';
import 'hub_strings.dart';
import 'lead_strings.dart';
import 'profile_strings.dart';
import 'provider_strings.dart';
import 'settings_strings.dart';
import 'workspace_strings.dart';

/// Aggregates copy added by later feature modules. Arabic is DRAFT copy and needs native review.
const Map<String, (String, String)> extraStrings = {
  ...workspaceStrings,
  ...agentStrings,
  ...analyticsStrings,
  ...settingsStrings,
  ...leadStrings,
  ...helpStrings,
  ...hubStrings,
  ...eBrokerStrings,
  ...brokerStrings,
  ...engagementStrings,
  ...profileStrings,
  ...providerStrings,
};
