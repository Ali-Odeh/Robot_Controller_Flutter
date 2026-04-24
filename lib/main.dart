import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────
// Command constants (match Arduino exactly)
// ─────────────────────────────────────────
const int CMD_STOP = 0;
const int CMD_LEFT_FWD = 1;
const int CMD_FORWARD = 2;
const int CMD_RIGHT_FWD = 3;
const int CMD_SIDE_LEFT = 4;
const int CMD_SIDE_RIGHT = 5;
const int CMD_LEFT_BACK = 6;
const int CMD_BACKWARD = 7;
const int CMD_RIGHT_BACK = 8;
const int CMD_ROTATE_LEFT = 9;
const int CMD_ROTATE_RIGHT = 10;

const int CMD_SERVO1_POS = 16;
const int CMD_SERVO1_NEG = 17;
const int CMD_SERVO2_NEG = 18;
const int CMD_SERVO2_POS = 19;
const int CMD_SERVO3_POS = 20;
const int CMD_SERVO3_NEG = 21;
const int CMD_SERVO4_NEG = 22;
const int CMD_SERVO4_POS = 23;
const int CMD_SERVO5_NEG = 24;
const int CMD_SERVO5_POS = 25;
const int CMD_SERVO6_POS = 26;
const int CMD_SERVO6_NEG = 27;

const int CMD_PICKUP = 28;
const int CMD_DROP_TRASH = 29;
const int CMD_DROP_NOT_TRASH = 30;

// ─────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const RobotApp());
}

class RobotApp extends StatelessWidget {
  const RobotApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080C1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          secondary: Color(0xFF00FF88),
          surface: Color(0xFF0F1629),
        ),
      ),
      home: const ControllerScreen(),
    );
  }
}

