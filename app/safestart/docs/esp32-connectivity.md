# ESP32 connectivity

All production Dashboard, Settings, Vehicle and Office requests share
`Esp32Connection.shared`. The exact last verified base URL (hostname or IPv4) is cached in memory.
Only an HTTP 200 `/status` with all SafeStart fields and valid states/results
makes the device online. `PENDING` is valid while counting down or sampling.
Discovery has no dependency on test completion, saving or emergency SMS.

The service first verifies its cached address, then explicitly probes `http://safestart.local/status`. If Dart cannot reach
that URL, Android hostname resolution supplies private IPv4 candidates. IPv6
and link-local results do not prevent trying subsequent private IPv4 results.
Debug logs show candidates, resolution, HTTP codes and rejection reasons.
If resolution fails, Android supplies candidates from current Wi-Fi links or
Wi-Fi/hotspot interfaces, with their actual network prefix lengths. The fallback
covers the phone's /24 portion within the real subnet, excluding its own address,
network and broadcast addresses. At most two interfaces / 508 candidates and
12 parallel GET probes are allowed. Public addresses, redirects, cellular and
VPN interfaces are excluded. Larger LANs with the ESP32 outside this /24 need
working local hostname resolution; no internet or full large-subnet scan occurs.
Some Android vendors hide tethering interfaces or isolate hotspot clients;
physical-device testing is necessary for those networks.

Status polling runs 2.5 seconds after each completed check, only while a status
route is visible and the app is resumed. Checks and discovery are shared across
consumers. Normal HTTP and hostname/platform lookups have a 2-second timeout;
subnet probes use 400 ms. Failed discovery waits 10, 20, 40, then 60 seconds
between attempts; success resets backoff. A failed cached-address check immediately
marks the device offline and begins rediscovery. Losing the cached address never
replays a POST: an acknowledgement timeout may mean hardware already started.

Timers and HTTP probes are cancelled when the last monitoring consumer leaves,
unless an active Vehicle/Office request is still using discovery. Activity cleanup
also closes the native resolver. No new Flutter package was added. Android needs
INTERNET, ACCESS_NETWORK_STATE and cleartext HTTP; SEND_SMS remains unchanged.

Firmware setup is separate: advertise the hostname `safestart.local` (typically
`MDNS.begin("safestart")`) on the same local network, retaining the existing API.
This Flutter change does not modify firmware or require a fixed IP. Hostname
resolution compatibility varies by Android version/router, so test fallback too.

Manual checks: connect on home Wi-Fi; confirm Online/Connected and both tests.
Move phone and ESP32 to a hotspot; confirm Offline then automatic recovery without
restarting. Disconnect/reconnect ESP32, pause/resume the app, navigate away/back,
and try a release APK. Check that monitoring/discovery never activates tests,
gate or SMS; explicit Vehicle DANGER and Office access behavior stay unchanged.
