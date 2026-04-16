import 'dart:convert';
import 'dart:typed_data';

/// Universal subscription converter.
/// Accepts:
/// - Clash/Mihomo YAML (returned as-is)
/// - Base64 V2Ray subscription (list of proxy links)
/// - Single proxy link (vless://, trojan://, ss://, hysteria2://)
/// Returns null if content is already valid Clash YAML (no conversion needed).
/// Returns converted Uint8List if conversion was applied.
Uint8List? convertSubscriptionToClash(Uint8List bytes) {
  final text = utf8.decode(bytes, allowMalformed: true).trim();

  // 1. Already looks like Clash YAML
  if (_isClashYaml(text)) return null;

  // 2. Direct single proxy link
  final singleBytes = convertProxyLinkToClash(text);
  if (singleBytes != null) return singleBytes;

  // 3. Base64 V2Ray subscription
  final decoded = _tryBase64Decode(text);
  if (decoded != null) {
    final links = decoded.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty).toList();
    if (links.isNotEmpty && _isProxyLink(links.first)) {
      return _multiLinksToClash(links);
    }
  }

  return null;
}

bool _isClashYaml(String text) {
  return (text.contains('proxies:') || text.contains('proxy-groups:')) &&
      (text.startsWith('proxies:') ||
          text.startsWith('mixed-port:') ||
          text.startsWith('port:') ||
          text.startsWith('mode:') ||
          text.startsWith('dns:'));
}

bool _isProxyLink(String s) {
  final schemes = ['vless://', 'vmess://', 'trojan://', 'ss://', 'hysteria2://', 'hy2://'];
  return schemes.any((sc) => s.startsWith(sc));
}

String? _tryBase64Decode(String text) {
  try {
    final normalized = base64.normalize(text.replaceAll(RegExp(r'\s'), ''));
    return utf8.decode(base64.decode(normalized));
  } catch (_) {
    return null;
  }
}

Uint8List _multiLinksToClash(List<String> links) {
  final proxies = <Map<String, dynamic>>[];

  for (final link in links) {
    final proxy = _parseLinkToMap(link.trim());
    if (proxy != null) proxies.add(proxy);
  }

  if (proxies.isEmpty) {
    return Uint8List.fromList(utf8.encode('proxies: []\nrules:\n- MATCH,DIRECT\n'));
  }

  final sb = StringBuffer();
  sb.writeln('proxies:');
  for (final p in proxies) {
    sb.write(_mapToYaml(p));
  }

  sb.writeln('proxy-groups:');
  sb.writeln('- name: PROXY');
  sb.writeln('  type: select');
  sb.writeln('  proxies:');
  for (final p in proxies) {
    sb.writeln('  - "${_escape(p['name'] as String)}"');
  }

  sb.writeln('rules:');
  sb.writeln('- MATCH,PROXY');

  return Uint8List.fromList(utf8.encode(sb.toString()));
}

Map<String, dynamic>? _parseLinkToMap(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null) return null;

  switch (uri.scheme.toLowerCase()) {
    case 'vless':
      return _parseVless(uri);
    case 'trojan':
      return _parseTrojan(uri);
    case 'ss':
      return _parseSs(uri);
    case 'vmess':
      return _parseVmess(uri);
    case 'hysteria2':
    case 'hy2':
      return _parseHysteria2(uri);
    default:
      return null;
  }
}

Map<String, dynamic>? _parseVless(Uri uri) {
  final uuid = uri.userInfo;
  final host = uri.host;
  final port = uri.port;
  final p = uri.queryParameters;
  final name = Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : host);
  final network = p['type'] ?? 'tcp';
  final security = p['security'] ?? '';

  if (uuid.isEmpty || host.isEmpty) return null;

  final proxy = <String, dynamic>{
    'type': 'vless',
    'name': name,
    'server': host,
    'port': port,
    'uuid': uuid,
    'udp': true,
    'network': network == 'xhttp' ? 'xhttp' : network == 'ws' ? 'ws' : network == 'grpc' ? 'grpc' : 'tcp',
  };

  final sni = p['sni'] ?? p['host'] ?? host;
  if (security == 'reality') {
    proxy['tls'] = true;
    proxy['servername'] = sni;
    proxy['client-fingerprint'] = p['fp'] ?? 'chrome';
    proxy['reality-opts'] = {
      'public-key': p['pbk'] ?? '',
      'short-id': p['sid'] ?? '',
    };
  } else if (security == 'tls') {
    proxy['tls'] = true;
    proxy['servername'] = sni;
  }

  if (network == 'ws') {
    proxy['ws-opts'] = {
      'path': p['path'] ?? '/',
      'headers': {'Host': p['host'] ?? host},
    };
  } else if (network == 'xhttp' || network == 'splithttp') {
    proxy['network'] = 'xhttp';
    proxy['xhttp-opts'] = {
      'path': p['path'] ?? '/',
      'host': p['host'] ?? host,
      if (p['mode'] != null) 'mode': p['mode'],
    };
  } else if (network == 'grpc') {
    proxy['grpc-opts'] = {'grpc-service-name': p['serviceName'] ?? ''};
  }

  return proxy;
}

