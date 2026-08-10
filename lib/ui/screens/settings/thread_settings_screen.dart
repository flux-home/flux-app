import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matter_home/services/flux_coap_service.dart';
import 'package:matter_home/services/hub_connection.dart';
import 'package:matter_home/services/thread_settings_service.dart';
import 'package:matter_home/ui/widgets/info_row.dart';
import 'package:matter_home/ui/widgets/section_label.dart';
import 'package:provider/provider.dart';

// ── Main screen ───────────────────────────────────────────────────────────────

/// The controller's Thread network: what it runs (read-only — the controller is
/// the source of truth) plus the Thread 1.4 credential-sharing flows.
class ThreadSettingsScreen extends StatefulWidget {
  const ThreadSettingsScreen({super.key});

  @override
  State<ThreadSettingsScreen> createState() => _ThreadSettingsScreenState();
}

class _ThreadSettingsScreenState extends State<ThreadSettingsScreen> {
  bool _hubThreadLoaded = false;
  bool _hubThreadConfigured = false;  // does the controller run a Thread network?
  String? _hubDatasetHex;             // active dataset TLV hex (for detail rows)
  String? _hubRole;                   // live OT role: Leader / Router / Child …
  int?    _hubNeighborCount;

  @override
  void initState() {
    super.initState();
    _loadHubThread();
  }

