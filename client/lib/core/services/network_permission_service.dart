import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'dart:io' as io;

class NetworkPermissionService {
  static final NetworkPermissionService _instance = NetworkPermissionService._internal();
  factory NetworkPermissionService() => _instance;
  NetworkPermissionService._internal();
  
  bool _hasNetworkPermission = false;
  bool _hasChecked = false;
  
  bool get hasPermission => _hasNetworkPermission;
  bool get hasChecked => _hasChecked;
  
  static const List<Map<String, dynamic>> _testServers = [
    {'host': 'www.baidu.com', 'port': 80, 'name': '百度'},
    {'host': 'www.qq.com', 'port': 80, 'name': '腾讯'},
    {'host': 'www.aliyun.com', 'port': 80, 'name': '阿里云'},
  ];
  
  Future<bool> checkAndRequestPermission() async {
    if (_hasChecked) return _hasNetworkPermission;
    
    _hasChecked = true;
    
    for (final server in _testServers) {
      try {
        final socket = await Socket.connect(
          server['host'] as String,
          server['port'] as int,
          timeout: const Duration(seconds: 3),
        );
        await socket.close();
        _hasNetworkPermission = true;
        debugPrint('Network permission: granted (tested via ${server['name']})');
        return true;
      } catch (e) {
        debugPrint('Failed to connect to ${server['name']}: $e');
        continue;
      }
    }
    
    _hasNetworkPermission = false;
    debugPrint('Network permission: denied');
    return false;
  }
  
  Future<bool> testServerConnection(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Server connection test failed: $e');
      return false;
    }
  }
  
  Future<FirewallResult> addFirewallRule() async {
    try {
      final executablePath = io.Platform.resolvedExecutable;
      final appName = path.basename(executablePath);
      
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          '''
          Start-Process powershell -Verb RunAs -ArgumentList '-Command',
          "New-NetFirewallRule -DisplayName 'Social App' -Direction Inbound -Program '\$executablePath' -Action Allow;
           New-NetFirewallRule -DisplayName 'Social App' -Direction Outbound -Program '\$executablePath' -Action Allow"
          '''
        ],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        debugPrint('Firewall rule added successfully');
        _hasNetworkPermission = true;
        return FirewallResult(
          success: true,
          message: '防火墙规则已添加，请重启应用生效',
        );
      } else {
        debugPrint('Failed to add firewall rule: ${result.stderr}');
        return FirewallResult(
          success: false,
          message: '添加防火墙规则失败：${result.stderr}',
        );
      }
    } catch (e) {
      debugPrint('Error adding firewall rule: $e');
      return FirewallResult(
        success: false,
        message: '添加防火墙规则出错：$e',
      );
    }
  }
  
  Future<bool> checkFirewallRuleExists() async {
    try {
      final executablePath = io.Platform.resolvedExecutable;
      
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          "Get-NetFirewallRule -DisplayName 'Social App' -ErrorAction SilentlyContinue | Select-Object -First 1",
        ],
        runInShell: true,
      );
      
      return result.stdout.toString().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  Future<FirewallResult> requestFirewallPermission() async {
    try {
      final executablePath = io.Platform.resolvedExecutable;
      
      final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$result = [System.Windows.Forms.MessageBox]::Show(
  "应用需要防火墙权限才能正常通讯功能（语音/视频通话）。`n`n点击"是"将添加防火墙规则，需要管理员权限。",
  "防火墙授权请求",
  "YesNo",
  "Warning"
)
if (\$result -eq "Yes") {
  Start-Process powershell -Verb RunAs -ArgumentList "-Command", "New-NetFirewallRule -DisplayName 'Social App' -Direction Inbound -Program '$executablePath' -Action Allow; New-NetFirewallRule -DisplayName 'Social App' -Direction Outbound -Program '$executablePath' -Action Allow; Start-Sleep -Seconds 2"
  "granted"
} else {
  "denied"
}
''';
      
      final result = await Process.run(
        'powershell',
        ['-Command', script],
        runInShell: true,
      );
      
      final output = result.stdout.toString().trim();
      if (output.contains('granted')) {
        return FirewallResult(
          success: true,
          message: '防火墙规则已添加，请重启应用生效',
          needsRestart: true,
        );
      } else {
        return FirewallResult(
          success: false,
          message: '用户取消了授权',
        );
      }
    } catch (e) {
      return FirewallResult(
        success: false,
        message: '请求防火墙权限失败：$e',
      );
    }
  }
}

class FirewallResult {
  final bool success;
  final String message;
  final bool needsRestart;
  
  FirewallResult({
    required this.success,
    required this.message,
    this.needsRestart = false,
  });
}