// ─────────────────────────────────────────
class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});
  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with TickerProviderStateMixin {
  BluetoothConnection? _connection;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectedDevice = '';
  double _wheelSpeed = 65; // 30–99  → multiply ×20 on Arduino
  double _armSpeed = 175; // 100–250 → divide ÷10 on Arduino

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _requestPermissions();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _connection?.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? const Color(0xFF2B3F66),
      ),
    );
  }

  Future<bool> _ensureBluetoothReady() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    final denied = statuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key)
        .toList();

    if (denied.isNotEmpty) {
      final permanentlyDenied =
          denied.any((p) => statuses[p]!.isPermanentlyDenied);
      _showSnack(
        permanentlyDenied
            ? 'Bluetooth permissions are permanently denied. Enable them in app settings.'
            : 'Bluetooth permissions are required to connect.',
        color: Colors.red.shade800,
      );
      if (permanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    final enabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
    if (!enabled) {
      final turnedOn = await FlutterBluetoothSerial.instance.requestEnable();
      if (turnedOn != true) {
        _showSnack('Please enable Bluetooth first.',
            color: Colors.orange.shade800);
        return false;
      }
    }

    return true;
  }

  void _send(int cmd) {
    if (_connection == null || !_isConnected) return;
    try {
      _connection!.output.add(Uint8List.fromList([cmd]));
    } catch (_) {}
  }

  void _sendWheelSpeed() => _send(_wheelSpeed.round());
  void _sendArmSpeed() => _send(_armSpeed.round());

  Future<void> _connectDialog() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      final ready = await _ensureBluetoothReady();
      if (!ready || !mounted) return;

      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0F1629),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _DeviceSheet(
          devices: devices,
          onSelect: (device) async {
            Navigator.pop(context);
            try {
              final conn = await BluetoothConnection.toAddress(device.address)
                  .timeout(const Duration(seconds: 8));
              setState(() {
                _connection = conn;
                _isConnected = true;
                _connectedDevice = device.name ?? device.address;
              });
              _showSnack('Connected to ${device.name ?? device.address}',
                  color: const Color(0xFF0C5A3B));

              // Send initial speed commands
              await Future.delayed(const Duration(milliseconds: 300));
              _send(60); // wheel speed = 60×20 = 1200
              await Future.delayed(const Duration(milliseconds: 150));
              _send(102); // servo speed
            } catch (e) {
              _showSnack('Connection failed: $e', color: Colors.red.shade800);
            }
          },
        ),
      );
    } catch (e) {
      _showSnack('Connect error: $e', color: Colors.red.shade800);
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _disconnect() {
    _send(CMD_STOP);
    _connection?.dispose();
    setState(() {
      _isConnected = false;
      _connectedDevice = '';
    });
  }

  // ── UI ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildMovementPad(),
                    const SizedBox(height: 10),
                    _buildSpeedSlider(
                      label: 'PLATFORM SPEED',
                      value: _wheelSpeed,
                      min: 30,
                      max: 99,
                      color: const Color(0xFF00D4FF),
                      onChanged: (v) => setState(() => _wheelSpeed = v),
                      onChangeEnd: (_) => _sendWheelSpeed(),
                    ),
                    const SizedBox(height: 14),
                    _buildDivider('ROBOT ARM'),
                    const SizedBox(height: 8),
                    _buildArmPanel(),
                    const SizedBox(height: 10),
                    _buildSpeedSlider(
                      label: 'ARM SPEED',
                      value: _armSpeed,
                      min: 100,
                      max: 250,
                      color: const Color(0xFF00FF88),
                      onChanged: (v) => setState(() => _armSpeed = v),
                      onChangeEnd: (_) => _sendArmSpeed(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1629),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2D50), width: 1)),
      ),
      child: Row(
        children: [
          // Status dot
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected
                    ? Color.lerp(const Color(0xFF00FF88),
                        const Color(0xFF00CC66), _pulseAnim.value)!
                    : const Color(0xFF444466),
                boxShadow: _isConnected
                    ? [
                        BoxShadow(
                            color: const Color(0xFF00FF88)
                                .withOpacity(0.5 * _pulseAnim.value),
                            blurRadius: 8,
                            spreadRadius: 2)
                      ]
                    : [],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ROBOT CONTROLLER',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: Color(0xFF00D4FF),
                        fontWeight: FontWeight.w700)),
                Text(
                  _isConnected ? _connectedDevice : 'Not connected',
                  style: TextStyle(
                      fontSize: 11,
                      color: _isConnected
                          ? const Color(0xFF00FF88)
                          : const Color(0xFF445577)),
                ),
              ],
            ),
          ),
          if (_isConnected)
            _HeaderBtn(
                label: 'DISCONNECT',
                color: const Color(0xFFFF4466),
                onTap: _disconnect)
          else
            _HeaderBtn(
                label: _isConnecting ? 'CONNECTING...' : 'CONNECT',
                color: const Color(0xFF00D4FF),
                onTap: _connectDialog),
        ],
      ),
    );
  }

  Widget _buildMovementPad() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecor(),
      child: Column(
        children: [
          _buildDivider('MOVEMENT'),
          const SizedBox(height: 12),
          // Row: LeftFwd · Forward · RightFwd
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _DirBtn(
                icon: Icons.north_west,
                cmd: CMD_LEFT_FWD,
                send: _send,
                size: 56),
            const SizedBox(width: 8),
            _DirBtn(
                icon: Icons.arrow_upward,
                cmd: CMD_FORWARD,
                send: _send,
                size: 68,
                color: const Color(0xFF00D4FF)),
            const SizedBox(width: 8),
            _DirBtn(
                icon: Icons.north_east,
                cmd: CMD_RIGHT_FWD,
                send: _send,
                size: 56),
          ]),
          const SizedBox(height: 8),
          // Row: SideLeft · [RotL · RotR] · SideRight
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _DirBtn(
                icon: Icons.arrow_back,
                cmd: CMD_SIDE_LEFT,
                send: _send,
                size: 68,
                color: const Color(0xFF00D4FF)),
            const SizedBox(width: 8),
            Column(children: [
              _DirBtn(
                  icon: Icons.rotate_left,
                  cmd: CMD_ROTATE_LEFT,
                  send: _send,
                  size: 48,
                  color: const Color(0xFFFFAA00)),
              const SizedBox(height: 6),
              _DirBtn(
                  icon: Icons.rotate_right,
                  cmd: CMD_ROTATE_RIGHT,
                  send: _send,
                  size: 48,
                  color: const Color(0xFFFFAA00)),
            ]),
            const SizedBox(width: 8),
            _DirBtn(
                icon: Icons.arrow_forward,
                cmd: CMD_SIDE_RIGHT,
                send: _send,
                size: 68,
                color: const Color(0xFF00D4FF)),
          ]),
          const SizedBox(height: 8),
          // Row: LeftBack · Backward · RightBack
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _DirBtn(
                icon: Icons.south_west,
                cmd: CMD_LEFT_BACK,
                send: _send,
                size: 56),
            const SizedBox(width: 8),
            _DirBtn(
                icon: Icons.arrow_downward,
                cmd: CMD_BACKWARD,
                send: _send,
                size: 68,
                color: const Color(0xFF00D4FF)),
            const SizedBox(width: 8),
            _DirBtn(
                icon: Icons.south_east,
                cmd: CMD_RIGHT_BACK,
                send: _send,
                size: 56),
          ]),
        ],
      ),
    );
  }

  Widget _buildArmPanel() {
    final joints = [
      (
        'WAIST',
        CMD_SERVO1_NEG,
        CMD_SERVO1_POS,
        Icons.rotate_left,
        Icons.rotate_right
      ),
      (
        'SHOULDER',
        CMD_SERVO2_NEG,
        CMD_SERVO2_POS,
        Icons.keyboard_arrow_down,
        Icons.keyboard_arrow_up
      ),
      (
        'ELBOW',
        CMD_SERVO3_NEG,
        CMD_SERVO3_POS,
        Icons.keyboard_arrow_down,
        Icons.keyboard_arrow_up
      ),
      (
        'WRIST ROLL',
        CMD_SERVO4_NEG,
        CMD_SERVO4_POS,
        Icons.rotate_left,
        Icons.rotate_right
      ),
      (
        'WRIST PITCH',
        CMD_SERVO5_NEG,
        CMD_SERVO5_POS,
        Icons.keyboard_arrow_down,
        Icons.keyboard_arrow_up
      ),
      (
        'GRIPPER',
        CMD_SERVO6_NEG,
        CMD_SERVO6_POS,
        Icons.open_in_full,
        Icons.close_fullscreen
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecor(accent: const Color(0xFF00FF88)),
      child: Column(
        children: joints.map((j) {
          final (label, negCmd, posCmd, negIcon, posIcon) = j;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: Color(0xFF8899BB),
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                _ServoBtn(icon: negIcon, cmd: negCmd, send: _send),
                const SizedBox(width: 10),
                _ServoBtn(icon: posIcon, cmd: posCmd, send: _send),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpeedSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _panelDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: color,
                      fontWeight: FontWeight.w700)),
              Text('${value.round()}',
                  style: TextStyle(
                      fontSize: 14, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Row(children: [
      Expanded(child: Container(height: 1, color: const Color(0xFF1E2D50))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                letterSpacing: 2.5,
                color: Color(0xFF445577),
                fontWeight: FontWeight.w700)),
      ),
      Expanded(child: Container(height: 1, color: const Color(0xFF1E2D50))),
    ]);
  }

  BoxDecoration _panelDecor({Color? accent}) {
    return BoxDecoration(
      color: const Color(0xFF0F1629),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: (accent ?? const Color(0xFF00D4FF)).withOpacity(0.15),
          width: 1),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4))
      ],
    );
  }
}

