import 'react-native-url-polyfill/auto';
import { useEffect, useState } from 'react';
import { Button, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Account, Client, Push } from 'react-native-appwrite';

const client = new Client()
  .setEndpoint(process.env.EXPO_PUBLIC_APPWRITE_ENDPOINT!)
  .setProject(process.env.EXPO_PUBLIC_APPWRITE_PROJECT!);
const account = new Account(client);
const push = new Push(client);

async function signIn() {
  try {
    return await account.get();
  } catch {
    await account.createEmailPasswordSession({
      email: process.env.EXPO_PUBLIC_APPWRITE_EMAIL!,
      password: process.env.EXPO_PUBLIC_APPWRITE_PASSWORD!,
    });
    return await account.get();
  }
}

export default function App() {
  const [lines, setLines] = useState<string[]>([]);
  const [status, setStatus] = useState<Awaited<ReturnType<typeof push.backgroundStatus>>>(null);
  const log = (line: string) => {
    console.log('[push-usage]', line);
    setLines((prev) => [line, ...prev]);
  };

  useEffect(() => {
    let stopOpened: (() => void) | undefined;

    (async () => {
      const user = await signIn();
      log(`signed in as ${user.$id}`);

      push
        .onOpen(() => log('connected'))
        .onClose(() => log('disconnected'))
        .onError((error) => log(`error: ${error.message}`));

      await push.subscribe((message) => {
        const { notification, data } = JSON.parse(message.data);
        log(`message: ${notification?.title} ${JSON.stringify(data)}`);
      });
      log('subscribed');

      const status = await push.backgroundStatus(); // null outside Android
      if (status) log(`background: ${JSON.stringify(status)}`);
      setStatus(status);

      const opened = await push.getInitialNotification();
      if (opened) log(`launched from notification: ${JSON.stringify(opened.data)}`);

      stopOpened = push.onNotificationOpened(({ data }) => {
        log(`notification opened: ${JSON.stringify(data)}`);
      });
    })().catch((error) => log(`error: ${error.message}`));

    return () => stopOpened?.();
  }, []);

  // Android: punctual wake-ups while the app is closed. Ask from a user action, never on start.
  const allowExactAlarms = async () => {
    log(`exact alarms asked: ${await push.requestExactAlarms()}`);
  };
  const allowBattery = async () => {
    log(`battery exemption asked: ${await push.requestIgnoreBatteryOptimizations()}`);
  };
  const checkStatus = async () => {
    const current = await push.backgroundStatus();
    log(`background: ${JSON.stringify(current)}`);
    setStatus(current);
  };

  const signOut = async () => {
    push.close();
    await account.deleteSession({ sessionId: 'current' });
    log('signed out');
  };

  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Appwrite Push</Text>
      <Button title="Sign out" onPress={signOut} />
      {status && !status.exactAlarms && (
        <Button title="Allow exact alarms" onPress={allowExactAlarms} />
      )}
      {status && !status.ignoringBatteryOptimizations && (
        <Button title="Ignore battery optimisation" onPress={allowBattery} />
      )}
      <Button title="Check background status" onPress={checkStatus} />
      <ScrollView>
        {lines.map((line, i) => (
          <Text key={i} style={styles.line}>
            {line}
          </Text>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 16, paddingTop: 64, gap: 12 },
  title: { fontSize: 22, fontWeight: '600' },
  line: { fontFamily: 'monospace', paddingVertical: 4 },
});
