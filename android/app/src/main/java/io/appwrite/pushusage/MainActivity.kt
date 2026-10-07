package io.appwrite.pushusage

import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import io.appwrite.Client
import io.appwrite.services.Account
import io.appwrite.services.Push
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {
    private lateinit var client: Client
    private lateinit var account: Account
    private lateinit var push: Push
    private lateinit var lines: TextView
    private lateinit var exactAlarms: Button
    private lateinit var battery: Button
    private var stopOpened: (() -> Unit)? = null

    private fun log(line: String) {
        Log.i("push", line)
        runOnUiThread { lines.text = "$line\n\n${lines.text}" }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lines = TextView(this)
        val signOut = Button(this).apply {
            text = "Sign out"
            setOnClickListener { signOut() }
        }
        // Punctual wake-ups while the app is closed. Ask from a user action, never on start.
        exactAlarms = Button(this).apply {
            text = "Allow exact alarms"
            setOnClickListener { log("exact alarms asked: ${Push.requestExactAlarms(context)}") }
        }
        battery = Button(this).apply {
            text = "Ignore battery optimisation"
            setOnClickListener { log("battery exemption asked: ${Push.requestIgnoreBatteryOptimizations(context)}") }
        }
        val status = Button(this).apply {
            text = "Check background status"
            setOnClickListener { checkStatus() }
        }
        setContentView(
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(32, 32, 32, 32)
                addView(signOut)
                addView(exactAlarms)
                addView(battery)
                addView(status)
                addView(ScrollView(context).apply { addView(lines) })
            },
        )

        client = Client(applicationContext).setEndpoint(ENDPOINT).setProject(PROJECT)
        account = Account(client)
        // Created with this activity, so the notification permission is asked from this screen.
        push = Push(client, this)
            .onOpen { log("connected") }
            .onClose { log("disconnected") }
            .onError { log("error: ${it.message}") }

        // Subscribing blocks until the broker acknowledges it, so run it off the main thread.
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                start()
            } catch (e: Exception) {
                log("error: ${e.message}")
            }
        }
    }

    private suspend fun start() {
        val user = try {
            account.get()
        } catch (e: Exception) {
            account.createEmailPasswordSession(EMAIL, PASSWORD)
            account.get()
        }
        log("signed in as ${user.id}")

        push.subscribe { message -> log("message: ${message.data}") }
        log("subscribed")

        checkStatus()

        push.getInitialNotification()?.let { log("launched from notification: ${it.data}") }
        stopOpened = push.onNotificationOpened { log("notification opened: ${it.data}") }
    }

    // What background delivery can rely on; each button shows while its permission is missing.
    private fun checkStatus() {
        val status = Push.backgroundStatus(applicationContext)
        log("background: exact alarms ${status.exactAlarms}, battery exempt ${status.ignoringBatteryOptimizations}, best effort ${status.bestEffort}")
        runOnUiThread {
            exactAlarms.visibility = if (status.exactAlarms) View.GONE else View.VISIBLE
            battery.visibility = if (status.ignoringBatteryOptimizations) View.GONE else View.VISIBLE
        }
    }

    private fun signOut() {
        lifecycleScope.launch(Dispatchers.IO) {
            push.close()
            account.deleteSession("current")
            log("signed out")
        }
    }

    override fun onDestroy() {
        stopOpened?.invoke()
        super.onDestroy()
    }
}