  /// Read the controller's live operational Thread network (it's the border
  /// router) for display. The controller is the single source of truth — the
  /// app just shows what it's running; there is no phone→controller sync here.
  Future<void> _loadHubThread() async {
    final svc = context.read<HubConnection>().service;
    final ds  = svc == null ? null : await svc.getThreadDataset();
    if (!mounted) return;
    final hex = (ds != null && ds.tlv.isNotEmpty)
        ? ds.tlv.map((b) => b.toRadixString(16).padLeft(2, '0')).join()
        : null;
    setState(() {
      _hubThreadConfigured = hex != null;
      _hubDatasetHex       = hex;
      _hubRole             = (ds?.role.isNotEmpty ?? false) ? ds!.role : null;
      _hubNeighborCount    = ds?.neighborCount;
      _hubThreadLoaded     = true;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => _buildController(context);

  // ── CONTROLLER: the Thread network it runs (read-only) + sharing ──────────
  Widget _buildController(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Live network details. Identity (PAN ID / extended PAN ID) is deliberately
    // not shown — it means nothing to a user and only adds noise; what matters
    // is which network it is, its role, its radio channel and how big the mesh is.
    final channel = _hubDatasetHex == null
        ? null
        : ThreadTlvDecoder.decode(_hubDatasetHex!)
            .where((f) => f.label == 'Channel')
            .map((f) => f.value)
            .firstOrNull;
    final name = _hubDatasetHex == null
        ? null
        : ThreadTlvDecoder.networkName(_hubDatasetHex!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _hubThreadLoaded ? () {
              setState(() => _hubThreadLoaded = false);
              _loadHubThread();
            } : null,
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SectionLabel('Current network'),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: !_hubThreadLoaded
                ? const ListTile(
                    leading: SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    title: Text('Reading the controller…'),
                  )
                : !_hubThreadConfigured
                    ? ListTile(
                        leading: Icon(Icons.lan_outlined, color: cs.onSurfaceVariant),
                        title: const Text('No Thread network'),
                        subtitle: const Text(
                            'The controller is not running a Thread network yet. '
                            'Create one, or join an existing network below.'),
                      )
                    : Column(children: [
                        ListTile(
                          leading: Icon(Icons.lan_outlined, color: cs.primary),
                          title: Text(name?.isNotEmpty ?? false
                              ? name! : 'Thread network'),
                          subtitle: const Text(
                              'Running on the controller (border router)'),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16,
                            color: cs.outlineVariant),
                        if (_hubRole != null)
                          InfoRow(label: 'Role', value: _hubRole!),
                        if (channel != null)
                          InfoRow(label: 'Channel', value: channel),
                        if (_hubNeighborCount != null)
                          InfoRow(
                              label: 'Devices on mesh',
                              value: '$_hubNeighborCount'),
                      ]),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SectionLabel('Credential sharing'),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              // Plain title-only rows — the ecosystem explanation lives on the
              // screen each one opens, not stacked up in the menu.
              ListTile(
                title: const Text('Join an existing network'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _joinExistingNetwork,
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
              ListTile(
                enabled: _hubThreadConfigured,
                title: const Text('Share this network'),
                subtitle: _hubThreadConfigured
                    ? null
                    : const Text('No Thread network to share yet'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _hubThreadConfigured ? _shareNetwork : null,
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
              // Always available: it bootstraps a mesh when there is none, and
              // is also the way back out of a network shared with another
              // ecosystem.
              ListTile(
                title: const Text('Create a new network'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _createNetwork,
              ),
            ]),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _joinExistingNetwork() async {
    final svc = context.read<HubConnection>().service;
    if (svc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Controller not connected')));
      return;
    }
    final joined = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _JoinThreadNetworkScreen(
          service: svc, hubHasNetwork: _hubThreadConfigured),
    ));
    if ((joined ?? false) && mounted) {
      await _loadHubThread(); // controller now reports the adopted network
    }
  }

  Future<void> _shareNetwork() async {
    final svc = context.read<HubConnection>().service;
    if (svc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Controller not connected')));
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => _ShareThreadNetworkScreen(service: svc),
    ));
  }

  Future<void> _createNetwork() async {
    final svc = context.read<HubConnection>().service;
    if (svc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Controller not connected')));
      return;
    }
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _CreateThreadNetworkScreen(
          service: svc, currentName: _hubDatasetHex == null
              ? null
              : ThreadTlvDecoder.networkName(_hubDatasetHex!)),
    ));
    if ((created ?? false) && mounted) {
      await _loadHubThread(); // controller now reports its new network
    }
  }

  // ── THIS PHONE: scanned networks + saved credentials ──────────────────────
}

// ── Join an existing (foreign) Thread network — POST /thread/join ─────────────

/// Collects the ephemeral sharing code and asks the controller to join an
/// existing Thread network. The controller browses `_meshcop-e._udp` itself
/// (Option A), so this screen never touches an address — the user only opens
/// the other ecosystem's share sheet and types the code it shows.
class _JoinThreadNetworkScreen extends StatefulWidget {
  const _JoinThreadNetworkScreen({
    required this.service,
    required this.hubHasNetwork,
  });

  final FluxCoapService service;

  /// Whether the controller already runs its own mesh. When it does, a live
  /// switch would orphan commissioned devices, so migrate is the default.
  final bool hubHasNetwork;

  @override
  State<_JoinThreadNetworkScreen> createState() => _JoinThreadNetworkScreenState();
}

class _JoinThreadNetworkScreenState extends State<_JoinThreadNetworkScreen> {
  final _codeCtrl = TextEditingController();
  late bool _migrate = widget.hubHasNetwork;
  bool    _busy = false;
  String? _error;
  String? _joinedName;   // non-null once the join succeeds

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the code shown by the other app (6–32 characters).');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; });

    final res = await widget.service.joinThreadNetwork(
        ephemeralKey: code, migrate: _migrate);
    if (!mounted) return;

    if (res == null) {
      setState(() { _busy = false; _error = 'Could not reach the controller. Try again.'; });
      return;
    }
    if (!res.success) {
      setState(() {
        _busy = false;
        _error = res.error.isNotEmpty
            ? res.error
            : 'The controller could not join that network.';
      });
      return;
    }
    setState(() {
      _busy = false;
      _joinedName = res.networkName.isNotEmpty ? res.networkName : 'the network';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Thread network')),
      body: _joinedName != null
          ? _success(cs)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: cs.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adopt another ecosystem\'s network',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        Text(
                            'Joins the controller to your Apple, Google or '
                            'SmartThings Thread network so it and your other '
                            'hubs share one mesh instead of running separate ones.',
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 14),
                        Text('How it works',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        _step(cs, 1, 'Open your other smart-home app (Apple Home, '
                            'Google Home, SmartThings…).'),
                        _step(cs, 2, 'Start "Share Thread credentials" (often under '
                            'the home / hub settings). It shows a short code.'),
                        _step(cs, 3, 'Type that code below while its sharing screen '
                            'stays open, then Join.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeCtrl,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Sharing code',
                    hintText: 'e.g. 123-456-789',
                    prefixIcon: Icon(Icons.key_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _migrate,
                  onChanged: _busy ? null : (v) => setState(() => _migrate = v),
                  title: const Text('Migrate existing devices'),
                  subtitle: Text(_migrate
                      ? 'The controller moves its whole mesh onto the new network '
                        '(~30s); already-added devices follow.'
                      : 'Switch immediately. Only safe if the controller has no '
                        'devices yet — others would be orphaned.'),
                  isThreeLine: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _join,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.hub_outlined),
                  label: Text(_busy ? 'Joining…' : 'Join network'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ],
            ),
    );
  }

  Widget _success(ColorScheme cs) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, size: 56, color: Color(0xFF34A853)),
            const SizedBox(height: 16),
            Text(
              _migrate
                  ? 'Migrating onto "$_joinedName"'
                  : 'Joined "$_joinedName"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _migrate
                  ? 'The controller and its devices are moving to the new mesh '
                    'over the next ~30 seconds.'
                  : 'The controller is now on the shared Thread network.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Done'),
            ),
          ],
        ),
      );

  Widget _step(ColorScheme cs, int n, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: cs.primary,
              child: Text('$n', style: TextStyle(
                  fontSize: 12, color: cs.onPrimary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
          ],
        ),
      );
}

