import 'dart:io';

/// Mahalliy WiFi/LAN IPv4 manzillari (telefon → desktop relay uchun).
class LocalNetworkIp {
  LocalNetworkIp._();

  /// Eng mos WiFi/Ethernet IPv4 (virtual adapterlar chiqarib tashlanadi).
  static Future<String?> primaryLocalIpv4() async {
    final list = await listCandidates();
    if (list.isEmpty) return null;
    return list.first.ip;
  }

  /// Barcha mos manzillar — eng yaxshisi birinchi.
  static Future<List<LocalIpv4Candidate>> listCandidates() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final out = <LocalIpv4Candidate>[];
      for (final iface in interfaces) {
        final name = iface.name.trim();
        if (_isVirtualOrIgnored(name)) continue;
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          if (!_isPrivateLan(ip)) continue;
          out.add(
            LocalIpv4Candidate(
              ip: ip,
              interfaceName: name,
              score: _score(name, ip),
            ),
          );
        }
      }
      out.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.ip.compareTo(b.ip);
      });
      return out;
    } catch (_) {
      return const [];
    }
  }
}

class LocalIpv4Candidate {
  final String ip;
  final String interfaceName;
  final int score;

  const LocalIpv4Candidate({
    required this.ip,
    required this.interfaceName,
    required this.score,
  });

  String get label {
    final nice = interfaceName.trim();
    return nice.isEmpty ? ip : '$ip  ($nice)';
  }
}

/// Orqaga mos: eski chaqiriqlar.
Future<String?> primaryLocalIpv4() => LocalNetworkIp.primaryLocalIpv4();

bool _isPrivateLan(String ip) {
  if (ip.startsWith('10.')) return true;
  if (ip.startsWith('192.168.')) return true;
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final a = int.tryParse(parts[0]);
  final b = int.tryParse(parts[1]);
  if (a == 172 && b != null && b >= 16 && b <= 31) return true;
  return false;
}

bool _isVirtualOrIgnored(String rawName) {
  final n = rawName.toLowerCase();
  const bad = [
    'loopback',
    'vmware',
    'vmnet',
    'virtualbox',
    'vbox',
    'vethernet',
    'hyper-v',
    'hyperv',
    'docker',
    'wsl',
    'vpn',
    'tap-',
    'tun',
    'zerotier',
    'hamachi',
    'radmin',
    'npcap',
    'bluetooth',
    'isatap',
    'teredo',
    'pseudo',
    'virtual',
    'bridge100', // macOS often VM / hotspot bridge
  ];
  for (final b in bad) {
    if (n.contains(b)) return true;
  }
  return false;
}

int _score(String rawName, String ip) {
  final n = rawName.toLowerCase();
  var s = 0;
  if (n.contains('wi-fi') || n.contains('wifi') || n.contains('wlan') || n == 'en0') {
    s += 100;
  } else if (n.contains('ethernet') || n.startsWith('eth') || n.startsWith('en')) {
    s += 80;
  } else if (n.contains('lan')) {
    s += 60;
  } else {
    s += 20;
  }
  // Oddiy uy/router diapazonlari biroz ustun.
  if (ip.startsWith('192.168.0.') || ip.startsWith('192.168.1.')) s += 10;
  return s;
}
