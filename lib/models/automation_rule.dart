import 'package:uuid/uuid.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TriggerType {
  switchPress,
  switchCw,
  switchCcw,
  contactOpen,
  contactClose,
}

enum AutomationAction {
  toggle,
  turnOn,
  turnOff,
  thermostatOff,          // turn off heating (semantic alias used in contact-sensor presets)
  brightnessStepUp,
  brightnessStepDown,
  thermostatSetpointUp,   // +0.5 °C fixed step
  thermostatSetpointDown, // −0.5 °C fixed step
}

// ── Extensions ────────────────────────────────────────────────────────────────

extension TriggerTypeX on TriggerType {
  bool get isSwitch =>
      this == TriggerType.switchPress ||
      this == TriggerType.switchCw    ||
      this == TriggerType.switchCcw;

  String get label => switch (this) {
    TriggerType.switchPress    => 'Press',
    TriggerType.switchCw       => 'Scroll up',
    TriggerType.switchCcw      => 'Scroll down',
    TriggerType.contactOpen    => 'When opened',
    TriggerType.contactClose   => 'When closed',
  };
}

extension AutomationActionX on AutomationAction {
  String get label => switch (this) {
    AutomationAction.toggle                => 'Toggle',
    AutomationAction.turnOn                => 'Turn on',
    AutomationAction.turnOff               => 'Turn off',
    AutomationAction.thermostatOff         => 'Heating off',
    AutomationAction.brightnessStepUp      => 'Dim ↑',
    AutomationAction.brightnessStepDown    => 'Dim ↓',
    AutomationAction.thermostatSetpointUp  => 'Temp ↑',
    AutomationAction.thermostatSetpointDown=> 'Temp ↓',
  };
}

// ── Model ─────────────────────────────────────────────────────────────────────

/// One automation rule: a single trigger on a source device executes one
/// action on one or more target devices.
///
/// For switch triggers [switchGroup] identifies the slot label ("1"/"2"/"3")
/// and [endpoints] are the endpoint numbers used for event matching.
/// For contact triggers both fields are empty / null.
class AutomationRule {
  AutomationRule({
    String? id,
    required this.sourceDeviceId,
    required this.trigger,
    this.switchGroup,
    this.endpoints = const [],
    required this.action,
    required this.targetDeviceIds,
  }) : id = id ?? const Uuid().v4();

  final String           id;
  final String           sourceDeviceId;
  final TriggerType      trigger;
  final String?          switchGroup;
  final List<int>        endpoints;
  final AutomationAction action;
  final List<String>     targetDeviceIds;

  AutomationRule copyWith({
    AutomationAction? action,
    List<String>? targetDeviceIds,
  }) => AutomationRule(
    id:              id,
    sourceDeviceId:  sourceDeviceId,
    trigger:         trigger,
    switchGroup:     switchGroup,
    endpoints:       endpoints,
    action:          action          ?? this.action,
    targetDeviceIds: targetDeviceIds ?? this.targetDeviceIds,
  );

  Map<String, dynamic> toJson() => {
    'id':              id,
    'sourceDeviceId':  sourceDeviceId,
    'trigger':         trigger.name,
    'switchGroup':     switchGroup,
    'endpoints':       endpoints,
    'action':          action.name,
    'targetDeviceIds': targetDeviceIds,
  };

  factory AutomationRule.fromJson(Map<String, dynamic> j) => AutomationRule(
    id:              j['id']             as String,
    sourceDeviceId:  j['sourceDeviceId'] as String,
    trigger:         TriggerType.values.byName(j['trigger'] as String),
    switchGroup:     j['switchGroup']    as String?,
    endpoints:       List<int>.from(j['endpoints'] as List? ?? []),
    action:          AutomationAction.values.byName(j['action'] as String),
    targetDeviceIds: List<String>.from(j['targetDeviceIds'] as List),
  );
}

// ── Connection (UI grouping of rules sharing source → target) ───────────────────

