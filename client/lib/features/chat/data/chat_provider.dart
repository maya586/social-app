import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart';
import '../domain/conversation.dart';
import '../../auth/data/auth_provider.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

final conversationsProvider = StateNotifierProvider<ConversationsNotifier, AsyncValue<List<Conversation>>>((ref) {
  final authState = ref.watch(authStateProvider);
  final isLoggedIn = authState.hasValue && authState.value != null;
  return ConversationsNotifier(ref.watch(chatRepositoryProvider), isLoggedIn);
});

class ConversationsNotifier extends StateNotifier<AsyncValue<List<Conversation>>> {
  final ChatRepository _repository;
  final bool _isLoggedIn;
  
  ConversationsNotifier(this._repository, this._isLoggedIn) : super(const AsyncValue.data([])) {
    if (_isLoggedIn) {
      loadConversations();
    }
  }
  
  Future<void> loadConversations() async {
    try {
      final conversations = await _repository.getConversations();
      state = AsyncValue.data(conversations);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await loadConversations();
  }
}

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, AsyncValue<List<Message>>, String>((ref, conversationId) {
  return MessagesNotifier(ref.watch(chatRepositoryProvider), conversationId);
});

class MessagesNotifier extends StateNotifier<AsyncValue<List<Message>>> {
  final ChatRepository _repository;
  final String conversationId;
  
  MessagesNotifier(this._repository, this.conversationId) : super(const AsyncValue.loading()) {
    loadMessages();
  }
  
  Future<void> loadMessages() async {
    try {
      final messages = await _repository.getMessages(conversationId);
      state = AsyncValue.data(messages.reversed.toList());
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<void> sendMessage({required String type, String? content, String? mediaUrl, int? duration}) async {
    try {
      final message = await _repository.sendMessage(
        conversationId: conversationId,
        type: type,
        content: content,
        mediaUrl: mediaUrl,
        duration: duration,
      );
      state.whenData((messages) {
        state = AsyncValue.data([...messages, message]);
      });
    } catch (e) {
      // Handle error
    }
  }
  
  void addMessage(Message message) {
    state.whenData((messages) {
      state = AsyncValue.data([...messages, message]);
    });
  }
}