import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/chat/presentation/conversation_list_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/contacts/presentation/contacts_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/call/presentation/call_page.dart';
import '../../features/call/domain/call_state.dart';

final routerProvider = StateNotifierProvider<RouterNotifier, String>((ref) {
  return RouterNotifier();
});

class RouterNotifier extends StateNotifier<String> {
  RouterNotifier() : super('/login');
  
  void goTo(String route) => state = route;
  void goHome() => state = '/home';
  void goLogin() => state = '/login';
  void goRegister() => state = '/register';
  void goChat(String conversationId) => state = '/chat/$conversationId';
  void goContacts() => state = '/contacts';
  void goProfile() => state = '/profile';
  void goCall(String conversationId, CallType type) => state = '/call/$conversationId/${type == CallType.audio ? 'audio' : 'video'}';
}

Widget buildRouter(WidgetRef ref) {
  final route = ref.watch(routerProvider);
  
  if (route.startsWith('/chat/')) {
    final conversationId = route.split('/').last;
    return ChatPage(conversationId: conversationId);
  }
  
  if (route.startsWith('/call/')) {
    final parts = route.split('/');
    final conversationId = parts[2];
    final callTypeStr = parts[3];
    final callType = callTypeStr == 'video' ? CallType.video : CallType.audio;
    return CallPage(conversationId: conversationId, callType: callType);
  }
  
  switch (route) {
    case '/login':
      return const LoginPage();
    case '/register':
      return const RegisterPage();
    case '/home':
      return const ConversationListPage();
    case '/contacts':
      return const ContactsPage();
    case '/profile':
      return const ProfilePage();
    default:
      return const LoginPage();
  }
}