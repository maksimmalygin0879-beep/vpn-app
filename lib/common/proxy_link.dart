import 'dart:convert';
import 'dart:typed_data';

/// Universal subscription converter.
/// Accepts Clash YAML, base64 V2Ray, single proxy links.
/// Returns null if content is already valid Clash YAML.
Uint8List? convertSubscriptionToClash(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true).trim();

  if (_isClashYaml(text)) return null;

  final singleBytes = convertProxyLinkToClash(text);
  if (singleBytes != null) return singleBytes;

  final decoded = _tryBase64Decode(text);
  if (decoded != null) {
    // Try newline-separated first, then space-separated
    var links = decoded
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && _isProxyLink(l))
        .toList();
    if (links.isEmpty) {
      links = decoded
          .split(RegExp(r'\s+'))
          .where(_isProxyLink)
          .toList();
    }
    if (links.isNotEmpty) return _multiLinksToClash(links);
  }

  // Fallback: plain-text subscription — extract proxy links from whitespace-delimited tokens
  final plainLinks = text.split(RegExp(r'\s+')).where(_isProxyLink).toList();
  if (plainLinks.isNotEmpty) return _multiLinksToClash(plainLinks);

  return null;
}

bool _isClashYaml(String text) =>
    (text.contains('proxies:') || text.contains('proxy-groups:')) &&
    (text.startsWith('proxies:') ||
        text.startsWith('mixed-port:') ||
        text.startsWith('port:') ||
        text.startsWith('mode:') ||
        text.startsWith('dns:'));

bool _isProxyLink(String s) => const [
      'vless://',
      'vmess://',
      'trojan://',
      'ss://',
      'hysteria2://',
      'hy2://',
    ].any(s.startsWith);

String? _tryBase64Decode(String text) {
  try {
    final clean = text.replaceAll(RegExp(r'\s'), '');
    final normalized = base64.normalize(clean);
    return utf8.decode(base64.decode(normalized));
  } catch (_) {
    return null;
  }
}

Uint8List _multiLinksToClash(List<String> links) {
  final proxies = links.map(_parseLinkToProxy).whereType<_Proxy>().toList();

  if (proxies.isEmpty) {
    return Uint8List.fromList(utf8.encode('proxies: []\nrules:\n- MATCH,DIRECT\n'));
  }

  final sb = StringBuffer();
  sb.writeln('proxies:');
  for (final p in proxies) {
    sb.write(p.toYamlListItem());
  }
  sb.writeln('proxy-groups:');
  sb.writeln('- name: PROXY');
  sb.writeln('  type: select');
  sb.writeln('  proxies:');
  for (final p in proxies) {
    sb.writeln('  - "${_esc(p.name)}"');
  }
  sb.writeln('rules:');
  sb.writeln('- MATCH,PROXY');
  return Uint8List.fromList(utf8.encode(sb.toString()));
}

/// Converts a single proxy link (vless://, etc.) to a minimal Clash YAML config.
Uint8List? convertProxyLinkToClash(String url) {
  if (!_isProxyLink(url)) return null;
  final proxy = _parseLinkToProxy(url);
  if (proxy == null) return null;
  final sb = StringBuffer();
  sb.writeln('proxies:');
  sb.write(proxy.toYamlListItem());
  sb.writeln('proxy-groups:');
  sb.writeln('- name: PROXY');
  sb.writeln('  type: select');
  sb.writeln('  proxies:');
  sb.writeln('  - "${_esc(proxy.name)}"');
  sb.writeln('rules:');
  sb.writeln('- MATCH,PROXY');
  return Uint8List.fromList(utf8.encode(sb.toString()));
}

// ---------------------------------------------------------------------------
// Proxy data class
// ---------------------------------------------------------------------------

class _Proxy {
  final String type;
  final String name;
  final String server;
  final int port;
  final Map<String, dynamic> extra; // additional fields

  _Proxy({
    required this.type,
    required this.name,
    required this.server,
    required this.port,
    this.extra = const {},
  });

  String toYamlListItem() {
    final sb = StringBuffer();
    // Build all top-level scalar fields first, then nested objects
    final fields = <String, dynamic>{
      'type': type,
      'name': name,
      'server': server,
      'port': port,
      ...extra,
    };

    bool first = true;
    final nestedKeys = <String>[];
    // Write scalars and lists first
    fields.forEach((k, v) {
      if (v is Map) {
        nestedKeys.add(k);
        return;
      }
      final line = '$k: ${_yamlVal(v)}\n';
      if (first) {
        sb.write('- $line');
        first = false;
      } else {
        sb.write('  $line');
      }
    });
    // Write nested maps
    for (final k in nestedKeys) {
      final v = fields[k] as Map;
      sb.write('  $k:\n');
      v.forEach((k2, v2) {
        if (v2 is Map) {
          sb.write('    $k2:\n');
          v2.forEach((k3, v3) => sb.write('      $k3: ${_yamlVal(v3)}\n'));
        } else {
          sb.write('    $k2: ${_yamlVal(v2)}\n');
        }
      });
    }
    return sb.toString();
  }
}

