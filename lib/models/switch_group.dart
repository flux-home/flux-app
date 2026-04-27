/// A logical grouping of endpoints on a multi-button/dial switch device,
/// corresponding to one physical slot (button + optional rotary).
class SwitchGroup {
  const SwitchGroup({
    required this.label,
    required this.pressEndpoints,
    required this.cwEndpoints,
    required this.ccwEndpoints,
  });

  final String    label;
  final List<int> pressEndpoints;
  final List<int> cwEndpoints;
  final List<int> ccwEndpoints;

  List<int> get allEndpoints =>
      [...pressEndpoints, ...cwEndpoints, ...ccwEndpoints];
}
