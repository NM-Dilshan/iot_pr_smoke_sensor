package com.example.safestart

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.InetAddress
import java.util.concurrent.Executors
import java.net.NetworkInterface

/** Supplies only bounded, current private Wi-Fi/tethering subnets. No HTTP or START commands. */
class LocalNetworkBridge(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "safestart/network")
    private val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val resolver = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var resolving = false
    private var disposed = false
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "localCandidates" -> try { result.success(candidates()) }
                    catch (_: Exception) { result.success(emptyList<String>()) }
                "resolveHostname" -> {
                    if (resolving) result.success(emptyList<String>())
                    else {
                        resolving = true
                        resolver.execute {
                            val hosts = try { InetAddress.getAllByName("safestart.local")
                                .filterIsInstance<Inet4Address>().mapNotNull { it.hostAddress } }
                                catch (_: Exception) { emptyList<String>() }
                            main.post {
                                resolving = false
                                if (!disposed) result.success(hosts)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    @Suppress("DEPRECATION")
    private fun candidates(): List<String> {
        val addresses = linkedMapOf<String, Pair<Inet4Address, Int>>()
        for (network in connectivity.allNetworks) {
            val capabilities = connectivity.getNetworkCapabilities(network) ?: continue
            if (!capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) continue
            val links = connectivity.getLinkProperties(network) ?: continue
            for (link in links.linkAddresses) {
                val ip = link.address as? Inet4Address ?: continue
                addresses[ip.hostAddress ?: continue] = Pair(ip, link.prefixLength)
            }
        }
        // A phone hosting the hotspot may expose its tethering interface outside
        // ConnectivityManager's application networks. Never include cellular/VPN interfaces.
        for (iface in NetworkInterface.getNetworkInterfaces().toList()) {
            if (!iface.isUp || iface.isLoopback ||
                !Regex("^(wlan|swlan|ap|wifi|softap|br[0-9]|bridge).*", RegexOption.IGNORE_CASE).matches(iface.name)) continue
            for (link in iface.interfaceAddresses) {
                val ip = link.address as? Inet4Address ?: continue
                addresses[ip.hostAddress ?: continue] = Pair(ip, link.networkPrefixLength.toInt())
            }
        }
        val hosts = linkedSetOf<String>()
        for ((ip, prefix) in addresses.values.take(2)) {
            val bytes = ip.address.map { it.toInt() and 255 }
            val private = bytes[0] == 10 || (bytes[0] == 172 && bytes[1] in 16..31) ||
                (bytes[0] == 192 && bytes[1] == 168)
            if (!private || prefix !in 8..30) continue
            val value = bytes.fold(0L) { acc, byte -> (acc shl 8) or byte.toLong() }
            val mask = (0xffffffffL shl (32 - prefix)) and 0xffffffffL
            val network = value and mask
            val broadcast = network or (mask xor 0xffffffffL)
            // On larger LANs restrict fallback to the phone's /24, within the
            // actual subnet. mDNS remains the path across a larger broadcast domain.
            val first = maxOf(network + 1, (value and 0xffffff00L) + 1)
            val last = minOf(broadcast - 1, (value and 0xffffff00L) + 254)
            for (candidate in first..last) {
                if (candidate == value) continue
                hosts.add((3 downTo 0).joinToString(".") { shift ->
                    ((candidate shr (shift * 8)) and 255).toString()
                })
            }
        }
        return hosts.take(508)
    }
    fun dispose() { disposed = true; channel.setMethodCallHandler(null); resolver.shutdownNow() }
}