String _yamlVal(dynamic v) {
  if (v is String) return '"${_esc(v)}"';
  if (v is bool) return v ? 'true' : 'false';
  if (v is List) return '[${v.map(_yamlVal).join(', ')}]';
  return v.toString();
}

String _esc(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

// ---------------------------------------------------------------------------
// Parsers
// ---------------------------------------------------------------------------

_Proxy? _parseLinkToProxy(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null) return null;
  switch (uri.scheme.toLowerCase()) {
    case 'vless':      return _parseVless(uri);
    case 'trojan':     return _parseTrojan(uri);
    case 'ss':         return _parseSs(uri);
    case 'vmess':      return _parseVmess(uri);
    case 'hysteria2':
    case 'hy2':        return _parseHysteria2(uri);
    default:           return null;
  }
}

_Proxy? _parseVless(Uri uri) {
  final uuid = uri.userInfo;
  final host = uri.host;
  final port = uri.port;
  final p = uri.queryParameters;
  if (uuid.isEmpty || host.isEmpty) return null;

  final name = _decodeFrag(uri);
  final network = p['type'] ?? 'tcp';
  final security = p['security'] ?? '';
  final sni = p['sni'] ?? p['host'] ?? host;
  final fp = p['fp'] ?? 'chrome';
  final flow = p['flow'] ?? '';

  final extra = <String, dynamic>{
    'uuid': uuid,
    'udp': true,
    'network': network == 'xhttp' || network == 'splithttp' ? 'xhttp' : network,
    if (flow.isNotEmpty) 'flow': flow,
  };

  // packet-encoding
  final pe = p['packetEncoding'] ?? p['packet-encoding'];
  if (pe != null && pe.isNotEmpty) extra['packet-encoding'] = pe;

  if (security == 'reality') {
    extra['tls'] = true;
    extra['servername'] = sni;
    extra['client-fingerprint'] = fp;
    extra['reality-opts'] = {
      'public-key': p['pbk'] ?? '',
      'short-id': p['sid'] ?? '',
    };
  } else if (security == 'tls') {
    extra['tls'] = true;
    extra['servername'] = sni;
    extra['client-fingerprint'] = fp;
    if (p['insecure'] == '1') extra['skip-cert-verify'] = true;
  }

  // alpn (comma-separated string → YAML list)
  final alpnStr = p['alpn'];
  if (alpnStr != null && alpnStr.isNotEmpty) {
    extra['alpn'] = alpnStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  if (network == 'ws') {
    extra['ws-opts'] = {
      'path': p['path'] ?? '/',
      'headers': {'Host': p['host'] ?? host},
    };
  } else if (network == 'xhttp' || network == 'splithttp') {
    final opts = <String, dynamic>{
      'path': p['path'] ?? '/',
      'host': p['host'] ?? host,
    };
    if (p['mode'] != null) opts['mode'] = p['mode'];
    if (p['extra'] != null) {
      try {
        final extraJson = jsonDecode(Uri.decodeComponent(p['extra']!)) as Map;
        const keyMap = <String, String>{
          'scMaxEachPostBytes': 'sc-max-each-post-bytes',
          'scMinPostsIntervalMs': 'sc-min-posts-interval-ms',
          'noGRPCHeader': 'no-grpc-header',
          'xPaddingBytes': 'x-padding-bytes',
        };
        extraJson.forEach((k, v) {
          final mapped = keyMap[k as String] ?? k as String;
          opts[mapped] = v;
        });
      } catch (_) {}
    }
    extra['xhttp-opts'] = opts;
  } else if (network == 'grpc') {
    extra['grpc-opts'] = {'grpc-service-name': p['serviceName'] ?? ''};
  } else if (network == 'h2') {
    final opts = <String, dynamic>{
      'path': p['path'] ?? '/',
    };
    final h2Host = p['host'] ?? host;
    if (h2Host.isNotEmpty) opts['host'] = [h2Host];
    extra['h2-opts'] = opts;
  } else if (network == 'http') {
    final opts = <String, dynamic>{
      'method': p['method'] ?? 'GET',
      'path': [p['path'] ?? '/'],
    };
    final httpHost = p['host'] ?? host;
    if (httpHost.isNotEmpty) opts['headers'] = {'Host': [httpHost]};
    extra['http-opts'] = opts;
  }

  return _Proxy(type: 'vless', name: name, server: host, port: port, extra: extra);
}

_Proxy? _parseTrojan(Uri uri) {
  final host = uri.host;
  if (host.isEmpty) return null;
  final p = uri.queryParameters;
  return _Proxy(
    type: 'trojan',
    name: _decodeFrag(uri),
    server: host,
    port: uri.port,
    extra: {
      'password': uri.userInfo,
      'sni': p['sni'] ?? p['peer'] ?? host,
      'udp': true,
    },
  );
}

_Proxy? _parseSs(Uri uri) {
  final host = uri.host;
  if (host.isEmpty) return null;
  String method = '', password = '';
  try {
    final decoded = utf8.decode(base64.decode(base64.normalize(uri.userInfo)));
    final idx = decoded.indexOf(':');
    if (idx != -1) { method = decoded.substring(0, idx); password = decoded.substring(idx + 1); }
  } catch (_) {
    final parts = uri.userInfo.split(':');
    if (parts.length >= 2) { method = parts[0]; password = parts.sublist(1).join(':'); }
  }
  if (method.isEmpty) return null;

  final p = uri.queryParameters;
  final extra = <String, dynamic>{'cipher': method, 'password': password, 'udp': true};

  // Plugin support: "obfs-local;obfs=http;obfs-host=example.com"
  final plugin = p['plugin'];
  if (plugin != null && plugin.isNotEmpty) {
    final parts = plugin.split(';');
    extra['plugin'] = parts.first;
    if (parts.length > 1) {
      final opts = <String, dynamic>{};
      for (final opt in parts.skip(1)) {
        final eq = opt.indexOf('=');
        if (eq != -1) {
          opts[opt.substring(0, eq)] = opt.substring(eq + 1);
        }
      }
      if (opts.isNotEmpty) extra['plugin-opts'] = opts;
    }
  }

  // UDP over TCP
  if (p['uot'] == '1' || p['udp-over-tcp'] == 'true') {
    extra['udp-over-tcp'] = true;
  }

  return _Proxy(
    type: 'ss',
    name: _decodeFrag(uri),
    server: host,
    port: uri.port,
    extra: extra,
  );
}

_Proxy? _parseVmess(Uri uri) {
  try {
    final raw = uri.toString().replaceFirst('vmess://', '');
    final json = jsonDecode(utf8.decode(base64.decode(base64.normalize(raw))));
    final host = json['add'] as String? ?? '';
    if (host.isEmpty) return null;
    final net = json['net'] as String? ?? 'tcp';
    final extra = <String, dynamic>{
      'uuid': json['id'] as String? ?? '',
      'alterId': int.tryParse(json['aid'].toString()) ?? 0,
      'cipher': 'auto',
      'udp': true,
      'network': net,
    };
    if ((json['tls'] as String? ?? '') == 'tls') {
      extra['tls'] = true;
      extra['servername'] = json['sni'] as String? ?? json['host'] as String? ?? host;
    }
    if (net == 'ws') {
      extra['ws-opts'] = {
        'path': json['path'] as String? ?? '/',
        'headers': {'Host': json['host'] as String? ?? host},
      };
    }
    return _Proxy(
      type: 'vmess',
      name: json['ps'] as String? ?? host,
      server: host,
      port: int.tryParse(json['port'].toString()) ?? 443,
      extra: extra,
    );
  } catch (_) { return null; }
}

_Proxy? _parseHysteria2(Uri uri) {
  final host = uri.host;
  if (host.isEmpty) return null;
  final p = uri.queryParameters;
  final extra = <String, dynamic>{
    'password': uri.userInfo,
    'sni': p['sni'] ?? host,
    'udp': true,
  };
  if (p['insecure'] == '1') extra['skip-cert-verify'] = true;
  if (p['obfs'] != null) {
    extra['obfs'] = p['obfs'];
    extra['obfs-password'] = p['obfs-password'] ?? '';
  }

  // Bandwidth limits
  if (p['up'] != null && p['up']!.isNotEmpty) extra['up'] = p['up'];
  if (p['down'] != null && p['down']!.isNotEmpty) extra['down'] = p['down'];

  // ALPN (comma-separated → list)
  final alpnStr = p['alpn'];
  if (alpnStr != null && alpnStr.isNotEmpty) {
    extra['alpn'] = alpnStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // Port hopping (mport = "1000-2000" or similar)
  final mport = p['mport'] ?? p['ports'];
  if (mport != null && mport.isNotEmpty) extra['ports'] = mport;

  // Hop interval
  final hopInterval = p['hop-interval'];
  if (hopInterval != null) {
    extra['hop-interval'] = int.tryParse(hopInterval) ?? 30;
  }

  return _Proxy(type: 'hysteria2', name: _decodeFrag(uri), server: host, port: uri.port, extra: extra);
}

String _decodeFrag(Uri uri) {
  final f = uri.fragment;
  if (f.isEmpty) return uri.host;
  try { return Uri.decodeComponent(f); } catch (_) { return f; }
}
