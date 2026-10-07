import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

import 'config.dart';

final client = Client().setEndpoint(endpoint).setProject(project);
final account = Account(client);
final push = Push(client);

void main() => runApp(const MaterialApp(home: PushScreen()));

class PushScreen extends StatefulWidget {
  const PushScreen({super.key});

  @override
  State<PushScreen> createState() => _PushScreenState();
}

class _PushScreenState extends State<PushScreen> {
  final lines = <String>[];
  void Function()? stopOpened;
  PushBackgroundStatus? status;

  void log(String line) {
    debugPrint('[push] $line');
    if (mounted) setState(() => lines.insert(0, line));
  }

  @override
  void initState() {
    super.initState();
    start().catchError((Object e) => log('error: $e'));
  }

  @override
  void dispose() {
    stopOpened?.call();
    super.dispose();
  }

  Future<void> start() async {
    try {
      await account.get();
    } catch (_) {
      await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
    }
    final user = await account.get();
    log('signed in as ${user.$id}');

    push
        .onOpen(() => log('connected'))
        .onClose(() => log('disconnected'))
        .onError((e) => log('error: $e'));

    await push.subscribe(null, (message) {
      final body = jsonDecode(message.data) as Map<String, dynamic>;
      log(
        'message: ${body['notification']?['title']} ${jsonEncode(body['data'])}',
      );
    });
    log('subscribed');

    await checkStatus();

    final opened = await push.getInitialNotification();
    if (opened != null) {
      log('launched from notification: ${jsonEncode(opened.data)}');
    }

    stopOpened = push.onNotificationOpened(
      (opened) => log('notification opened: ${jsonEncode(opened.data)}'),
    );
  }

  // Android: what background delivery can rely on. Null on other platforms.
  Future<void> checkStatus() async {
    final current = await push.backgroundStatus();
    if (current != null) {
      log(
        'background: exact alarms ${current.exactAlarms}, battery exempt '
        '${current.ignoringBatteryOptimizations}, best effort ${current.bestEffort}',
      );
    }
    if (mounted) setState(() => status = current);
  }

  // Android: punctual wake-ups while the app is closed. Ask from a user action, never on start.
  Future<void> allowExactAlarms() async =>
      log('exact alarms asked: ${await push.requestExactAlarms()}');

  Future<void> allowBattery() async => log(
    'battery exemption asked: ${await push.requestIgnoreBatteryOptimizations()}',
  );

  Future<void> signOut() async {
    push.close();
    await account.deleteSession(sessionId: 'current');
    log('signed out');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Appwrite Push')),
    body: Column(
      children: [
        TextButton(onPressed: signOut, child: const Text('Sign out')),
        if (status != null && !status!.exactAlarms)
          TextButton(
            onPressed: allowExactAlarms,
            child: const Text('Allow exact alarms'),
          ),
        if (status != null && !status!.ignoringBatteryOptimizations)
          TextButton(
            onPressed: allowBattery,
            child: const Text('Ignore battery optimisation'),
          ),
        TextButton(
          onPressed: checkStatus,
          child: const Text('Check background status'),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final line in lines)
                ListTile(dense: true, title: Text(line)),
            ],
          ),
        ),
      ],
    ),
  );
}
