import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:matter_home/models/automation_rule.dart';
import 'package:matter_home/models/device_type.dart';
import 'package:matter_home/models/device_view.dart';
import 'package:matter_home/models/matter_device.dart';
import 'package:matter_home/models/switch_group.dart';
import 'package:matter_home/providers/device_provider.dart';
import 'package:matter_home/ui/widgets/bottom_sheet_scaffold.dart';
import 'package:provider/provider.dart';

IconData _triggerIcon(TriggerType t) => switch (t) {
  TriggerType.switchPress  => Icons.radio_button_checked_outlined,
  TriggerType.switchCw     => Icons.keyboard_arrow_up,
  TriggerType.switchCcw    => Icons.keyboard_arrow_down,
  TriggerType.contactOpen  => Icons.meeting_room_outlined,
  TriggerType.contactClose => Icons.sensor_door_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// Connection detail sheet — per-gesture action dropdowns + delete
// ─────────────────────────────────────────────────────────────────────────────

class ConnectionDetailSheet extends StatefulWidget {
  const ConnectionDetailSheet({
    required this.source,
    required this.connection,
    required this.targetView,
    required this.groups,
    super.key,
  });
  final MatterDevice      source;
  final DeviceConnection  connection;
  final DeviceView        targetView;
  final List<SwitchGroup> groups;

  @override
  State<ConnectionDetailSheet> createState() => _ConnectionDetailSheetState();
}

class _ConnectionDetailSheetState extends State<ConnectionDetailSheet> {
  late final Map<TriggerType, AutomationAction?> _selections;

  @override
  void initState() {
    super.initState();
    _selections = {};
    for (final rule in widget.connection.rules) {
      _selections[rule.trigger] = rule.action;
    }
  }

  List<TriggerType> get _triggers {
    if (widget.source.deviceType == DeviceType.contactSensor) {
      return [TriggerType.contactOpen, TriggerType.contactClose];
    }
    final group = widget.groups.firstWhereOrNull((g) => g.label == widget.connection.switchGroup);
    if (group == null) return [TriggerType.switchPress];
    return [
      if (group.pressEndpoints.isNotEmpty) TriggerType.switchPress,
      if (group.cwEndpoints.isNotEmpty)    TriggerType.switchCw,
      if (group.ccwEndpoints.isNotEmpty)   TriggerType.switchCcw,
    ];
  }

  bool get _hasOnOff => widget.targetView.deviceType.hasOnOff ||
      (context.read<DeviceProvider>().liveDataFor(widget.targetView.id)?.attrs.containsKey('onOff') ?? false);
  bool get _hasBrightness => widget.targetView.deviceType.hasBrightness ||
      (context.read<DeviceProvider>().liveDataFor(widget.targetView.id)?.attrs.containsKey('level') ?? false);
  bool get _isThermostat => widget.targetView.deviceType == DeviceType.thermostat ||
      (context.read<DeviceProvider>().liveDataFor(widget.targetView.id)?.attrs.containsKey('localTempCenti') ?? false);

  void _save() {
    final provider = context.read<DeviceProvider>();
    provider.disconnectTarget(
      sourceDeviceId: widget.source.id,
      targetDeviceId: widget.connection.targetDeviceId,
      switchGroup:    widget.connection.switchGroup,
    );
    final group = widget.groups.firstWhereOrNull((g) => g.label == widget.connection.switchGroup);
    for (final entry in _selections.entries) {
      final action = entry.value;
      if (action == null) continue;
      provider.upsertRule(AutomationRule(
        sourceDeviceId:  widget.source.id,
        trigger:         entry.key,
        switchGroup:     widget.connection.switchGroup,
        endpoints:       _endpointsFor(entry.key, group),
        action:          action,
        targetDeviceIds: [widget.connection.targetDeviceId],
      ));
    }
    Navigator.pop(context);
  }

  List<int> _endpointsFor(TriggerType t, SwitchGroup? group) => switch (t) {
    TriggerType.switchPress => group?.pressEndpoints ?? [],
    TriggerType.switchCw    => group?.cwEndpoints    ?? [],
    TriggerType.switchCcw   => group?.ccwEndpoints   ?? [],
    _                       => [],
  };

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final triggers = _triggers;

    return BottomSheetScaffold(
      titleWidget: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
          child: Icon(widget.targetView.deviceType.icon, size: 18, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.targetView.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (widget.connection.switchGroup != null)
            Text('Slot ${widget.connection.switchGroup}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ])),
      ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 24, indent: 24, endIndent: 24),
          for (final trigger in triggers)
            _GestureActionRow(
              trigger:   trigger,
              selected:  _selections[trigger],
              actions:   actionsFor(
                trigger:       trigger,
                hasOnOff:      _hasOnOff,
                hasBrightness: _hasBrightness,
                isThermostat:  _isThermostat,
              ),
              onChanged: (a) => setState(() => _selections[trigger] = a),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Row(children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('Disconnect'),
                style: OutlinedButton.styleFrom(foregroundColor: cs.error, side: BorderSide(color: cs.error)),
                onPressed: () {
                  context.read<DeviceProvider>().disconnectTarget(
                    sourceDeviceId: widget.source.id,
                    targetDeviceId: widget.connection.targetDeviceId,
                    switchGroup:    widget.connection.switchGroup,
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _save, child: const Text('Save'))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _GestureActionRow extends StatelessWidget {
  const _GestureActionRow({
    required this.trigger,
    required this.selected,
    required this.actions,
    required this.onChanged,
  });
  final TriggerType              trigger;
  final AutomationAction?        selected;
  final List<AutomationAction?>  actions;
  final ValueChanged<AutomationAction?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (actions.isEmpty || (actions.length == 1 && actions.first == null)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(children: [
        Icon(_triggerIcon(trigger), size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(trigger.label, style: TextStyle(fontSize: 13, color: cs.onSurface)),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AutomationAction?>(
              value:        actions.contains(selected) ? selected : null,
              isExpanded:   true,
              style:        TextStyle(fontSize: 13, color: cs.onSurface),
              dropdownColor: cs.surfaceContainerHigh,
              items: [
                for (final a in actions)
                  DropdownMenuItem(
                    value: a,
                    child: Text(a?.label ?? '— none —',
                        style: TextStyle(fontSize: 13,
                            color: a == null ? cs.onSurfaceVariant.withValues(alpha: 0.5) : cs.onSurface)),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }
}
