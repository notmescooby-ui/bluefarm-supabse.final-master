import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_data.dart';

class AppProvider extends ChangeNotifier {
  Future<void> loadAllData() async {
    await initializeData();
  }
  
  Future<void> updateProfile(Map<String, dynamic> data) async {
    await updateUserProfile(data);
  }

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  SensorData? _latestReading;
  SensorData? get latestReading => _latestReading;

  List<SensorData> _todayReadings = [];
  List<SensorData> get todayReadings => _todayReadings;

  Map<String, dynamic> _deviceStatus = {};
  Map<String, dynamic> get deviceStatus => _deviceStatus;

  int get motorASpeed => _deviceStatus['motor_a'] == true ? 255 : 0;
  int get motorBSpeed => _deviceStatus['motor_b'] == true ? 255 : 0;
  int get servoAngle => _deviceStatus['feeder_angle'] as int? ?? 0;
  bool get isFeederOn => (_deviceStatus['feeder_on'] == true) || ((_deviceStatus['feeder_angle'] as int? ?? 0) > 0);
  bool get isFeederAutoMode => _deviceStatus['feeder_auto_mode'] as bool? ?? true;
  double get hopperLevel => (_deviceStatus['hopper_level'] as num?)?.toDouble() ?? 85.0;

  final List<Map<String, dynamic>> _feedingSchedules = [
    {'id': '1', 'time': '07:30 AM', 'amount': 1.5, 'label': 'Morning Feed', 'enabled': true},
    {'id': '2', 'time': '12:30 PM', 'amount': 2.0, 'label': 'Midday Feed', 'enabled': true},
    {'id': '3', 'time': '05:30 PM', 'amount': 1.5, 'label': 'Evening Feed', 'enabled': true},
  ];
  List<Map<String, dynamic>> get feedingSchedules => _feedingSchedules;

  final List<Map<String, dynamic>> _feedingLogs = [
    {'time': 'Today, 12:30 PM', 'amount': '2.0 kg', 'mode': 'Automated', 'status': 'Success'},
    {'time': 'Today, 07:30 AM', 'amount': '1.5 kg', 'mode': 'Automated', 'status': 'Success'},
    {'time': 'Yesterday, 05:30 PM', 'amount': '1.5 kg', 'mode': 'Manual', 'status': 'Success'},
  ];
  List<Map<String, dynamic>> get feedingLogs => _feedingLogs;

  Future<void> updateMotorA(int speed) async {
    await updateMotorSpeed('a', speed);
  }

  Future<void> updateMotorB(int speed) async {
    await updateMotorSpeed('b', speed);
  }

  Future<void> updateServo(int angle) async {
    await updateServoAngle(angle);
  }

  Future<void> turnOnFeeder() async {
    _deviceStatus['feeder_on'] = true;
    _deviceStatus['feeder_angle'] = 90;
    if (_feedingLogs.isEmpty || _feedingLogs.first['status'] != 'Active') {
      _feedingLogs.insert(0, {
        'time': 'Just now',
        'amount': 'Dispensing...',
        'mode': 'Manual Direct',
        'status': 'Active',
      });
    }
    double currentLevel = hopperLevel;
    if (currentLevel > 0.5) {
      _deviceStatus['hopper_level'] = (currentLevel - 0.5).clamp(0.0, 100.0);
    }
    notifyListeners();
  }

  Future<void> turnOffFeeder() async {
    _deviceStatus['feeder_on'] = false;
    _deviceStatus['feeder_angle'] = 0;
    if (_feedingLogs.isNotEmpty && _feedingLogs.first['status'] == 'Active') {
      _feedingLogs[0] = {
        'time': 'Just now',
        'amount': '1.0 kg',
        'mode': 'Manual Direct',
        'status': 'Success',
      };
    }
    notifyListeners();
  }

  Future<void> toggleFeederAutoMode(bool enabled) async {
    _deviceStatus['feeder_auto_mode'] = enabled;
    notifyListeners();
  }

  Future<void> addFeedingSchedule(String label, String time, double amount) async {
    _feedingSchedules.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'label': label,
      'time': time,
      'amount': amount,
      'enabled': true,
    });
    notifyListeners();
  }

  Future<void> toggleSchedule(int index, bool enabled) async {
    if (index >= 0 && index < _feedingSchedules.length) {
      _feedingSchedules[index]['enabled'] = enabled;
      notifyListeners();
    }
  }

  Future<void> removeSchedule(int index) async {
    if (index >= 0 && index < _feedingSchedules.length) {
      _feedingSchedules.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> refillHopper() async {
    _deviceStatus['hopper_level'] = 100.0;
    notifyListeners();
  }


  
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  bool _isDeviceConnected = false;
  bool get isDeviceConnected => _isDeviceConnected;
  Future<void> setDeviceConnected(bool val) async {
    _isDeviceConnected = val;
    notifyListeners();
  }

  StreamSubscription? _sensorSubscription;

  Future<void> initializeData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final data = await Supabase.instance.client.from('profiles').select().eq('id', uid).maybeSingle();
        _userProfile = data;
      }
      
      // Stubbing IoT data
      _latestReading = SensorData(createdAt: DateTime.now(), ph: 7.2, temperature: 28.5, turbidity: 2.5);
      _todayReadings = [_latestReading!];
      _deviceStatus = {'motor_a': false, 'motor_b': false, 'feeder_angle': 0};
      
      _startSensorWatch();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startSensorWatch() {
    _sensorSubscription?.cancel();
    // Use dummy stream for now
    _sensorSubscription = Stream.periodic(const Duration(seconds: 10)).listen((_) {
      _latestReading = SensorData(createdAt: DateTime.now(), ph: 7.2, temperature: 28.0 + (DateTime.now().second % 10) / 10, turbidity: 2.5);
      notifyListeners();
    });
  }

  Future<void> updateMotorSpeed(String motor, int speed) async {
    _deviceStatus['motor_'] = speed > 0;
    notifyListeners();
  }

  Future<void> updateServoAngle(int angle) async {
    _deviceStatus['feeder_angle'] = angle;
    notifyListeners();
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      await Supabase.instance.client.from('profiles').update(data).eq('id', uid);
      _userProfile = { ...?_userProfile, ...data };
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    super.dispose();
  }
}
