import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_colors.dart';
import '../services/preferences_service.dart';

// ── BLE identifiers ───────────────────────────────────────────────────────────

const String _kDeviceName = 'GasYangu';
const String _kServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const String _kWeightUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

enum _BleStatus { idle, scanning, connecting, connected }

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Settings
  double _deadWeight = 0.0;
  double _fullWeight = 0.0;
  double _warningPercent = 20.0;

  // BLE
  _BleStatus _bleStatus = _BleStatus.idle;
  double? _weight;
  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _weightSub;
  bool _autoReconnect = false;
  DateTime? _lastReceived;
  DateTime? _lastConnected;
  Timer? _refreshTimer;

  // Derived values
  double get _netGasWeight => (_weight ?? 0.0) - _deadWeight;
  double get _maxGasWeight => _fullWeight - _deadWeight;
  double get _percentage =>
      _maxGasWeight > 0
          ? (_netGasWeight / _maxGasWeight * 100).clamp(0.0, 100.0)
          : 0.0;
  bool get _isWarning =>
      _weight != null && _maxGasWeight > 0 && _percentage <= _warningPercent;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _autoReconnect = false;
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _weightSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait([
      PreferencesService.load(),
      PreferencesService.getLastWeight(),
      PreferencesService.getLastReceivedTime(),
      PreferencesService.getLastConnectedTime(),
    ]);
    if (!mounted) return;
    final data = results[0] as Map<String, double>;
    setState(() {
      _deadWeight = data['deadWeight']!;
      _fullWeight = data['fullWeight']!;
      _warningPercent = data['warningPercent']!;
      final w = results[1] as double?;
      if (w != null) _weight = w;
      _lastReceived = results[2] as DateTime?;
      _lastConnected = results[3] as DateTime?;
    });
  }

  // ── Permissions ─────────────────────────────────────────────────────────────

  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  // ── BLE ─────────────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    if (_bleStatus != _BleStatus.idle) return;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on Bluetooth and try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final granted = await _requestPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions are required.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _bleStatus = _BleStatus.scanning;
      _autoReconnect = true;
    });

    await FlutterBluePlus.startScan(
      withServices: [Guid(_kServiceUuid)],
      timeout: const Duration(seconds: 10),
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == _kDeviceName) {
          FlutterBluePlus.stopScan();
          _scanSub?.cancel();
          _connect(r.device);
          break;
        }
      }
    });

    FlutterBluePlus.isScanning.where((s) => !s).first.then((_) {
      _scanSub?.cancel();
      if (mounted && _bleStatus == _BleStatus.scanning) {
        setState(() => _bleStatus = _BleStatus.idle);
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (!mounted) return;
    setState(() {
      _bleStatus = _BleStatus.connecting;
      _device = device;
    });

    try {
      await device.connect(autoConnect: false);
    } catch (e) {
      if (mounted) setState(() => _bleStatus = _BleStatus.idle);
      return;
    }

    _connectionSub?.cancel();
    _weightSub?.cancel();

    _connectionSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _weightSub?.cancel();
        if (mounted) setState(() => _bleStatus = _BleStatus.idle);
        if (_autoReconnect) {
          Future.delayed(const Duration(seconds: 5), _startScan);
        }
      }
    });

    try {
      final services = await device.discoverServices();
      for (final svc in services) {
        if (svc.uuid != Guid(_kServiceUuid)) continue;
        for (final c in svc.characteristics) {
          if (c.uuid != Guid(_kWeightUuid)) continue;
          await c.setNotifyValue(true);
          _weightSub = c.onValueReceived.listen((v) {
            final raw = double.tryParse(String.fromCharCodes(v));
            if (raw != null && mounted) {
              final kg = raw / 1000;
              final now = DateTime.now();
              setState(() {
                _weight = kg;
                _lastReceived = now;
              });
              PreferencesService.saveLastWeight(kg);
              PreferencesService.saveLastReceivedTime(now);
            }
          });
          final initial = await c.read();
          final raw = double.tryParse(String.fromCharCodes(initial));
          if (raw != null && mounted) {
            final kg = raw / 1000;
            final now = DateTime.now();
            setState(() {
              _weight = kg;
              _lastReceived = now;
            });
            PreferencesService.saveLastWeight(kg);
            PreferencesService.saveLastReceivedTime(now);
          }
        }
      }
      if (mounted) {
        final now = DateTime.now();
        setState(() {
          _bleStatus = _BleStatus.connected;
          _lastConnected = now;
        });
        PreferencesService.saveLastConnectedTime(now);
      }
    } catch (e) {
      if (mounted) setState(() => _bleStatus = _BleStatus.idle);
    }
  }

  Future<void> _disconnect() async {
    _autoReconnect = false;
    _connectionSub?.cancel();
    _weightSub?.cancel();
    await _device?.disconnect();
    if (mounted) {
      setState(() {
        _bleStatus = _BleStatus.idle;
        _device = null;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(
            bleStatus: _bleStatus,
            weight: _weight,
            percentage: _percentage,
            deadWeight: _deadWeight,
            fullWeight: _fullWeight,
            warningPercent: _warningPercent,
            isWarning: _isWarning,
            lastReceived: _lastReceived,
            lastConnected: _lastConnected,
            onConnect: _startScan,
            onDisconnect: _disconnect,
          ),
          _SettingsTab(
            deadWeight: _deadWeight,
            fullWeight: _fullWeight,
            warningPercent: _warningPercent,
            onDeadWeightChanged: (v) {
              setState(() => _deadWeight = v);
              PreferencesService.saveDeadWeight(v);
            },
            onFullWeightChanged: (v) {
              setState(() => _fullWeight = v);
              PreferencesService.saveFullWeight(v);
            },
            onWarningPercentChanged: (v) {
              setState(() => _warningPercent = v);
              PreferencesService.saveWarningPercent(v);
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.brandPrimary,
          unselectedItemColor: AppColors.textTertiary,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final _BleStatus bleStatus;
  final double? weight;
  final double percentage;
  final double deadWeight;
  final double fullWeight;
  final double warningPercent;
  final bool isWarning;
  final DateTime? lastReceived;
  final DateTime? lastConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _HomeTab({
    required this.bleStatus,
    required this.weight,
    required this.percentage,
    required this.deadWeight,
    required this.fullWeight,
    required this.warningPercent,
    required this.isWarning,
    required this.lastReceived,
    required this.lastConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  String get _statusLabel => switch (bleStatus) {
        _BleStatus.idle => 'Not connected',
        _BleStatus.scanning => 'Scanning…',
        _BleStatus.connecting => 'Connecting…',
        _BleStatus.connected => 'Connected',
      };

  Color get _statusColor => switch (bleStatus) {
        _BleStatus.idle => AppColors.statusOffline,
        _BleStatus.scanning => AppColors.warning,
        _BleStatus.connecting => AppColors.brandNeutral,
        _BleStatus.connected => AppColors.statusOnline,
      };

  Color get _gaugeColor =>
      isWarning ? AppColors.brandAccentLight : AppColors.brandAccent;

  double get _netGasWeight => (weight ?? 0.0) - deadWeight;

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  String get _lastReceivedLabel =>
      lastReceived == null ? 'No data yet' : _ago(lastReceived!);

  String get _lastConnectedLabel =>
      bleStatus == _BleStatus.connected
          ? 'Now'
          : lastConnected == null
              ? 'Never'
              : _ago(lastConnected!);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool calibrated =
        fullWeight > 0 && deadWeight >= 0 && fullWeight > deadWeight;

    return Stack(
      children: [
        // ── Gradient background ──────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF012333),
                AppColors.brandPrimary,
                Color(0xFF014D6E),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // ── Decorative circle top-right ──────────────────────────────────────
        Positioned(
          top: -size.width * 0.22,
          right: -size.width * 0.18,
          child: Container(
            width: size.width * 0.68,
            height: size.width * 0.68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandSecondary.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.brandSecondary.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
        ),

        // ── Dot accents ──────────────────────────────────────────────────────
        Positioned(
          top: size.height * 0.10,
          left: size.width * 0.07,
          child: _GlowDot(color: AppColors.brandAccentLight, size: 5),
        ),
        Positioned(
          top: size.height * 0.20,
          right: size.width * 0.08,
          child: _GlowDot(color: AppColors.brandNeutral, size: 4),
        ),

        // ── Content ──────────────────────────────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 10, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GasYangu',
                            style: TextStyle(
                              color: AppColors.textOnBrand,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _statusColor.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _statusLabel,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // BLE icon button
                    if (bleStatus == _BleStatus.connected)
                      _CircleIconButton(
                        icon: Icons.bluetooth_connected_rounded,
                        color: AppColors.brandSecondary,
                        onTap: onDisconnect,
                      )
                    else if (bleStatus == _BleStatus.idle)
                      _CircleIconButton(
                        icon: Icons.bluetooth_searching_rounded,
                        color: AppColors.brandNeutral.withValues(alpha: 0.8),
                        onTap: onConnect,
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.brandNeutral,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Circular gauge ─────────────────────────────────────────────
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Gauge ring
                  SizedBox(
                    width: 186,
                    height: 186,
                    child: CircularProgressIndicator(
                      value: calibrated ? percentage / 100 : 0,
                      strokeWidth: 13,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      color: _gaugeColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  // Center content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _gaugeColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.gas_meter_outlined,
                          size: 24,
                          color: _gaugeColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Weight value
                      Text(
                        weight != null
                            ? weight!.toStringAsFixed(2)
                            : '--',
                        style: const TextStyle(
                          color: AppColors.textOnBrand,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        'kg',
                        style: TextStyle(
                          color: AppColors.brandNeutral,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bleStatus == _BleStatus.connected
                            ? 'Live reading'
                            : weight != null
                                ? 'Last known'
                                : 'No data',
                        style: TextStyle(
                          color: AppColors.brandNeutral.withValues(alpha: 0.65),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── White bottom sheet ─────────────────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 20,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Drag handle ──────────────────────────────────
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // ── Warning banner ───────────────────────────────
                        if (isWarning) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Gas below ${warningPercent.toStringAsFixed(0)}% — time to refill!',
                                    style: const TextStyle(
                                      color: Color(0xFF7A5000),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Gas level bar ────────────────────────────────
                        if (calibrated) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Gas remaining',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isWarning
                                      ? AppColors.warningLight
                                      : AppColors.brandSecondary
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  weight != null
                                      ? '${percentage.toStringAsFixed(1)}%'
                                      : '--%',
                                  style: TextStyle(
                                    color: isWarning
                                        ? AppColors.warning
                                        : AppColors.brandSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: weight != null ? percentage / 100 : 0,
                              minHeight: 10,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isWarning
                                    ? AppColors.warning
                                    : AppColors.brandSecondary,
                              ),
                            ),
                          ),
                          if (weight != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_netGasWeight > 0 ? _netGasWeight.toStringAsFixed(2) : '0.00'} kg'
                              ' of ${(fullWeight - deadWeight).toStringAsFixed(2)} kg gas left',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.brandPrimary
                                        .withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: AppColors.textTertiary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Set cylinder weights in Settings\nto see gas level.',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Timestamp chips ──────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _InfoChip(
                                icon: Icons.schedule_rounded,
                                label: 'Last reading',
                                value: _lastReceivedLabel,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InfoChip(
                                icon: Icons.bluetooth_rounded,
                                label: 'Device',
                                value: _lastConnectedLabel,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Action button ────────────────────────────────
                        if (bleStatus == _BleStatus.idle)
                          _ActionButton(
                            label: 'Scan & Connect',
                            icon: Icons.bluetooth_searching_rounded,
                            onTap: onConnect,
                          ),
                        if (bleStatus == _BleStatus.scanning ||
                            bleStatus == _BleStatus.connecting)
                          _ActionButton(
                            label: bleStatus == _BleStatus.scanning
                                ? 'Scanning for GasYangu…'
                                : 'Connecting…',
                            icon: null,
                            loading: true,
                            onTap: null,
                          ),
                        if (bleStatus == _BleStatus.connected)
                          _ActionButton(
                            label: 'Disconnect',
                            icon: Icons.bluetooth_disabled_rounded,
                            danger: true,
                            onTap: onDisconnect,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Settings tab ──────────────────────────────────────────────────────────────

class _SettingsTab extends StatefulWidget {
  final double deadWeight;
  final double fullWeight;
  final double warningPercent;
  final ValueChanged<double> onDeadWeightChanged;
  final ValueChanged<double> onFullWeightChanged;
  final ValueChanged<double> onWarningPercentChanged;

  const _SettingsTab({
    required this.deadWeight,
    required this.fullWeight,
    required this.warningPercent,
    required this.onDeadWeightChanged,
    required this.onFullWeightChanged,
    required this.onWarningPercentChanged,
  });

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _deadWeightCtrl;
  late TextEditingController _fullWeightCtrl;
  late TextEditingController _warningPercentCtrl;

  @override
  void initState() {
    super.initState();
    _deadWeightCtrl = TextEditingController(
      text: widget.deadWeight > 0 ? widget.deadWeight.toStringAsFixed(2) : '',
    );
    _fullWeightCtrl = TextEditingController(
      text: widget.fullWeight > 0 ? widget.fullWeight.toStringAsFixed(2) : '',
    );
    _warningPercentCtrl = TextEditingController(
      text: widget.warningPercent.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(_SettingsTab old) {
    super.didUpdateWidget(old);
    if (old.deadWeight != widget.deadWeight && _deadWeightCtrl.text.isEmpty) {
      _deadWeightCtrl.text =
          widget.deadWeight > 0 ? widget.deadWeight.toStringAsFixed(2) : '';
    }
    if (old.fullWeight != widget.fullWeight && _fullWeightCtrl.text.isEmpty) {
      _fullWeightCtrl.text =
          widget.fullWeight > 0 ? widget.fullWeight.toStringAsFixed(2) : '';
    }
  }

  @override
  void dispose() {
    _deadWeightCtrl.dispose();
    _fullWeightCtrl.dispose();
    _warningPercentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final dead = double.parse(_deadWeightCtrl.text);
    final full = double.parse(_fullWeightCtrl.text);
    final warn = double.parse(_warningPercentCtrl.text);
    widget.onDeadWeightChanged(dead);
    widget.onFullWeightChanged(full);
    widget.onWarningPercentChanged(warn);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Settings saved'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF012333),
                AppColors.brandPrimary,
                Color(0xFF014D6E),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Decorative circle
        Positioned(
          top: -size.width * 0.20,
          right: -size.width * 0.15,
          child: Container(
            width: size.width * 0.60,
            height: size.width * 0.60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandSecondary.withValues(alpha: 0.07),
              border: Border.all(
                color: AppColors.brandSecondary.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
          ),
        ),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Dark header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: AppColors.textOnBrand,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Configure your gas cylinder parameters.',
                      style: TextStyle(
                        color: AppColors.brandNeutral.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // ── White card ─────────────────────────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 20,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 28),
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          _sectionLabel('Cylinder Parameters'),
                          const SizedBox(height: 14),

                          _SettingField(
                            label: 'Dead weight (empty cylinder)',
                            hint: 'e.g. 14.50',
                            unit: 'kg',
                            controller: _deadWeightCtrl,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(v) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          _SettingField(
                            label: 'Full cylinder gross weight',
                            hint: 'e.g. 26.50',
                            unit: 'kg',
                            controller: _fullWeightCtrl,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final parsed = double.tryParse(v);
                              if (parsed == null) return 'Enter a valid number';
                              final dead =
                                  double.tryParse(_deadWeightCtrl.text) ?? 0;
                              if (parsed <= dead) {
                                return 'Must be greater than dead weight';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 28),
                          _sectionLabel('Alerts'),
                          const SizedBox(height: 14),

                          _SettingField(
                            label: 'Low gas warning threshold',
                            hint: 'e.g. 20',
                            unit: '%',
                            controller: _warningPercentCtrl,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final parsed = double.tryParse(v);
                              if (parsed == null) return 'Enter a valid number';
                              if (parsed < 1 || parsed > 99) {
                                return 'Must be 1 – 99';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 36),

                          _ActionButton(
                            label: 'Save Settings',
                            icon: Icons.check_rounded,
                            onTap: _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.brandAccent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SettingField extends StatelessWidget {
  final String label;
  final String hint;
  final String unit;
  final TextEditingController controller;
  final String? Function(String?) validator;

  const _SettingField({
    required this.label,
    required this.hint,
    required this.unit,
    required this.controller,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: unit,
            suffixStyle: const TextStyle(
              color: AppColors.brandSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.brandSecondary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool danger;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.danger = false,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger ? AppColors.error : AppColors.brandPrimary;
    final fg = AppColors.textOnBrand;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: onTap != null ? bg : AppColors.buttonDisabled,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else if (icon != null) ...[
                  Icon(icon, color: fg, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
      ),
    );
  }
}