// ── Share this network with another app — /thread/epskc ───────────────────────

/// Starts the controller's ephemeral-key (`_meshcop-e._udp`) session and shows
/// the one-time code another ecosystem's app enters to join flux's Thread
/// network. Polls the session state until the other app is accepted, or the
/// session times out / is cancelled.
class _ShareThreadNetworkScreen extends StatefulWidget {
  const _ShareThreadNetworkScreen({required this.service});

  final FluxCoapService service;

  @override
  State<_ShareThreadNetworkScreen> createState() => _ShareThreadNetworkScreenState();
}

class _ShareThreadNetworkScreenState extends State<_ShareThreadNetworkScreen> {
  static const _sessionSeconds = 300; // 5 min window

  bool    _starting = true;
  String? _otpc;
  String  _state = '';
  String? _error;
  bool    _succeeded = false;   // saw "Accepted"
  bool    _ended = false;       // "Stopped"/"Disabled" without success
  Timer?  _poll;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    // Best-effort stop if the user leaves before the other app is accepted.
    if (!_succeeded) unawaited(widget.service.stopThreadShare());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() { _starting = true; _error = null; _ended = false; _succeeded = false; });
    final res = await widget.service.startThreadShare(timeoutSeconds: _sessionSeconds);
    if (!mounted) return;
    if (res == null || !res.success) {
      setState(() {
        _starting = false;
        _error = (res?.error.isNotEmpty ?? false)
            ? res!.error
            : 'Could not start credential sharing on the controller.';
      });
      return;
    }
    setState(() { _starting = false; _otpc = res.otpc; _state = res.state; });
    _evaluate(res.state);
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  Future<void> _tick() async {
    final res = await widget.service.getThreadShareState();
    if (!mounted || res == null) return; // transient read failure → keep polling
    setState(() => _state = res.state);
    _evaluate(res.state);
  }

  void _evaluate(String state) {
    if (state == 'Accepted') {
      _succeeded = true;
      _poll?.cancel();
    } else if (state == 'Stopped' || state == 'Disabled') {
      _ended = true;
      _poll?.cancel();
    }
  }

  String get _prettyOtpc {
    final c = _otpc ?? '';
    if (c.length != 9) return c;
    return '${c.substring(0, 3)} ${c.substring(3, 6)} ${c.substring(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Share Thread network')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _body(cs),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_starting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _centered(cs, Icons.error_outline, cs.error, 'Sharing unavailable',
          _error!, actionLabel: 'Try again', onAction: _start);
    }
    if (_succeeded) {
      return _centered(cs, Icons.check_circle_rounded, const Color(0xFF34A853),
          'Network shared',
          'The other app joined the controller\'s Thread network.',
          actionLabel: 'Done', onAction: () => Navigator.of(context).pop());
    }
    if (_ended) {
      return _centered(cs, Icons.timer_off_outlined, cs.onSurfaceVariant,
          'Sharing ended',
          'The code expired before another app joined.',
          actionLabel: 'Share again', onAction: _start);
    }

    // Active session: show the code + live status.
    final connecting = _state == 'Connected';
    return ListView(
      children: [
        Text('Enter this code in your other app',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
            "Lets Apple, Google or SmartThings join the controller's Thread "
            'network, so both ecosystems share one mesh. In that app, add a '
            'Thread network or accessory, then type the code below while this '
            'screen stays open.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 28),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              _prettyOtpc,
              style: const TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w600,
                  letterSpacing: 3, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.primary)),
            const SizedBox(width: 12),
            Text(connecting ? 'Connecting…' : 'Waiting for the other app…',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 40),
        OutlinedButton(
          onPressed: () async {
            _poll?.cancel();
            await widget.service.stopThreadShare();
            if (mounted) Navigator.of(context).pop();
          },
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Cancel sharing'),
        ),
      ],
    );
  }

  Widget _centered(ColorScheme cs, IconData icon, Color color, String title,
          String body, {required String actionLabel, required VoidCallback onAction}) =>
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(actionLabel),
          ),
        ],
      );
}