Map<String, dynamic>? _parseTrojan(Uri uri) {
  final host = uri.host;
  final port = uri.port;
  final p = uri.queryParameters;
  final name = Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : host);
  if (host.isEmpty) return null;
  return {
    'type': 'trojan',
    'name': name,
    'server': host,
    'port': port,
    'password': uri.userInfo,
    'sni': p['sni'] ?? p['peer'] ?? host,
    'udp': true,
  };
}

Map<String, dynamic>? _parseSs(Uri uri) {
  final host = uri.host;
  final port = uri.port;
  final name = Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : host);
  if (host.isEmpty) return null;

  String method = '', password = '';
  try {
    final decoded = utf8.decode(base64.decode(base64.normalize(uri.userInfo)));
    final idx = decoded.indexOf(':');
    if (idx != -1) {
      method = decoded.substring(0, idx);
      password = decoded.substring(idx + 1);
    }
  } catch (_) {
    final parts = uri.userInfo.split(':');
    if (parts.length >= 2) {
      method = parts[0];
      password = parts.sublist(1).join(':');
    }
  }

  if (method.isEmpty) return null;
  return {
    'type': 'ss',
    'name': name,
    'server': host,
    'port': port,
    'cipher': method,
    'password': password,
    'udp': true,
  };
}

Map<String, dynamic>? _parseVmess(Uri uri) {
  try {
    final json = jsonDecode(utf8.decode(base64.decode(base64.normalize(uri.path))));
    final name = json['ps'] as String? ?? json['add'] as String? ?? 'vmess';
    final host = json['add'] as String? ?? '';
    final port = int.tryParse(json['port'].toString()) ?? 443;
    if (host.isEmpty) return null;
    final net = json['net'] as String? ?? 'tcp';
    final proxy = <String, dynamic>{
      'type': 'vmess',
      'name': name,
      'server': host,
      'port': port,
      'uuid': json['id'] as String? ?? '',
      'alterId': int.tryParse(json['aid'].toString()) ?? 0,
      'cipher': 'auto',
      'udp': true,
      'network': net,
    };
    final tls = json['tls'] as String? ?? '';
    if (tls == 'tls') {
      proxy['tls'] = true;
      proxy['servername'] = json['sni'] as String? ?? json['host'] as String? ?? host;
    }
    if (net == 'ws') {
      proxy['ws-opts'] = {
        'path': json['path'] as String? ?? '/',
        'headers': {'Host': json['host'] as String? ?? host},
      };
    }
    return proxy;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _parseHysteria2(Uri uri) {
  final host = uri.host;
  final port = uri.port;
  final p = uri.queryParameters;
  final name = Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : host);
  if (host.isEmpty) return null;
  final proxy = <String, dynamic>{
    'type': 'hysteria2',
    'name': name,
    'server': host,
    'port': port,
    'password': uri.userInfo,
    'udp': true,
  };
  final sni = p['sni'] ?? host;
  proxy['sni'] = sni;
  if (p['insecure'] == '1') proxy['skip-cert-verify'] = true;
  final obfs = p['obfs'];
  if (obfs != null) {
    proxy['obfs'] = obfs;
    proxy['obfs-password'] = p['obfs-password'] ?? '';
  }
  return proxy;
}

String _mapToYaml(Map<String, dynamic> map, {int indent = 0}) {
  final sb = StringBuffer();
  final prefix = ' ' * indent;
  map.forEach((k, v) {
    if (v is Map) {
      sb.writeln('$prefix$k:');
      v.forEach((k2, v2) {
        if (v2 is Map) {
          sb.writeln('$prefix  $k2:');
          v2.forEach((k3, v3) {
            sb.writeln('$prefix    $k3: ${_yamlValue(v3)}');
          });
        } else {
          sb.writeln('$prefix  $k2: ${_yamlValue(v2)}');
        }
      });
    } else {
      sb.writeln('$prefix$k: ${_yamlValue(v)}');
    }
  });
  return sb.toString();
}

String _yamlValue(dynamic v) {
  if (v is String) return '"${_escape(v)}"';
  if (v is bool) return v ? 'true' : 'false';
  return v.toString();
}

/// Converts a single proxy link to Clash YAML bytes.
/// Returns null if not a recognized proxy link.
Uint8List? convertProxyLinkToClash(String url) {
  if (!_isProxyLink(url)) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final proxy = _parseLinkToMap(url);
  if (proxy == null) return null;

  final name = proxy['name'] as String;
  final sb = StringBuffer();
  sb.writeln('proxies:');
  sb.write('- ');
  sb.write(_mapToYaml(proxy));
  sb.writeln('proxy-groups:');
  sb.writeln('- name: PROXY');
  sb.writeln('  type: select');
  sb.writeln('  proxies:');
  sb.writeln('  - "${_escape(name)}"');
  sb.writeln('rules:');
  sb.writeln('- MATCH,PROXY');
  return Uint8List.fromList(utf8.encode(sb.toString()));
}

String _escape(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
