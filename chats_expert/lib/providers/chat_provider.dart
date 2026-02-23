import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/firestore_service.dart';

// Current session provider - tracks which session is active for each persona
final currentSessionProvider = StateProvider<Map<String, String?>>((ref) => {});

// Firestore service provider
final firestoreServiceProvider = Provider((ref) => FirestoreService());

// Provider to get chat sessions for a specific persona
final chatSessionsProvider = StreamProvider.autoDispose.family<List<ChatSession>, String>((ref, personaId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getChatSessions(personaId);
});

// Provider to get messages for a specific session
final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, sessionId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getMessages(sessionId);
});

// State for managing chat operations
class ChatState {
  final Map<String, List<ChatMessage>> chatHistories;

  ChatState({required this.chatHistories});

  ChatState copyWith({Map<String, List<ChatMessage>>? chatHistories}) {
    return ChatState(
      chatHistories: chatHistories ?? this.chatHistories,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final FirestoreService _firestoreService;

  ChatNotifier(this._firestoreService) : super(ChatState(chatHistories: {}));

  void addMessage(String personaId, ChatMessage message) {
    final history = state.chatHistories[personaId] ?? [];
    final updatedHistory = [...history, message];

    state = state.copyWith(
      chatHistories: {...state.chatHistories, personaId: updatedHistory},
    );
  }

  List<ChatMessage> getHistory(String personaId) {
    return state.chatHistories[personaId] ?? [];
  }

  void clearHistory(String personaId) {
    final histories = {...state.chatHistories};
    histories.remove(personaId);
    state = state.copyWith(chatHistories: histories);
  }

  void deleteMessage(String personaId, int messageIndex) {
    final history = state.chatHistories[personaId] ?? [];
    if (messageIndex >= 0 && messageIndex < history.length) {
      final updatedHistory = [...history];
      updatedHistory.removeAt(messageIndex);

      state = state.copyWith(
        chatHistories: {...state.chatHistories, personaId: updatedHistory},
      );
    }
  }

  // Add message to Firestore
  Future<void> addMessageToFirestore(String sessionId, ChatMessage message) async {
    await _firestoreService.addMessage(sessionId, message);
  }

  // Create new chat session
  Future<String> createNewSession(String personaId) async {
    clearHistory(personaId);
    return await _firestoreService.createChatSession(personaId);
  }

  // Delete chat session
  Future<void> deleteSession(String sessionId, String personaId) async {
    await _firestoreService.deleteChatSession(sessionId);
    clearHistory(personaId);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return ChatNotifier(firestoreService);
});