// ── Create a new network — POST /thread/create ────────────────────────────────

/// Explains and confirms forming a brand-new Thread network on the controller.
/// Two uses: bootstrap a mesh when there is none, and — as the inverse of
/// joining — leave a network shared with another ecosystem and go back to an
/// independent mesh.
class _CreateThreadNetworkScreen extends StatefulWidget {
  const _CreateThreadNetworkScreen({required this.service, this.currentName});

  final FluxCoapService service;

  /// Name of the network the controller is on today (for the explanation).
  final String? currentName;

  @override
  State<_CreateThreadNetworkScreen> createState() => _CreateThreadNetworkScreenState();
}

class _CreateThreadNetworkScreenState extends State<_CreateThreadNetworkScreen> {
  bool    _busy = false;
  String? _error;
  bool    _done = false;

  Future<void> _create() async {
    setState(() { _busy = true; _error = null; });
    final res = await widget.service.createThreadNetwork();
    if (!mounted) return;
    if (res == null) {
      setState(() {
        _busy = false;
        _error = 'The controller did not create a network. It may not support '
            'this yet — check the controller logs.';
      });
      return;
    }
    if (res.code != 0) {
      setState(() {
        _busy = false;
        _error = res.message.isNotEmpty
            ? res.message
            : 'The controller could not form a new network.';
      });
      return;
    }
    setState(() { _busy = false; _done = true; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // The controller may have no network at all (first-time bootstrap), in which
    // case there is nothing to leave and the copy must not imply otherwise.
    final onNetwork = widget.currentName != null;
    final from = (widget.currentName?.isNotEmpty ?? false)
        ? '"${widget.currentName}"' : 'its current network';

    return Scaffold(
      appBar: AppBar(title: const Text('Create network')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _done
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 56,
                      color: Color(0xFF34A853)),
                  const SizedBox(height: 16),
                  Text(onNetwork ? 'Moving to a new network'
                                 : 'Network created',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                      onNetwork
                          ? 'The controller is moving itself and its devices onto '
                            'a fresh Thread network. This takes about 30 seconds.'
                          : 'The controller is now the border router for its own '
                            'Thread network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: const Text('Done'),
                  ),
                ],
              )
            : ListView(
                children: [
                  Text(onNetwork
                          ? 'Run an independent mesh'
                          : 'Start a Thread mesh',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                      onNetwork
                          ? 'The controller leaves $from and forms a brand-new '
                            'Thread network of its own, with fresh credentials. '
                            'Use this to stop sharing a mesh with another '
                            'ecosystem.'
                          : 'The controller forms its own Thread network with '
                            'fresh credentials, so Thread devices have a mesh to '
                            'join. You can share it with other ecosystems, or '
                            'join theirs instead, at any time.',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  Card(
                    color: cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What happens',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          if (onNetwork) ...[
                            _bullet(cs, 'Devices commissioned to this controller '
                                'migrate to the new network with it.'),
                            _bullet(cs, "The other ecosystem's hubs and their own "
                                'devices stay on the old network.'),
                            _bullet(cs, 'The two meshes can no longer relay for '
                                'each other, so range may drop.'),
                            _bullet(cs, 'You can join a shared network again at '
                                'any time.'),
                          ] else ...[
                            _bullet(cs, 'The controller becomes the border router '
                                'for the new mesh.'),
                            _bullet(cs, 'Thread devices you add from now on join '
                                'this network.'),
                            _bullet(cs, 'You can share it with another ecosystem, '
                                'or join theirs, at any time.'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: TextStyle(color: cs.error, fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _create,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: Text(_busy ? 'Forming…' : 'Form a new network'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _bullet(ColorScheme cs, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 10),
              child: Container(width: 5, height: 5,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: cs.onSurfaceVariant)),
            ),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
          ],
        ),
      );
}
