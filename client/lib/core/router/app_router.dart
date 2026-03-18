import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/chat/presentation/conversation_list_page.dart';
import '../../features/chat/presentation/chat_page.dart';
import '../../features/contacts/presentation/contacts_page.dart';
import '../../features/profile/presentation/profile_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

RouterNotifier? _globalRouterNotifier;

final routerProvider = StateNotifierProvider<RouterNotifier, String>((ref) {
  _globalRouterNotifier = RouterNotifier();
  return _globalRouterNotifier!;
});

RouterNotifier? get globalRouterNotifier => _globalRouterNotifier;

class RouterNotifier extends StateNotifier<String> {
  RouterNotifier() : super('/login');
  
  void goTo(String route) => state = route;
  void goHome() => state = '/home';
  void goLogin() => state = '/login';
  void goRegister() => state = '/register';
  void goChat(String conversationId) => state = '/chat/$conversationId';
  void goContacts() => state = '/contacts';
  void goProfile() => state = '/profile';
}

Widget buildRouter(WidgetRef ref) {
  final route = ref.watch(routerProvider);
  
  if (route.startsWith('/chat/')) {
    final conversationId = route.split('/').last;
    return ChatPage(conversationId: conversationId);
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
      return const ProfileTabPage();
    default:
      return const LoginPage();
  }
}