// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus_example/utils/extra.dart';
import 'package:flutter_blue_plus_example/utils/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/bluetooth_off_screen.dart';
import 'screens/scan_screen.dart';

void main() {
  FlutterBluePlus.setOptions(restoreState: true);
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);

  runApp(const FlutterBlueApp());
}

//
// This widget shows BluetoothOffScreen or
// ScanScreen depending on the adapter state
//
class FlutterBlueApp extends StatefulWidget {
  const FlutterBlueApp({super.key});

  @override
  State<FlutterBlueApp> createState() => _FlutterBlueAppState();
}

class _FlutterBlueAppState extends State<FlutterBlueApp> with WidgetsBindingObserver {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;
  final notificationService = LocalNotificationService();

  @override
  void initState() {
    super.initState();
    setupBle();
  }

  @override
  void didHaveMemoryPressure() {
    print('didHaveMemoryPressure');
    notificationService.showNotification(title: 'Memory Warning', body: '');
  }

  Future<void> start() async {
    final sharedPref = await SharedPreferences.getInstance();
    final remoteId = sharedPref.getString('lastConnected');

    if (remoteId == null) {
      return;
    }

    final peripherals = await FlutterBluePlus.retrievePeripherals([remoteId]);

    if (peripherals.isEmpty) {
      print("No saved peripherals found for $remoteId. Starting scan...");
      notificationService.showNotification(title: 'adapterState-poweredOn', body: "Starting scan...");
      FlutterBluePlus.startScan(timeout: null, withRemoteIds: [remoteId]);

      return;
    }

    for (final peripheral in peripherals) {
      print("Found saved peripheral, connecting: ${peripheral.remoteId}");
      notificationService.showNotification(
          title: 'adapterState-poweredOn', body: "Found previously connected peripheral, try connecting");
      peripheral.connect(timeout: null);
    }
  }

  Future<void> setupBle() async {
    notificationService.init();

    _adapterStateStateSubscription = FlutterBluePlus.adapterState.listen((state) async {
      _adapterState = state;
      if (mounted) {
        setState(() {});
      }

      if (state == BluetoothAdapterState.on) {
        await start();
      } else {
        notificationService.showNotification(title: 'adapterState', body: state.name);
      }
    });

    FlutterBluePlus.events.onWillRestoreState.listen((event) {
      notificationService.showNotification(title: 'onWillRestoreState', body: event.devices.toString());
      debugPrint('onWillRestoreState:: ${event.devices.toString()}');
    });

    FlutterBluePlus.onScanResults.listen((event) async {
      final peripherals = event.map((e) => e.device).toList();
      final peripheralIds = peripherals.map((e) => e.remoteId.str);

      debugPrint("onScanResults: $peripheralIds");

      final sharedPref = await SharedPreferences.getInstance();
      final remoteId = sharedPref.getString('lastConnected');

      if (remoteId == null) {
        return;
      }

      if (!peripheralIds.contains(remoteId)) {
        return;
      }

      for (final peripheral in peripherals) {
        if (peripheral.remoteId.str == remoteId && !peripheral.isConnected) {
          notificationService.showNotification(
              title: 'onScanResults stopScan $remoteId', body: "connectAndUpdateStream");
          FlutterBluePlus.stopScan();
          peripheral.connect(timeout: null);
        }
      }
    });

    FlutterBluePlus.events.onConnectionStateChanged.listen((e) async {
      final deviceName = e.device.advName.isNotEmpty ? e.device.advName : e.device.remoteId.str;
      if (e.connectionState == BluetoothConnectionState.connected) {
        notificationService.showNotification(
          title: 'connected',
          body: 'Connected to $deviceName',
        );
      } else if (e.connectionState == BluetoothConnectionState.disconnected) {
        final sharedPref = await SharedPreferences.getInstance();
        final remoteId = sharedPref.getString('lastConnected');

        if (remoteId != null) {
          notificationService.showNotification(
            title: 'disconnected, startScan',
            body: 'Disconnected from $deviceName',
          );

          // Optionally try reconnecting or notify user
          // FlutterBluePlus.startScan(timeout: null);
          await e.device.connect(timeout: null);
        } else {
          notificationService.showNotification(
            title: 'disconnected',
            body: 'Disconnected from $deviceName',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screen = _adapterState == BluetoothAdapterState.on
        ? const ScanScreen()
        : BluetoothOffScreen(adapterState: _adapterState);

    return MaterialApp(
      color: Colors.lightBlue,
      debugShowCheckedModeBanner: false,
      home: screen,
      navigatorObservers: [BluetoothAdapterStateObserver()],
    );
  }
}

//
// This observer listens for Bluetooth Off and dismisses the DeviceScreen
//
class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/DeviceScreen') {
      // Start listening to Bluetooth state changes when a new route is pushed
      _adapterStateSubscription ??= FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) {
          // Pop the current route if Bluetooth is off
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // Cancel the subscription when the route is popped
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}