/// All rules for a single source → target relationship.
/// For switch sources [switchGroup] is the slot label; null for contact sensors.
class DeviceConnection {
  const DeviceConnection({
    required this.targetDeviceId,
    required this.switchGroup,
    required this.rules,
  });
  final String             targetDeviceId;
  final String?            switchGroup;
  final List<AutomationRule> rules;

  AutomationRule? ruleFor(TriggerType t) =>
      rules.where((r) => r.trigger == t).firstOrNull;
}

// ── Action list per (trigger, target) for the connection detail sheet ─────────

/// Returns the ordered list of valid actions for [trigger] given target
/// capabilities.  [null] represents “no action” (gesture disabled).
List<AutomationAction?> actionsFor({
  required TriggerType trigger,
  required bool hasOnOff,
  required bool hasBrightness,
  required bool isThermostat,
}) {
  final out = <AutomationAction?>[];
  switch (trigger) {
    case TriggerType.switchPress:
    case TriggerType.contactOpen:
    case TriggerType.contactClose:
      if (hasOnOff) {
        out.addAll([
          AutomationAction.toggle,
          AutomationAction.turnOn,
          AutomationAction.turnOff,
        ]);
      }
      if (isThermostat) {
        out.addAll([
          AutomationAction.thermostatOff,
          AutomationAction.thermostatSetpointUp,
          AutomationAction.thermostatSetpointDown,
        ]);
      }
    case TriggerType.switchCw:
      if (hasBrightness) out.add(AutomationAction.brightnessStepUp);
      if (isThermostat)  out.add(AutomationAction.thermostatSetpointUp);
    case TriggerType.switchCcw:
      if (hasBrightness) out.add(AutomationAction.brightnessStepDown);
      if (isThermostat)  out.add(AutomationAction.thermostatSetpointDown);
  }
  // “No action” is always available (disables the gesture).
  out.add(null);
  return out;
}

// ── Action ordering per trigger (for the edit sheet) ─────────────────────

/// Returns actions ordered by relevance to [trigger].
/// The first item is the default when creating a new rule.
List<AutomationAction> suggestedActions(TriggerType trigger) => switch (trigger) {
  TriggerType.switchPress => [
    AutomationAction.toggle,
    AutomationAction.turnOn,
    AutomationAction.turnOff,
    AutomationAction.thermostatOff,
    AutomationAction.brightnessStepUp,
    AutomationAction.brightnessStepDown,
    AutomationAction.thermostatSetpointUp,
    AutomationAction.thermostatSetpointDown,
  ],
  TriggerType.switchCw => [
    AutomationAction.brightnessStepUp,
    AutomationAction.thermostatSetpointUp,
    AutomationAction.toggle,
    AutomationAction.turnOn,
    AutomationAction.turnOff,
    AutomationAction.thermostatOff,
    AutomationAction.brightnessStepDown,
    AutomationAction.thermostatSetpointDown,
  ],
  TriggerType.switchCcw => [
    AutomationAction.brightnessStepDown,
    AutomationAction.thermostatSetpointDown,
    AutomationAction.toggle,
    AutomationAction.turnOn,
    AutomationAction.turnOff,
    AutomationAction.thermostatOff,
    AutomationAction.brightnessStepUp,
    AutomationAction.thermostatSetpointUp,
  ],
  TriggerType.contactOpen => [
    AutomationAction.thermostatOff,
    AutomationAction.turnOff,
    AutomationAction.toggle,
    AutomationAction.turnOn,
    AutomationAction.brightnessStepDown,
    AutomationAction.thermostatSetpointDown,
    AutomationAction.brightnessStepUp,
    AutomationAction.thermostatSetpointUp,
  ],
  TriggerType.contactClose => [
    AutomationAction.turnOn,
    AutomationAction.toggle,
    AutomationAction.turnOff,
    AutomationAction.thermostatOff,
    AutomationAction.brightnessStepUp,
    AutomationAction.thermostatSetpointUp,
    AutomationAction.brightnessStepDown,
    AutomationAction.thermostatSetpointDown,
  ],
};
