import 'dart:io';

/// Mahalliy WiFi/LAN IPv4 (telefon ulanishi uchun kompyuter manzili).
Future<String?> primaryLocalIpv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    String? fallback;
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final ip = addr.address;
        if (!_isPrivateOrLinkLocal(ip)) continue;
        // WiFi/Ethernet interfeyslarini ustun qo‘yish.
        final name = iface.name.toLowerCase();
        if (name.startsWith('en') || name.startsWith('wlan') || name.startsWith('eth')) {
          return ip;
        }
        fallback ??= ip;
      }
    }
    return fallback;
  } catch (_) {
    return null;
  }
}

bool _isPrivateOrLinkLocal(String ip) {
  if (ip.startsWith('10.')) return true;
  if (ip.startsWith('192.168.')) return true;
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final a = int.tryParse(parts[0]);
  final b = int.tryParse(parts[1]);
  if (a == 172 && b != null && b >= 16 && b <= 31) return true;
  return false;
}
