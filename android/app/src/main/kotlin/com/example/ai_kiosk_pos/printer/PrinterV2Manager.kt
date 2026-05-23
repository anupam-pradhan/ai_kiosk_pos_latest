package com.example.ai_kiosk_pos.printer

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Base64
import androidx.core.content.ContextCompat
import com.dantsu.escposprinter.connection.DeviceConnection
import com.dantsu.escposprinter.connection.bluetooth.BluetoothConnection
import com.dantsu.escposprinter.connection.tcp.TcpConnection
import com.dantsu.escposprinter.connection.usb.UsbConnection
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class PrinterV2Manager(private val context: Context) {
  companion object {
    private const val PREFS_NAME = "megapos_printer_v2"
    private const val KEY_NAME = "name"
    private const val KEY_ADDRESS = "address"
    private const val KEY_TYPE = "type"
    private const val DEFAULT_TCP_PORT = 9100
  }

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val prefs: SharedPreferences =
    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
  private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager

  var statusSender: ((Map<String, Any?>) -> Unit)? = null
  var jobSender: ((Map<String, Any?>) -> Unit)? = null
  var debugLogSender: ((String) -> Unit)? = null

  fun shutdown() {
    scope.cancel()
  }

  fun handleAppResume() {
    emitStatus()
  }

  fun status(result: MethodChannel.Result) {
    result.success(ok(state = "idle", message = "Printer status ready"))
  }

  fun scan(result: MethodChannel.Result) {
    scope.launch(Dispatchers.IO) {
      val devices = mutableListOf<Map<String, Any?>>()
      devices.addAll(scanBluetoothPrinters())
      devices.addAll(scanUsbPrinters())

      val savedType = savedType()
      val savedAddress = savedAddress()
      if ((savedType == "ethernet" || savedType == "wifi") && savedAddress.isNotBlank()) {
        devices.add(
          printerMap(
            name = savedName().ifBlank { "Network Printer ($savedAddress)" },
            address = savedAddress,
            type = savedType,
            connected = true,
          )
        )
      }

      val response = ok(state = "scanned", message = "Printer scan complete") +
        mapOf("printers" to devices)
      withContext(Dispatchers.Main) {
        emitStatus()
        result.success(response)
      }
    }
  }

  fun save(args: Map<*, *>, result: MethodChannel.Result) {
    val address = args["address"]?.toString()?.trim().orEmpty()
    val type = normalizeType(args["printerType"]?.toString() ?: args["type"]?.toString())
    val name = args["name"]?.toString()?.trim().orEmpty()

    if (address.isBlank()) {
      result.success(fail("PRINTER_DISCONNECTED", "Printer address is required"))
      return
    }

    scope.launch(Dispatchers.IO) {
      val validation = validatePrinter(address, type)
      val response = if (validation == null) {
        val displayName = name.ifBlank { nameFor(address, type) }
        prefs.edit()
          .putString(KEY_NAME, displayName)
          .putString(KEY_ADDRESS, address)
          .putString(KEY_TYPE, type)
          .apply()
        ok(state = "saved", message = "$displayName saved") + mapOf(
          "name" to displayName,
          "address" to address,
          "printerType" to type,
        )
      } else {
        validation
      }

      withContext(Dispatchers.Main) {
        emitStatus()
        result.success(response)
      }
    }
  }

  fun forget(result: MethodChannel.Result) {
    prefs.edit().clear().apply()
    emitStatus()
    result.success(ok(state = "forgotten", message = "Printer forgotten"))
  }

  fun test(result: MethodChannel.Result) {
    val lines = listOf(
      "MEGAPOS PRINTER TEST",
      SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale.UK).format(Date()),
      "Transport: ${savedType().uppercase(Locale.ROOT)}",
      "Printer: ${savedName().ifBlank { savedAddress() }}",
      "",
      "If this prints, the v2 printer bridge is working.",
    )
    printBytes(
      bytes = escposText(lines, cut = true),
      copies = 1,
      jobId = "test-${UUID.randomUUID()}",
      jobType = "test",
      result = result,
    )
  }

  fun drawer(result: MethodChannel.Result) {
    printBytes(
      bytes = byteArrayOf(0x1B, 0x70, 0x00, 0x19, 0xFA.toByte()),
      copies = 1,
      jobId = "drawer-${UUID.randomUUID()}",
      jobType = "drawer",
      result = result,
    )
  }

  fun printRaw(args: Map<*, *>, result: MethodChannel.Result) {
    val data = args["data"]?.toString()?.trim().orEmpty()
    if (data.isBlank()) {
      result.success(fail("PRINTER_DISCONNECTED", "Missing printer data"))
      return
    }

    val bytes = try {
      Base64.decode(data, Base64.DEFAULT)
    } catch (_: Exception) {
      result.success(fail("PRINTER_DISCONNECTED", "Printer data is not valid base64"))
      return
    }

    val copies = numberArg(args["copies"], 1).coerceIn(1, 5)
    val jobId = args["jobId"]?.toString()?.ifBlank { null } ?: "print-${UUID.randomUUID()}"
    val jobType = args["jobType"]?.toString()?.ifBlank { null } ?: "raw"
    printBytes(bytes, copies, jobId, jobType, result)
  }

  private fun printBytes(
    bytes: ByteArray,
    copies: Int,
    jobId: String,
    jobType: String,
    result: MethodChannel.Result,
  ) {
    val startedAt = System.currentTimeMillis()
    emitJob(jobId, jobType, "printing", "Sending to printer")

    scope.launch(Dispatchers.IO) {
      var errorCode = "PRINTER_DISCONNECTED"
      var message = "Printer print failed"
      var ok = false

      try {
        val address = savedAddress()
        val type = savedType()
        if (address.isBlank() || type.isBlank()) {
          errorCode = "PRINTER_DISCONNECTED"
          message = "No saved printer"
        } else {
          repeat(copies) { copyIndex ->
            val connection = openConnection(address, type)
            connection.useConnection { device ->
              device.write(bytes)
              device.send(waitMs(bytes, type))
            }
            if (copyIndex < copies - 1) Thread.sleep(500)
          }
          ok = true
          message = "Sent to printer"
        }
      } catch (e: Exception) {
        errorCode = classifyError(e)
        message = e.message ?: message
        log("Printer v2 print failed: $message")
      }

      val duration = System.currentTimeMillis() - startedAt
      val response = if (ok) {
        ok(jobId = jobId, state = "sent", message = message, durationMs = duration) +
          mapOf("copies" to copies)
      } else {
        fail(errorCode, message, jobId = jobId, state = "failed", durationMs = duration)
      }

      withContext(Dispatchers.Main) {
        emitStatus()
        emitJob(jobId, jobType, if (ok) "sent" else "failed", message, errorCode.takeIf { !ok }, duration)
        result.success(response)
      }
    }
  }

  private fun ok(
    jobId: String? = null,
    state: String,
    message: String,
    durationMs: Long = 0L,
  ): Map<String, Any?> = mapOf(
    "ok" to true,
    "jobId" to (jobId ?: ""),
    "state" to state,
    "errorCode" to "",
    "message" to message,
    "durationMs" to durationMs,
    "status" to currentStatus(),
  )

  private fun fail(
    code: String,
    message: String,
    jobId: String = "",
    state: String = "failed",
    durationMs: Long = 0L,
  ): Map<String, Any?> = mapOf(
    "ok" to false,
    "jobId" to jobId,
    "state" to state,
    "errorCode" to code,
    "code" to code,
    "message" to message,
    "error" to message,
    "durationMs" to durationMs,
    "status" to currentStatus(),
  )

  private fun currentStatus(): Map<String, Any?> {
    val name = savedName()
    val address = savedAddress()
    val type = savedType()
    val saved = address.isNotBlank() && type.isNotBlank()
    return mapOf(
      "connected" to saved,
      "state" to if (saved) "saved" else "none",
      "name" to if (saved) name.ifBlank { nameFor(address, type) } else "",
      "address" to if (saved) address else "",
      "type" to if (saved) type else "",
      "lastPrinterName" to name,
      "lastPrinterAddress" to address,
      "lastPrinterType" to type,
      "bluetoothAvailable" to (bluetoothAdapter() != null),
      "bluetoothEnabled" to (bluetoothAdapter()?.isEnabled == true),
      "bluetoothPermissionGranted" to hasBluetoothPermission(),
      "locationPermissionGranted" to hasLocationPermission(),
      "usbPermissionGranted" to usbManager.deviceList.values
        .filter { isLikelyUsbPrinter(it.deviceClass, it.productName) }
        .all { usbManager.hasPermission(it) },
      "printerStatusAvailable" to false,
      "printerStatusMessage" to if (saved) "Saved printer. Status checks happen per print." else "",
      "printerStatusIssues" to emptyList<String>(),
      "printerStatusCheckedAt" to System.currentTimeMillis(),
      "paperEnd" to false,
      "paperNearEnd" to false,
      "coverOpen" to false,
      "cutterError" to false,
      "printerOffline" to false,
      "mechanicalError" to false,
      "printingStopped" to false,
      "feedButtonPressed" to false,
      "unrecoverableError" to false,
      "autoRecoverableError" to false,
    )
  }

  private fun emitStatus() {
    statusSender?.invoke(currentStatus())
  }

  private fun emitJob(
    jobId: String,
    jobType: String,
    state: String,
    message: String,
    errorCode: String? = null,
    durationMs: Long = 0L,
  ) {
    jobSender?.invoke(
      mapOf(
        "jobId" to jobId,
        "jobType" to jobType,
        "state" to state,
        "message" to message,
        "errorCode" to (errorCode ?: ""),
        "durationMs" to durationMs,
        "status" to currentStatus(),
      )
    )
  }

  @SuppressLint("MissingPermission")
  private fun scanBluetoothPrinters(): List<Map<String, Any?>> {
    val adapter = bluetoothAdapter() ?: return emptyList()
    if (!adapter.isEnabled || !hasBluetoothPermission()) return emptyList()

    return adapter.bondedDevices
      .filter { it.type != BluetoothDevice.DEVICE_TYPE_LE }
      .filter { isLikelyBluetoothPrinter(it) }
      .map {
        printerMap(
          name = it.name ?: "Bluetooth Printer",
          address = it.address,
          type = "bluetooth",
          connected = savedType() == "bluetooth" &&
            it.address.equals(savedAddress(), ignoreCase = true),
        )
      }
  }

  private fun scanUsbPrinters(): List<Map<String, Any?>> {
    return usbManager.deviceList.values
      .filter { isLikelyUsbPrinter(it.deviceClass, it.productName) }
      .map {
        printerMap(
          name = it.productName ?: it.deviceName ?: "USB Printer",
          address = it.deviceName,
          type = "usb",
          connected = savedType() == "usb" && it.deviceName == savedAddress(),
        ) + mapOf("usbPermissionGranted" to usbManager.hasPermission(it))
      }
  }

  private fun printerMap(
    name: String,
    address: String,
    type: String,
    connected: Boolean,
  ): Map<String, Any?> = mapOf(
    "name" to name,
    "address" to address,
    "type" to type,
    "isPrinter" to true,
    "isConnected" to connected,
  )

  private suspend fun validatePrinter(address: String, type: String): Map<String, Any?>? =
    withContext(Dispatchers.IO) {
      try {
        val connection = openConnection(address, type)
        connection.useConnection { }
        null
      } catch (e: Exception) {
        fail(classifyError(e), e.message ?: "Could not connect to printer")
      }
    }

  private fun openConnection(address: String, type: String): DeviceConnection {
    return when (normalizeType(type)) {
      "bluetooth" -> openBluetooth(address)
      "usb" -> openUsb(address)
      "ethernet", "wifi" -> openTcp(address)
      else -> throw IllegalArgumentException("Unsupported printer type: $type")
    }
  }

  @SuppressLint("MissingPermission")
  private fun openBluetooth(address: String): BluetoothConnection {
    val adapter = bluetoothAdapter() ?: throw IllegalStateException("Bluetooth is not available")
    if (!adapter.isEnabled) throw IllegalStateException("Bluetooth is turned off")
    if (!hasBluetoothPermission()) throw SecurityException("Bluetooth permission not granted")
    val device = adapter.bondedDevices.firstOrNull {
      it.address.equals(address, ignoreCase = true)
    } ?: throw IllegalStateException("Printer is not paired")
    return BluetoothConnection(device).connect() as BluetoothConnection
  }

  private fun openUsb(address: String): UsbConnection {
    val device = usbManager.deviceList[address]
      ?: throw IllegalStateException("USB printer is not connected")
    if (!usbManager.hasPermission(device)) {
      throw SecurityException("USB permission not granted")
    }
    return UsbConnection(usbManager, device).connect() as UsbConnection
  }

  private fun openTcp(address: String): TcpConnection {
    val (host, port) = parseNetworkAddress(address)
    return TcpConnection(host, port, 5000).connect() as TcpConnection
  }

  private fun DeviceConnection.useConnection(block: (DeviceConnection) -> Unit) {
    try {
      block(this)
    } finally {
      try {
        disconnect()
      } catch (_: Exception) {
      }
    }
  }

  private fun parseNetworkAddress(address: String): Pair<String, Int> {
    val parts = address.trim().split(":")
    val host = parts.firstOrNull()?.trim().orEmpty()
    if (host.isBlank() || parts.size > 2) throw IllegalArgumentException("Invalid network printer address")
    val port = if (parts.size == 2) {
      parts[1].toIntOrNull() ?: throw IllegalArgumentException("Invalid network printer port")
    } else {
      DEFAULT_TCP_PORT
    }
    if (port !in 1..65535) throw IllegalArgumentException("Invalid network printer port")
    return host to port
  }

  @SuppressLint("MissingPermission")
  private fun isLikelyBluetoothPrinter(device: BluetoothDevice): Boolean {
    val name = (device.name ?: "").lowercase(Locale.ROOT)
    val nonPrinter = listOf(
      "phone", "iphone", "android", "galaxy", "watch", "band",
      "headset", "headphone", "earbud", "speaker", "keyboard", "mouse",
      "laptop", "macbook", "desktop", "tv", "car",
    )
    if (nonPrinter.any { name.contains(it) }) return false

    val btClass = device.bluetoothClass
    if (btClass?.majorDeviceClass == BluetoothClass.Device.Major.IMAGING) return true
    val keywords = listOf(
      "printer", "print", "pos", "thermal", "receipt", "escpos", "epson",
      "star", "bixolon", "xprinter", "munbyn", "goojprt", "gprinter",
      "rongta", "hprt", "zjiang", "sunmi", "imin", "sprt", "xp-", "kpc",
    )
    return keywords.any { name.contains(it) }
  }

  private fun isLikelyUsbPrinter(deviceClass: Int, productName: String?): Boolean {
    if (deviceClass == 7) return true
    val name = (productName ?: "").lowercase(Locale.ROOT)
    return listOf("printer", "print", "pos", "thermal", "receipt", "epson", "star", "xprinter")
      .any { name.contains(it) }
  }

  private fun escposText(lines: List<String>, cut: Boolean): ByteArray {
    val out = mutableListOf<Byte>()
    fun add(vararg bytes: Int) {
      bytes.forEach { out.add(it.toByte()) }
    }
    fun text(value: String) {
      out.addAll(value.toByteArray(Charsets.ISO_8859_1).toList())
      out.add(0x0A)
    }
    add(0x1B, 0x40)
    lines.forEach(::text)
    repeat(4) { out.add(0x0A) }
    if (cut) add(0x1D, 0x56, 0x01)
    return out.toByteArray()
  }

  private fun waitMs(bytes: ByteArray, type: String): Int {
    if (type == "usb") return 0
    return (bytes.size / 16 + 500).coerceIn(500, 4000)
  }

  private fun classifyError(e: Exception): String {
    val msg = (e.message ?: "").uppercase(Locale.ROOT)
    return when {
      "BLUETOOTH" in msg && "PERMISSION" in msg -> "BLUETOOTH_PERMISSION_DENIED"
      "BLUETOOTH" in msg && ("OFF" in msg || "TURNED" in msg) -> "BLUETOOTH_OFF"
      "PAIRED" in msg -> "PRINTER_NOT_PAIRED"
      "USB" in msg && "PERMISSION" in msg -> "USB_PERMISSION_DENIED"
      "NETWORK" in msg || "TCP" in msg || "HOST" in msg || "PORT" in msg || "CONNECT" in msg -> "NETWORK_UNREACHABLE"
      "PERMISSION" in msg -> "BLUETOOTH_PERMISSION_DENIED"
      else -> "PRINTER_DISCONNECTED"
    }
  }

  private fun normalizeType(value: String?): String {
    return when (value?.trim()?.lowercase(Locale.ROOT)) {
      "bt", "bluetooth" -> "bluetooth"
      "usb" -> "usb"
      "lan", "tcp", "network", "ethernet" -> "ethernet"
      "wifi", "wi-fi" -> "wifi"
      else -> "bluetooth"
    }
  }

  private fun numberArg(value: Any?, fallback: Int): Int {
    return when (value) {
      is Int -> value
      is Number -> value.toInt()
      is String -> value.toIntOrNull() ?: fallback
      else -> fallback
    }
  }

  private fun savedName(): String = prefs.getString(KEY_NAME, "") ?: ""
  private fun savedAddress(): String = prefs.getString(KEY_ADDRESS, "") ?: ""
  private fun savedType(): String = prefs.getString(KEY_TYPE, "") ?: ""

  private fun nameFor(address: String, type: String): String {
    return when (normalizeType(type)) {
      "bluetooth" -> "Bluetooth Printer"
      "usb" -> "USB Printer"
      "ethernet" -> "Network Printer ($address)"
      "wifi" -> "WiFi Printer ($address)"
      else -> "Printer"
    }
  }

  private fun bluetoothAdapter(): BluetoothAdapter? {
    val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    return manager?.adapter
  }

  private fun hasBluetoothPermission(): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) ==
        PackageManager.PERMISSION_GRANTED
    } else {
      true
    }
  }

  private fun hasLocationPermission(): Boolean {
    return ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
      PackageManager.PERMISSION_GRANTED ||
      ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
      PackageManager.PERMISSION_GRANTED
  }

  private fun log(message: String) {
    debugLogSender?.invoke(message)
  }
}
