import 'dart:convert';
import 'dart:typed_data';

/// Converts proxy share links (vless://, vmess://, ss://, trojan://)
/// to a minimal Clash/Mihomo YAML configuration.
/// Returns null if the URL is not a recognized proxy link.
Uint8List? convertProxyLinkToClash(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  final scheme = uri.scheme.toLowerCase();

  if (scheme == 'vless') {
    return _vlessToClash(uri);
  }
  if (scheme == 'trojan') {
    return _trojanToClash(uri);
  }
  if (scheme == 'ss') {
    return _ssToClash(uri);
  }
  return null;
}

Uint8List? _vlessToClash(Uri uri) {
  final uuid = uri.userInfo;
  final host = uri.host;
  final port = uri.port;
  final params = uri.queryParameters;
  final name = Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : host);
  final network = params['type'] ?? 'tcp';
  final security = params['security'] ?? '';
  final sni = params['sni'] ?? params['host'] ?? host;
  final fp = params['fp'] ?? 'chrome';

  if (uuid.isEmpty || host.isEmpty) return null;

  final sb = StringBuffer();
  sb.writeln('proxies:');
  sb.writeln('- type: vless');
  sb.writeln('  name: "${_escape(name)}"');
  sb.writeln('  server: $host');
  sb.writeln('  port: $port');
  sb.writeln('  uuid: $uuid');
  sb.writeln('  udp: true');

  if (security == 'reality') {
    final pbk = params['pbk'] ?? '';
    final sid = params['sid'] ?? '';
    sb.writeln('  tls: true');
    sb.writeln('  servername: $sni');
    sb.writeln('  client-fingerprint: $fp');
    sb.writeln('  reality-opts:');
    sb.writeln('    public-key: $pbk');
    sb.writeln('    short-id: $sid');
  } else if (security == 'tls') {
    sb.writeln('  tls: true');
    sb.writeln('  servername: $sni');
    sb.writeln('  client-fingerprint: $fp');
  }

  if (network == 'ws') {
    final wsPath = params['path'] ?? '/';
    final wsHost = params['host'] ?? host;
    sb.writeln('  network: ws');
    sb.writeln('  ws-opts:');
    sb.writeln('    path: "$wsPath"');
    sb.writeln('    headers:');
    sb.writeln('      Host: $wsHost');
  } else if (network == 'grpc') {
    final svcName = params['serviceName'] ?? '';
    sb.writeln('  network: grpc');
    sb.writeln('  grpc-opts:');
    sb.writeln('    grpc-service-name: $svcName');
  } else if (network == 'xhttp' || network == 'splithttp') {
    final xPath = params['path'] ?? '/';
    final xHost = params['host'] ?? host;
    sb.writeln('  network: xhttp');
    sb.writeln('  xhttp-opts:');
    sb.writeln('    path: "$xPath"');
    sb.writeln('    headers:');
    sb.writeln('      Host: $xHost');
    final mode = params['mode'];
    if (mode != null) sb.writeln('    mode: $mode');
  } else {
    sb.writeln('  network: tcp');
  }

  _appendProxyGroupAndRules(sb, name);
  return Uint8List.fromList(utf8.encode(sb.toString()));
}

Uint8List? _trojanToClash(Uri uri) {
  final password = uri.userInfo;
  final host = uri.host;
  final port = uri.port;
  final params = uri.queryParameters;
  final name = Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : host);
  final sni = params['sni'] ?? params['peer'] ?? host;

  if (password.isEmpty || host.isEmpty) return null;

  final sb = StringBuffer();
  sb.writeln('proxies:');
  sb.writeln('- type: trojan');
  sb.writeln('  name: "${_escape(name)}"');
  sb.writeln('  server: $host');
  sb.writeln('  port: $port');
  sb.writeln('  password: $password');
  sb.writeln('  sni: $sni');
  sb.writeln('  udp: true');

  _appendProxyGroupAndRules(sb, name);
  return Uint8List.fromList(utf8.encode(sb.toString()));
}

Uint8List? _ssToClash(Uri uri) {
  final host = uri.host;
  final port = uri.port;
  final name = Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : host);

  // ss://BASE64(method:password)@host:port or ss://BASE64@host:port
  String method = '';
  String password = '';
  try {
    final decoded = utf8.decode(base64.decode(base64.normalize(uri.userInfo)));
    final idx = decoded.indexOf(':');
    if (idx != -1) {
      method = decoded.substring(0, idx);
      password = decoded.substring(idx + 1);
    }
  } catch (_) {
    final parts = uri.userInfo.split(':');
    if (parts.length == 2) {
      method = parts[0];
      password = parts[1];
    }
  }

  if (host.isEmpty || method.isEmpty) return null;

  final sb = StringBuffer();
  sb.writeln('proxies:');
  sb.writeln('- type: ss');
  sb.writeln('  name: "${_escape(name)}"');
  sb.writeln('  server: $host');
  sb.writeln('  port: $port');
  sb.writeln('  cipher: $method');
  sb.writeln('  password: "${_escape(password)}"');
  sb.writeln('  udp: true');

  _appendProxyGroupAndRules(sb, name);
  return Uint8List.fromList(utf8.encode(sb.toString()));
}

void _appendProxyGroupAndRules(StringBuffer sb, String name) {
  sb.writeln('proxy-groups:');
  sb.writeln('- name: PROXY');
  sb.writeln('  type: select');
  sb.writeln('  proxies:');
  sb.writeln('  - "${_escape(name)}"');
  sb.writeln('rules:');
  sb.writeln('- MATCH,PROXY');
}

String _escape(String s) => s.replaceAll('"', '\\"');