// ─────────────────────────────────────────
// Direction Button — hold to move, release to stop
// ─────────────────────────────────────────
class _DirBtn extends StatefulWidget {
  final IconData icon;
  final int cmd;
  final void Function(int) send;
  final double size;
  final Color color;

  const _DirBtn({
    required this.icon,
    required this.cmd,
    required this.send,
    required this.size,
    this.color = const Color(0xFF1E3060),
  });

  @override
  State<_DirBtn> createState() => _DirBtnState();
}

class _DirBtnState extends State<_DirBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.send(widget.cmd);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.send(CMD_STOP);
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        widget.send(CMD_STOP);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _pressed
              ? widget.color.withOpacity(0.9)
              : widget.color.withOpacity(0.15),
          border: Border.all(
              color: _pressed ? widget.color : widget.color.withOpacity(0.3),
              width: 1.5),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                      color: widget.color.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Icon(widget.icon,
            color: _pressed ? Colors.white : widget.color.withOpacity(0.8),
            size: widget.size * 0.42),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Servo Button — hold to move continuously
// ─────────────────────────────────────────
class _ServoBtn extends StatefulWidget {
  final IconData icon;
  final int cmd;
  final void Function(int) send;

  const _ServoBtn({required this.icon, required this.cmd, required this.send});

  @override
  State<_ServoBtn> createState() => _ServoBtnState();
}

class _ServoBtnState extends State<_ServoBtn> {
  bool _pressed = false;
  Timer? _timer;

  void _start() {
    setState(() => _pressed = true);
    widget.send(widget.cmd);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      widget.send(widget.cmd);
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() => _pressed = false);
    widget.send(CMD_STOP);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 54,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _pressed
              ? const Color(0xFF00FF88).withOpacity(0.25)
              : const Color(0xFF0F2030),
          border: Border.all(
              color:
                  _pressed ? const Color(0xFF00FF88) : const Color(0xFF1E3A50),
              width: 1.2),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                      color: const Color(0xFF00FF88).withOpacity(0.3),
                      blurRadius: 8)
                ]
              : [],
        ),
        child: Icon(widget.icon,
            color: _pressed ? const Color(0xFF00FF88) : const Color(0xFF4466AA),
            size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Header button
// ─────────────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.6), width: 1.2),
          color: color.withOpacity(0.08),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: color,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Device selection sheet
// ─────────────────────────────────────────
class _DeviceSheet extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final void Function(BluetoothDevice) onSelect;

  const _DeviceSheet({required this.devices, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELECT DEVICE',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 3,
                  color: Color(0xFF00D4FF),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (devices.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No paired devices found.\nPair HC-05 in Bluetooth settings first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF445577)),
                ),
              ),
            )
          else
            ...devices.map((d) => ListTile(
                  onTap: () => onSelect(d),
                  leading:
                      const Icon(Icons.bluetooth, color: Color(0xFF00D4FF)),
                  title: Text(d.name ?? 'Unknown',
                      style: const TextStyle(color: Color(0xFFCCDDEE))),
                  subtitle: Text(d.address,
                      style: const TextStyle(
                          color: Color(0xFF445577), fontSize: 11)),
                  trailing:
                      const Icon(Icons.chevron_right, color: Color(0xFF445577)),
                )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
