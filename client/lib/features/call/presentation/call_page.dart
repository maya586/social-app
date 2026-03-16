import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CallType {
  static const String audio = 'audio';
  static const String video = 'video';
}

class CallPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String callType;
  
  const CallPage({
    super.key,
    required this.conversationId,
    required this.callType,
  });
  
  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.callType == CallType.video ? '视频通话' : '语音通话'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              '通话功能需要完整版客户端',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}