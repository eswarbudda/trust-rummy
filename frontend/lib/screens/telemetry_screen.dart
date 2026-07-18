import 'package:flutter/material.dart';

import '../services/auth_api_service.dart';
import '../services/websocket_service.dart';

/// Phase 1 deliverable: a clean, visual "hit run and it just works" screen
/// that proves the full loop end-to-end -
///   Flutter --REST(register)--> Spring Boot --JWT-->
///   Flutter --WSS handshake w/ JWT--> Spring Boot WebSocket handler
/// and then streams a live heartbeat/latency indicator.
class TelemetryScreen extends StatefulWidget {
  const TelemetryScreen({super.key});

  @override
  State<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen> {
  final _authApi = AuthApiService();
  final _ws = WebSocketService();

  final List<String> _log = [];
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  int? _latestLatencyMs;
  bool _isBootstrapping = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ws.stateStream.listen((state) {
      setState(() => _connectionState = state);
    });
    _ws.eventStream.listen((event) {
      setState(() {
        _log.insert(0, _formatEvent(event));
        if (_log.length > 50) _log.removeLast();
      });
    });
    _ws.latencyStream.listen((latency) {
      setState(() => _latestLatencyMs = latency);
    });
  }

  String _formatEvent(TelemetryEvent event) {
    final time = event.receivedAt.toIso8601String().split('T').last;
    switch (event.type) {
      case 'WELCOME':
        return '[$time] WELCOME - connected as ${event.raw['user']}';
      case 'PONG':
        return '[$time] PONG - seq #${event.raw['sequence']}';
      default:
        return '[$time] ${event.type} - ${event.raw}';
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isBootstrapping = true;
      _errorMessage = null;
    });

    try {
      final token = await _authApi.quickRegisterTestUser();
      await _ws.connect(token);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isBootstrapping = false);
    }
  }

  void _disconnect() {
    _ws.disconnect();
    setState(() {
      _latestLatencyMs = null;
    });
  }

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }

  Color _statusColor() {
    switch (_connectionState) {
      case SocketConnectionState.connected:
        return Colors.greenAccent;
      case SocketConnectionState.connecting:
        return Colors.amberAccent;
      case SocketConnectionState.error:
        return Colors.redAccent;
      case SocketConnectionState.disconnected:
        return Colors.white38;
    }
  }

  String _statusLabel() {
    switch (_connectionState) {
      case SocketConnectionState.connected:
        return 'LIVE';
      case SocketConnectionState.connecting:
        return 'CONNECTING…';
      case SocketConnectionState.error:
        return 'ERROR';
      case SocketConnectionState.disconnected:
        return 'OFFLINE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _connectionState == SocketConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trust Rummy — Live Telemetry'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _StatusCard(
                  color: _statusColor(),
                  label: _statusLabel(),
                  latencyMs: _latestLatencyMs,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_isBootstrapping || connected) ? null : _connect,
                        icon: _isBootstrapping
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bolt),
                        label: Text(_isBootstrapping ? 'Bootstrapping…' : 'Connect (auto test user)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: connected ? _disconnect : null,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Live event log',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: _log.isEmpty
                        ? const Center(
                            child: Text(
                              'No telemetry yet — tap Connect above.',
                              style: TextStyle(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _log.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _log[index],
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Color color;
  final String label;
  final int? latencyMs;

  const _StatusCard({required this.color, required this.label, required this.latencyMs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.18), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latencyMs != null
                      ? 'Round-trip latency: ${latencyMs}ms'
                      : 'Waiting for heartbeat…',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
