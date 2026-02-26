package com.example.ai_kiosk_pos

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.nfc.NfcAdapter
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.ai_kiosk_pos.BuildConfig
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.stripe.stripeterminal.Terminal
import com.stripe.stripeterminal.external.callable.Callback
import com.stripe.stripeterminal.external.callable.Cancelable
import com.stripe.stripeterminal.external.callable.ConnectionTokenCallback
import com.stripe.stripeterminal.external.callable.ConnectionTokenProvider
import com.stripe.stripeterminal.external.callable.DiscoveryListener
import com.stripe.stripeterminal.external.callable.PaymentIntentCallback
import com.stripe.stripeterminal.external.callable.ReaderCallback
import com.stripe.stripeterminal.external.callable.TerminalListener
import com.stripe.stripeterminal.external.models.CollectPaymentIntentConfiguration
import com.stripe.stripeterminal.external.models.ConnectionConfiguration
import com.stripe.stripeterminal.external.models.ConnectionStatus
import com.stripe.stripeterminal.external.models.ConnectionTokenException
import com.stripe.stripeterminal.external.models.DiscoveryConfiguration
import com.stripe.stripeterminal.external.models.PaymentIntent
import com.stripe.stripeterminal.external.models.PaymentStatus
import com.stripe.stripeterminal.external.models.Reader
import com.stripe.stripeterminal.external.models.TerminalException
import com.stripe.stripeterminal.external.OfflineMode
import com.stripe.stripeterminal.log.LogLevel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity(), TerminalListener {

  private val channelName = "kiosk.stripe.terminal"
  private val tapToPayTimeoutMs = 120_000L
  private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  
  // HTTP timeout optimization (Tier 1 optimization)
  private val httpTimeoutConnectMs = 10_000L  // 10 seconds
  private val httpTimeoutReadMs = 15_000L     // 15 seconds
  private val httpTimeoutWriteMs = 15_000L    // 15 seconds
  
  private val httpClient = OkHttpClient.Builder()
    .connectTimeout(httpTimeoutConnectMs, TimeUnit.MILLISECONDS)
    .readTimeout(httpTimeoutReadMs, TimeUnit.MILLISECONDS)
    .writeTimeout(httpTimeoutWriteMs, TimeUnit.MILLISECONDS)
    .build()

  // Mutable URL for the deferred token provider — set when eagerPrepare/prepareTapToPay/startTapToPay provides it
  @Volatile private var tokenProviderUrl: String? = null

  // Deferred token provider: Terminal.init() is called at startup with this.
  // Actual token fetching only happens when the SDK needs one (during discoverReaders etc.)
  private val deferredTokenProvider = object : ConnectionTokenProvider {
    override fun fetchConnectionToken(callback: ConnectionTokenCallback) {
      val url = tokenProviderUrl
      if (url == null) {
        callback.onFailure(ConnectionTokenException("Terminal base URL not configured yet"))
        return
      }
      activityScope.launch(Dispatchers.IO) {
        try {
          val body = "{}".toRequestBody("application/json".toMediaType())
          val req = Request.Builder().url("$url/terminal/connection_token").post(body).build()
          val secret = httpClient.newCall(req).execute().use {
            if (!it.isSuccessful) throw Exception("HTTP ${it.code}")
            JSONObject(it.body?.string() ?: "").getString("secret")
          }
          withContext(Dispatchers.Main) { callback.onSuccess(secret) }
        } catch (e: Exception) {
          withContext(Dispatchers.Main) { callback.onFailure(ConnectionTokenException(e.message ?: "Failed", e)) }
        }
      }
    }
  }

  private val mainHandler = Handler(Looper.getMainLooper())
  private val isProcessing = AtomicBoolean(false)
  private val isConnectingReader = AtomicBoolean(false)
  
  private var discoveryCancelable: Cancelable? = null
  private var currentPaymentCancelable: Cancelable? = null
  
  private var pendingResult: MethodChannel.Result? = null
  private var terminalBaseUrl: String? = null
  private var paymentTimeoutRunnable: Runnable? = null
  private var ttpActivityLaunched = false

  private var pendingPermissionGranted: (() -> Unit)? = null
  private var pendingPermissionDenied: (() -> Unit)? = null
  private var pendingMicrophoneResult: MethodChannel.Result? = null

  private val locationPermissions = arrayOf(
    Manifest.permission.ACCESS_FINE_LOCATION,
    Manifest.permission.ACCESS_COARSE_LOCATION
  )
  private val locationPermissionRequestCode = 1001
  private val microphonePermissionRequestCode = 1002
  private val eagerPermissionRequestCode = 1003

  // Cached config for eager prepare (used after permission grant)
  private var eagerPrepareConfig: Triple<String, String, Boolean>? = null

  private var methodChannel: MethodChannel? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
    methodChannel = channel
    channel.setMethodCallHandler { call, result ->
      val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
      when (call.method) {
        "startTapToPay"   -> startTapToPay(args, result)
        "prepareTapToPay" -> prepareTapToPay(args, result)
        "requestMicrophonePermission" -> requestMicrophonePermission(result)
        "getNfcStatus"    -> getNfcStatus(result)
        "openNfcSettings" -> { openNfcSettings(); result.success(true) }
        "prewarmupNfc"    -> prewarmupNfc(args, result)
        "eagerPrepare"   -> eagerPrepare(args, result)
        else              -> result.notImplemented()
      }
    }
    
    // Pre-initialize Terminal SDK at startup for fastest possible first payment.
    // Uses deferred token provider — URL is set later by eagerPrepare or payment request.
    if (!Terminal.isInitialized()) {
      try {
        @Suppress("OPT_IN_USAGE")
        @OptIn(OfflineMode::class)
        Terminal.init(applicationContext, LogLevel.VERBOSE, deferredTokenProvider, this, null)
        Log.d("StripeTerminal", "Terminal pre-initialized at startup ✅")
      } catch (e: Exception) {
        Log.e("StripeTerminal", "Early Terminal init failed: ${e.message}")
      }
    }

    // Start NFC prewarmup in background when activity is created
    activityScope.launch {
      try {
        prewarmupNfcInBackground()
      } catch (e: Exception) {
        Log.w("StripeTerminal", "NFC prewarmup on startup failed (non-critical): ${e.message}")
      }
    }
  }

  private fun sendProgress(step: Int, message: String) {
    mainHandler.post {
      methodChannel?.invokeMethod("onTtpProgress", mapOf("step" to step, "message" to message))
    }
  }

  /**
   * Pre-request all permissions at Activity startup for maximum payment speed.
   * By the time the user hits "Pay", permissions are already granted.
   */
  override fun onStart() {
    super.onStart()
    val needed = mutableListOf<String>()
    locationPermissions.forEach { perm ->
      if (ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED) {
        needed.add(perm)
      }
    }
    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      needed.add(Manifest.permission.RECORD_AUDIO)
    }
    if (needed.isNotEmpty()) {
      Log.d("StripeTerminal", "Pre-requesting ${needed.size} permission(s) at startup")
      ActivityCompat.requestPermissions(this, needed.toTypedArray(), eagerPermissionRequestCode)
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    activityScope.cancel()
    httpClient.dispatcher.executorService.shutdown()
  }

  override fun onUserLeaveHint() {
    super.onUserLeaveHint()
    if (ttpActivityLaunched) return
    if (!isProcessing.get()) return

    // Try to cancel the active collect-payment operation.
    // The cancel callback (or the normal payment callback — whichever fires
    // first) will deliver the result to Flutter via finishWithError/Success.
    // We must NOT call finishWithError here directly because the SDK may
    // still fire its own callback, leading to a double-delivery crash.
    val cancelable = currentPaymentCancelable
    if (cancelable != null && !cancelable.isCompleted) {
      cancelable.cancel(object : Callback {
        // Cancel succeeded → SDK won't fire the payment callback, so we
        // are the ones responsible for delivering the result.
        override fun onSuccess() {
          finishWithError("PAYMENT_CANCELLED", "Payment cancelled — app minimized", null)
        }
        // Cancel failed (payment already completed or confirmed).
        // The normal payment callback will handle the result, so do nothing.
        override fun onFailure(e: TerminalException) {
          Log.d("StripeTerminal", "Cancel after minimize failed (already completed): ${e.message}")
          // Don't call finishWithError — let the payment callback deliver.
        }
      })
    } else {
      // No active cancelable (still in discover/connect phase or already done).
      // Safe to clean up directly.
      finishWithError("PAYMENT_CANCELLED", "Payment cancelled — app minimized", null)
    }
  }

  private fun checkDeviceCapability(): Pair<String, String>? {
    val nfc = NfcAdapter.getDefaultAdapter(this)
    if (nfc == null) return "NFC_UNSUPPORTED" to "No NFC hardware"
    if (!nfc.isEnabled)  return "NFC_DISABLED"   to "NFC disabled"
    val gms = GoogleApiAvailability.getInstance()
    val res = gms.isGooglePlayServicesAvailable(this)
    if (res != ConnectionResult.SUCCESS) return "TAP_TO_PAY_INSECURE_ENVIRONMENT" to "No Google Play Services"
    return null
  }

  private fun prepareTapToPay(args: Map<*, *>, result: MethodChannel.Result) {
    val baseUrl    = args["terminalBaseUrl"] as? String ?: return result.error("INVALID_ARGS", "No URL", null)
    val locationId = args["locationId"] as? String ?: return result.error("INVALID_ARGS", "No LocId", null)
    val isSimulated = args["isSimulated"] as? Boolean ?: BuildConfig.DEBUG

    val url = normalizeBaseUrl(baseUrl)
    terminalBaseUrl = url
    sendProgress(0, "Initializing...")

    ensureTerminalInitialized(url) {
      val terminal = Terminal.getInstance()
      if (terminal.connectedReader != null) {
        sendProgress(3, "Ready!")
        return@ensureTerminalInitialized result.success(mapOf("status" to "READY"))
      }

      if (isConnectingReader.get()) {
        // Eager init is already connecting — wait for it to finish
        awaitReaderConnection(
          onConnected = {
            sendProgress(3, "Ready!")
            result.success(mapOf("status" to "READY"))
          },
          onTimeout = {
            // Eager connect didn't finish in time — return READY anyway
            // startTapToPay will handle connection via ensureReaderConnected
            result.success(mapOf("status" to "READY", "warning" to "Reader not yet connected"))
          }
        )
        return@ensureTerminalInitialized
      }
      isConnectingReader.set(true)

      ensureLocationPermission(
        onGranted = {
          if (!isLocationServicesEnabled()) {
            isConnectingReader.set(false)
            return@ensureLocationPermission result.error("LOCATION_SERVICES_DISABLED", "Enable Location", null)
          }

          sendProgress(1, "Connecting...")
          
          val config = DiscoveryConfiguration.TapToPayDiscoveryConfiguration(isSimulated)

          discoveryCancelable = terminal.discoverReaders(config, object : DiscoveryListener {
            override fun onUpdateDiscoveredReaders(readers: List<Reader>) {
              val reader = readers.firstOrNull()
              if (reader != null) {
                // Cancel discovery to connect
                discoveryCancelable?.cancel(object : Callback {
                  override fun onSuccess() {
                    discoveryCancelable = null
                    retryConnectReader(reader, locationId, result, true)
                  }
                  override fun onFailure(e: TerminalException) {
                    discoveryCancelable = null
                    retryConnectReader(reader, locationId, result, true) // Try anyway
                  }
                })
              }
            }
          }, object : Callback {
            override fun onSuccess() {}
            override fun onFailure(e: TerminalException) {
              isConnectingReader.set(false)
              discoveryCancelable = null
              result.success(mapOf("status" to "READY", "warning" to "Discovery failed: ${e.message}"))
            }
          })
        },
        onDenied = {
          isConnectingReader.set(false)
          result.error("LOCATION_PERMISSION_DENIED", "Denied", null)
        }
      )
    }
  }

  /**
   * Retry connection with exponential backoff.
   * Improves reliability on unstable connections by auto-retrying transient failures.
   */
  private fun retryConnectReader(
      reader: Reader,
      locationId: String,
      result: MethodChannel.Result?,
      isPrepare: Boolean,
      maxRetries: Int = 2,
      delayMs: Long = 500
  ) {
    sendProgress(2, "Downloading...")
    var currentDelay = delayMs
    var attemptCount = 0

    fun attemptConnect() {
      attemptCount++
      val config = ConnectionConfiguration.TapToPayConnectionConfiguration(
        locationId,
        autoReconnectOnUnexpectedDisconnect = true,
        tapToPayReaderListener = null
      )
      
      Terminal.getInstance().connectReader(reader, config, object : ReaderCallback {
        override fun onSuccess(reader: Reader) {
          isConnectingReader.set(false)
          sendProgress(3, "Ready!")
          result?.success(mapOf("status" to "READY"))
        }

        override fun onFailure(e: TerminalException) {
          if (attemptCount < maxRetries) {
            Log.w("StripeTerminal", "Connection attempt $attemptCount failed: ${e.message}, retrying in ${currentDelay}ms")
            mainHandler.postDelayed({
              currentDelay *= 2  // Exponential backoff
              attemptConnect()
            }, currentDelay)
          } else {
            isConnectingReader.set(false)
            sendProgress(3, "Ready (warning)")
            if (isPrepare) {
              result?.success(mapOf("status" to "READY", "warning" to "Connection retries exhausted: ${e.errorMessage}"))
            } else {
              result?.error("CONNECT_FAILED", "Connection failed after $maxRetries retries: ${e.errorMessage}", null)
            }
          }
        }
      })
    }

    attemptConnect()
  }

  private fun startTapToPay(args: Map<*, *>, result: MethodChannel.Result) {
    if (isProcessing.getAndSet(true)) return result.error("BUSY", "In progress", null)
    pendingResult = result
    schedulePaymentTimeout()
    
    checkDeviceCapability()?.let { (c, m) -> return finishWithError(c, m, null) }
    
    val secret  = args["clientSecret"] as? String
    val locId   = args["locationId"] as? String
    val url     = args["terminalBaseUrl"] as? String
    val orderId = args["orderId"] as? String
    val isSim = args["isSimulated"] as? Boolean ?: false

    if (secret == null || url == null || locId == null) return finishWithError("INVALID_ARGS", "Missing params", null)

    val nUrl = normalizeBaseUrl(url)
    terminalBaseUrl = nUrl

    ensureTerminalInitialized(nUrl) {
      val terminal = Terminal.getInstance()

      // FAST PATH: Reader already connected → just retrieve and process
      if (terminal.connectedReader != null) {
        retrieveAndProcess(secret, orderId)
        return@ensureTerminalInitialized
      }

      // PARALLEL PATH: Start retrieve PI + connect reader simultaneously
      // retrievePaymentIntent only needs Terminal initialized (not a reader)
      // This overlaps the 1-2s retrieve with the 3-5s discover+connect
      var retrievedIntent: PaymentIntent? = null
      var retrieveFailed: TerminalException? = null
      var readerReady = false
      var connectFailed: Pair<String, String>? = null
      val resolved = AtomicBoolean(false)

      fun tryFinish() {
        val intentDone = retrievedIntent != null || retrieveFailed != null
        val connDone = readerReady || connectFailed != null
        if (!intentDone || !connDone) return
        if (!resolved.compareAndSet(false, true)) return

        connectFailed?.let { (c, m) -> return finishWithError(c, m, null) }
        retrieveFailed?.let { e -> return finishWithError("RETRIEVE_FAILED", e.errorMessage ?: "Retrieve failed", e.toString()) }

        collectAndConfirm(retrievedIntent!!, orderId)
      }

      // Leg 1: Retrieve PI (only needs Terminal, not a reader)
      terminal.retrievePaymentIntent(secret, object: PaymentIntentCallback {
        override fun onSuccess(intent: PaymentIntent) {
          retrievedIntent = intent
          mainHandler.post { tryFinish() }
        }
        override fun onFailure(e: TerminalException) {
          retrieveFailed = e
          mainHandler.post { tryFinish() }
        }
      })

      // Leg 2: Discover + connect reader in parallel
      ensureReaderConnected(locId, isSim, { _ ->
        readerReady = true
        mainHandler.post { tryFinish() }
      }, { c, m ->
        connectFailed = c to m
        mainHandler.post { tryFinish() }
      })
    }
  }

  private fun ensureReaderConnected(locId: String, isSim: Boolean, onConn: (Reader)->Unit, onErr: (String, String)->Unit) {
    val terminal = Terminal.getInstance()
    terminal.connectedReader?.let { return onConn(it) }

    ensureLocationPermission(
      onGranted = {
        if (!isLocationServicesEnabled()) return@ensureLocationPermission onErr("LOCATION_ERROR", "Location services disabled")
        
        if (isConnectingReader.get()) {
          // Eager init or prepareTapToPay is already connecting — wait for it
          awaitReaderConnection(
            onConnected = { onConn(it) },
            onTimeout = { onErr("CONNECT_FAILED", "Reader connection timed out. Please retry.") }
          )
          return@ensureLocationPermission
        }
        isConnectingReader.set(true)

        // Cancel any leftover discovery from a previous attempt
        discoveryCancelable?.let { old ->
          if (!old.isCompleted) old.cancel(object : Callback {
            override fun onSuccess() {}
            override fun onFailure(e: TerminalException) {}
          })
          discoveryCancelable = null
        }

        var readerFoundAndConnecting = false
        
        val config = DiscoveryConfiguration.TapToPayDiscoveryConfiguration(isSim)
        
        discoveryCancelable = terminal.discoverReaders(config, object: DiscoveryListener {
          override fun onUpdateDiscoveredReaders(readers: List<Reader>) {
            val r = readers.firstOrNull()
            if (r != null && !readerFoundAndConnecting) {
              readerFoundAndConnecting = true
              discoveryCancelable?.cancel(object: Callback {
                override fun onSuccess() {
                   discoveryCancelable = null
                   val cConfig = ConnectionConfiguration.TapToPayConnectionConfiguration(
                     locId,
                     autoReconnectOnUnexpectedDisconnect = true,
                     tapToPayReaderListener = null
                   )
                   terminal.connectReader(r, cConfig, object: ReaderCallback {
                     override fun onSuccess(reader: Reader) { isConnectingReader.set(false); onConn(reader) }
                     override fun onFailure(e: TerminalException) { isConnectingReader.set(false); onErr("CONNECT_FAILED", e.errorMessage ?: "Connect failed") }
                   })
                }
                override fun onFailure(e: TerminalException) {
                  discoveryCancelable = null
                  val cConfig = ConnectionConfiguration.TapToPayConnectionConfiguration(
                    locId,
                    autoReconnectOnUnexpectedDisconnect = true,
                    tapToPayReaderListener = null
                  )
                  terminal.connectReader(r, cConfig, object: ReaderCallback {
                    override fun onSuccess(reader: Reader) { isConnectingReader.set(false); onConn(reader) }
                    override fun onFailure(e2: TerminalException) { isConnectingReader.set(false); onErr("CONNECT_FAILED", e2.errorMessage ?: "Connect failed") }
                  })
                }
              })
            }
          }
        }, object: Callback {
          override fun onSuccess() {
            // Discovery completed. If we never found a reader, report error.
            if (!readerFoundAndConnecting) {
              isConnectingReader.set(false)
              discoveryCancelable = null
              onErr("NO_READER_FOUND", "No payment reader found. Please try again.")
            }
          }
          override fun onFailure(e: TerminalException) {
            isConnectingReader.set(false)
            discoveryCancelable = null
            onErr("DISCOVERY_FAILED", e.errorMessage ?: "Discovery failed")
          }
        })

        // Safety timeout: if discovery hangs for more than 15s, abort
        mainHandler.postDelayed({
          if (isConnectingReader.get() && !readerFoundAndConnecting) {
            discoveryCancelable?.let { d ->
              if (!d.isCompleted) d.cancel(object : Callback {
                override fun onSuccess() {}
                override fun onFailure(e: TerminalException) {}
              })
            }
            isConnectingReader.set(false)
            discoveryCancelable = null
            onErr("DISCOVERY_TIMEOUT", "Reader discovery timed out. Please try again.")
          }
        }, 15_000L)
      },
      onDenied = { onErr("LOCATION_ERROR", "Location permission denied") }
    )
  }

  /**
   * Retrieve PI then collect+confirm (used when reader is already connected).
   */
  private fun retrieveAndProcess(secret: String, orderId: String?) {
    val terminal = Terminal.getInstance()
    terminal.retrievePaymentIntent(secret, object: PaymentIntentCallback {
      override fun onSuccess(intent: PaymentIntent) {
        collectAndConfirm(intent, orderId)
      }
      override fun onFailure(e: TerminalException) {
        finishWithError("RETRIEVE_FAILED", e.errorMessage ?: "Retrieve failed", e.toString())
      }
    })
  }

  /**
   * Collect payment method (shows NFC screen) then confirm.
   * Used by both the fast path (reader already connected) and
   * the parallel path (retrieve + connect ran simultaneously).
   */
  private fun collectAndConfirm(intent: PaymentIntent, orderId: String?) {
    val terminal = Terminal.getInstance()
    ttpActivityLaunched = true
    val config = CollectPaymentIntentConfiguration.Builder().build()
    currentPaymentCancelable = terminal.collectPaymentMethod(intent, object: PaymentIntentCallback {
      override fun onSuccess(collected: PaymentIntent) {
        currentPaymentCancelable = null
        terminal.confirmPaymentIntent(collected, object: PaymentIntentCallback {
          override fun onSuccess(processed: PaymentIntent) {
            finishWithSuccess(mapOf("status" to "SUCCESS", "paymentIntentId" to processed.id, "amount" to processed.amount, "currency" to processed.currency, "orderId" to orderId))
          }
          override fun onFailure(e: TerminalException) {
            finishWithError("PROCESS_FAILED", e.errorMessage ?: "Process failed", e.toString())
          }
        })
      }
      override fun onFailure(e: TerminalException) {
        currentPaymentCancelable = null
        finishWithError("COLLECT_FAILED", e.errorMessage ?: "Collect failed", e.toString())
      }
    }, config)
  }

  /**
   * Ensure Terminal SDK is initialized and the token provider URL is set.
   * Terminal is pre-initialized at startup; this just sets/updates the URL.
   */
  @OptIn(OfflineMode::class)
  private fun ensureTerminalInitialized(url: String, onReady: ()->Unit) {
    tokenProviderUrl = url  // Set URL for the deferred token provider
    if (!Terminal.isInitialized()) {
      try {
        Terminal.init(applicationContext, LogLevel.VERBOSE, deferredTokenProvider, this, null)
      } catch (e: Exception) {
        Log.e("StripeTerminal", "Failed to initialize terminal: ${e.message}")
      }
    }
    onReady()
  }

  /**
   * Atomically grab and clear pendingResult so only the FIRST caller
   * (out of cancel-callback vs. payment-callback) actually delivers.
   */
  private fun takePendingResult(): MethodChannel.Result? {
    val r = pendingResult
    pendingResult = null
    return r
  }

  private fun finishWithSuccess(map: Map<String, Any?>) {
    val r = takePendingResult()
    resetState()
    mainHandler.post { r?.success(map) }
  }

  private fun finishWithError(code: String, msg: String, det: String?) {
    val r = takePendingResult()
    resetState()
    mainHandler.post { r?.error(code, msg, det) }
  }

  private fun resetState() {
    clearPaymentTimeout()
    isProcessing.set(false)
    isConnectingReader.set(false)
    ttpActivityLaunched = false
    discoveryCancelable = null
    currentPaymentCancelable = null
  }

  private fun schedulePaymentTimeout() {
    clearPaymentTimeout()
    paymentTimeoutRunnable = Runnable { if (isProcessing.get()) finishWithError("TIMEOUT", "Timed out", null) }
    mainHandler.postDelayed(paymentTimeoutRunnable!!, tapToPayTimeoutMs)
  }
  
  private fun clearPaymentTimeout() {
    paymentTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
    paymentTimeoutRunnable = null
  }
  
  private fun normalizeBaseUrl(u: String) = u.trimEnd('/')

  private fun ensureLocationPermission(onGranted: ()->Unit, onDenied: ()->Unit) {
    if (locationPermissions.all { ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED }) onGranted()
    else {
      pendingPermissionGranted = onGranted
      pendingPermissionDenied = onDenied
      ActivityCompat.requestPermissions(this, locationPermissions, locationPermissionRequestCode)
    }
  }
  
  private fun isLocationServicesEnabled(): Boolean {
    val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
    return try { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } catch(e:Exception) { false }
  }

  private fun requestMicrophonePermission(res: MethodChannel.Result) {
    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) res.success(true)
    else {
      pendingMicrophoneResult?.success(false)
      pendingMicrophoneResult = res
      ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), microphonePermissionRequestCode)
    }
  }

  /**
   * Warm up the NFC stack by initiating reader discovery in the background.
   * This runs on app startup to pre-initialize the Stripe Terminal SDK
   * and have the NFC hardware ready before the user makes a payment.
   * 
   * The discovery is cancelled after a short timeout to avoid blocking
   * the UI or draining battery, but it still initializes the necessary
   * background services.
   */
  private fun prewarmupNfcInBackground() {
    if (!Terminal.isInitialized()) {
      Log.d("StripeTerminal", "Terminal not yet initialized, skipping NFC prewarmup")
      return
    }
    // Skip prewarmup if no token URL is set yet (first launch, no cache).
    // The eagerPrepare path handles full discovery+connect once the URL arrives.
    if (tokenProviderUrl == null) {
      Log.d("StripeTerminal", "Token provider URL not set, skipping NFC prewarmup (eagerPrepare will handle)")
      return
    }
    val terminal = Terminal.getInstance()

    Log.d("StripeTerminal", "Starting NFC prewarmup in background...")
    
    // Request location permission silently if not granted
    ensureLocationPermission(
      onGranted = {
        if (!isLocationServicesEnabled()) {
          Log.w("StripeTerminal", "Location services disabled, skipping NFC prewarmup")
          return@ensureLocationPermission
        }

        // Start a brief discovery cycle to warm up the NFC stack
        // This initializes the Stripe Terminal reader discovery without blocking the UI
        val config = DiscoveryConfiguration.TapToPayDiscoveryConfiguration(false) // Non-simulated
        
        val prewarmupCancelable = terminal.discoverReaders(
          config,
          object : DiscoveryListener {
            override fun onUpdateDiscoveredReaders(readers: List<Reader>) {
              Log.d("StripeTerminal", "NFC prewarmup: Found ${readers.size} reader(s)")
            }
          },
          object : Callback {
            override fun onSuccess() {
              Log.d("StripeTerminal", "NFC prewarmup discovery completed")
            }
            override fun onFailure(e: TerminalException) {
              Log.w("StripeTerminal", "NFC prewarmup discovery failed: ${e.message}")
            }
          }
        )

        // Cancel discovery after 2 seconds to warm up the stack without draining battery
        mainHandler.postDelayed({
          if (!prewarmupCancelable.isCompleted) {
            prewarmupCancelable.cancel(object : Callback {
              override fun onSuccess() {
                Log.d("StripeTerminal", "NFC prewarmup cancelled successfully after warmup")
              }
              override fun onFailure(e: TerminalException) {
                Log.d("StripeTerminal", "NFC prewarmup cancel failed (normal): ${e.message}")
              }
            })
          }
        }, 2_000L) // 2 second warmup window
      },
      onDenied = {
        Log.d("StripeTerminal", "Location permission denied, skipping NFC prewarmup")
      }
    )
  }

  /**
   * Prewarmup method that can be called from Flutter if needed.
   * Typically called automatically during app startup.
   */
  private fun prewarmupNfc(args: Map<*, *>, result: MethodChannel.Result) {
    Log.d("StripeTerminal", "Explicit prewarmup requested from Flutter")
    try {
      prewarmupNfcInBackground()
      result.success(mapOf("status" to "PREWARMUP_STARTED"))
    } catch (e: Exception) {
      Log.w("StripeTerminal", "Prewarmup failed (non-critical): ${e.message}")
      result.success(mapOf("status" to "PREWARMUP_SKIPPED", "reason" to (e.message ?: "Terminal not ready")))
    }
  }

  /**
   * Eagerly initialize Terminal and connect reader in background.
   * Called from Dart at app startup to minimize first-payment latency.
   * Returns immediately — all heavy work happens asynchronously.
   */
  private fun eagerPrepare(args: Map<*, *>, result: MethodChannel.Result) {
    val baseUrl = args["terminalBaseUrl"] as? String
    val locationId = args["locationId"] as? String
    val isSimulated = args["isSimulated"] as? Boolean ?: false

    if (baseUrl.isNullOrBlank() || locationId.isNullOrBlank()) {
      result.success(mapOf("status" to "SKIPPED", "reason" to "Missing terminalBaseUrl or locationId"))
      return
    }

    val url = normalizeBaseUrl(baseUrl)
    terminalBaseUrl = url

    // Return to Dart immediately — background initialization follows
    result.success(mapOf("status" to "STARTED"))

    // Step 1: Initialize Terminal SDK
    ensureTerminalInitialized(url) {
      val terminal = Terminal.getInstance()

      // Step 2: Already connected? Done.
      if (terminal.connectedReader != null) {
        Log.d("StripeTerminal", "EagerPrepare: Reader already connected ✅")
        return@ensureTerminalInitialized
      }

      // Step 3: Check location permission (if not granted, cache config for retry after grant)
      if (locationPermissions.any { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }) {
        Log.d("StripeTerminal", "EagerPrepare: Location permission not yet granted, will retry after grant")
        eagerPrepareConfig = Triple(url, locationId, isSimulated)
        return@ensureTerminalInitialized
      }
      if (!isLocationServicesEnabled()) {
        Log.d("StripeTerminal", "EagerPrepare: Location services disabled")
        return@ensureTerminalInitialized
      }

      // Step 4: Discover + Connect in background
      startEagerDiscoveryAndConnect(terminal, locationId, isSimulated)
    }
  }

  /**
   * Background reader discovery and connection for eager initialization.
   */
  private fun startEagerDiscoveryAndConnect(terminal: Terminal, locationId: String, isSimulated: Boolean) {
    if (isConnectingReader.getAndSet(true)) {
      Log.d("StripeTerminal", "EagerPrepare: Already connecting, skip")
      return
    }

    Log.d("StripeTerminal", "EagerPrepare: Starting discovery...")
    sendProgress(1, "Connecting...")

    val config = DiscoveryConfiguration.TapToPayDiscoveryConfiguration(isSimulated)
    discoveryCancelable = terminal.discoverReaders(config, object : DiscoveryListener {
      override fun onUpdateDiscoveredReaders(readers: List<Reader>) {
        val reader = readers.firstOrNull() ?: return
        discoveryCancelable?.cancel(object : Callback {
          override fun onSuccess() {
            discoveryCancelable = null
            connectEagerReader(terminal, reader, locationId)
          }
          override fun onFailure(e: TerminalException) {
            discoveryCancelable = null
            connectEagerReader(terminal, reader, locationId)
          }
        })
      }
    }, object : Callback {
      override fun onSuccess() { /* discovery completed naturally */ }
      override fun onFailure(e: TerminalException) {
        isConnectingReader.set(false)
        discoveryCancelable = null
        Log.w("StripeTerminal", "EagerPrepare: Discovery failed: ${e.message}")
      }
    })
  }

  /**
   * Connect to a discovered reader in the eager init background pipeline.
   */
  private fun connectEagerReader(terminal: Terminal, reader: Reader, locationId: String) {
    Log.d("StripeTerminal", "EagerPrepare: Connecting to reader...")
    sendProgress(2, "Downloading...")

    val cConfig = ConnectionConfiguration.TapToPayConnectionConfiguration(
      locationId,
      autoReconnectOnUnexpectedDisconnect = true,
      tapToPayReaderListener = null
    )
    terminal.connectReader(reader, cConfig, object : ReaderCallback {
      override fun onSuccess(r: Reader) {
        isConnectingReader.set(false)
        Log.d("StripeTerminal", "EagerPrepare: Reader connected ✅")
        sendProgress(3, "Ready!")
      }
      override fun onFailure(e: TerminalException) {
        isConnectingReader.set(false)
        Log.w("StripeTerminal", "EagerPrepare: Connect failed: ${e.message}")
      }
    })
  }

  /**
   * Wait for an in-progress reader connection to complete.
   * Polls every 300ms for up to 15 seconds.
   */
  private fun awaitReaderConnection(
    maxWaitMs: Long = 15_000,
    onConnected: (Reader) -> Unit,
    onTimeout: () -> Unit
  ) {
    val startTime = System.currentTimeMillis()
    val poller = object : Runnable {
      override fun run() {
        Terminal.getInstance().connectedReader?.let {
          onConnected(it)
          return
        }
        // If no longer connecting and not connected → attempt finished (failed)
        if (!isConnectingReader.get()) {
          onTimeout()
          return
        }
        // Still connecting — check timeout
        if (System.currentTimeMillis() - startTime > maxWaitMs) {
          onTimeout()
          return
        }
        mainHandler.postDelayed(this, 300)
      }
    }
    mainHandler.post(poller)
  }

  private fun getNfcStatus(res: MethodChannel.Result) {
    val s = packageManager.hasSystemFeature(PackageManager.FEATURE_NFC)
    val e = NfcAdapter.getDefaultAdapter(this)?.isEnabled == true
    res.success(mapOf("supported" to s, "enabled" to e))
  }

  private fun openNfcSettings() {
    startActivity(Intent(Settings.ACTION_NFC_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) 
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
    if (requestCode == locationPermissionRequestCode) {
      if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) pendingPermissionGranted?.invoke() else pendingPermissionDenied?.invoke()
      pendingPermissionGranted = null; pendingPermissionDenied = null
    } else if (requestCode == microphonePermissionRequestCode) {
      pendingMicrophoneResult?.success(grantResults.all { it == PackageManager.PERMISSION_GRANTED })
      pendingMicrophoneResult = null
    } else if (requestCode == eagerPermissionRequestCode) {
      val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
      Log.d("StripeTerminal", "Eager permissions result: allGranted=$allGranted")
      // If location was granted and we have pending eager config, start background connect
      if (allGranted) {
        eagerPrepareConfig?.let { (url, locId, isSim) ->
          if (Terminal.isInitialized()) {
            val terminal = Terminal.getInstance()
            if (terminal.connectedReader == null && !isConnectingReader.get()) {
              startEagerDiscoveryAndConnect(terminal, locId, isSim)
            }
          }
          eagerPrepareConfig = null
        }
      }
    } else super.onRequestPermissionsResult(requestCode, permissions, grantResults)
  }

  // TerminalListener: onUnexpectedReaderDisconnect removed in SDK 5.x.
  // Disconnect handling goes through TapToPayReaderListener on the connection config.
  override fun onConnectionStatusChange(status: ConnectionStatus) {}
  override fun onPaymentStatusChange(status: PaymentStatus) {}
}
