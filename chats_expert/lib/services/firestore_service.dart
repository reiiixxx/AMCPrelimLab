import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // Create a new chat session
  Future<String> createChatSession(String personaId) async {
    if (_userId == null) throw Exception('User not logged in');

    final session = ChatSession(
      id: '', // Will be set by Firestore
      personaId: personaId,
      userId: _userId!,
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chatSessions')
        .add(session.toMap());

    return docRef.id;
  }

  // Get all chat sessions for a persona - FIXED: removed orderBy to avoid index requirement
  Stream<List<ChatSession>> getChatSessions(String personaId) {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('chatSessions')
        .where('personaId', isEqualTo: personaId)
        .snapshots()
        .map((snapshot) {
      // Sort in code instead of in query
      final sessions = snapshot.docs
          .map((doc) => ChatSession.fromMap(doc.id, doc.data()))
          .toList();

      // Sort by lastMessageAt in descending order (newest first)
      sessions.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      return sessions;
    });
  }

  // Add a message to a chat session
  Future<void> addMessage(String sessionId, ChatMessage message) async {
    if (_userId == null) throw Exception('User not logged in');

    // Add message to messages subcollection
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chatSessions')
        .doc(sessionId)
        .collection('messages')
        .add(message.toMap());

    // Update session's lastMessageAt and firstMessage if needed
    final sessionRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('chatSessions')
        .doc(sessionId);

    final sessionDoc = await sessionRef.get();
    final sessionData = sessionDoc.data();

    await sessionRef.update({
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      if (message.isUserMessage && sessionData?['firstMessage'] == null)
        'firstMessage': message.text.length > 50
            ? '${message.text.substring(0, 50)}...'
            : message.text,
    });
  }

  // Get messages for a chat session - FIXED: removed orderBy to avoid index requirement
  Stream<List<ChatMessage>> getMessages(String sessionId) {
    if (_userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('chatSessions')
        .doc(sessionId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      // Sort in code instead of in query
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data()))
          .toList();

      // Sort by timestamp in ascending order (oldest first)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return messages;
    });
  }

  // Delete a chat session
  Future<void> deleteChatSession(String sessionId) async {
    if (_userId == null) throw Exception('User not logged in');

    final sessionRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('chatSessions')
        .doc(sessionId);

    // Delete all messages in the session
    final messagesSnapshot = await sessionRef.collection('messages').get();
    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the session itself
    await sessionRef.delete();
  }

  // Get the most recent chat session for a persona
  Future<ChatSession?> getMostRecentSession(String personaId) async {
    if (_userId == null) return null;

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chatSessions')
        .where('personaId', isEqualTo: personaId)
        .get();

    if (snapshot.docs.isEmpty) return null;

    // Sort in code to get the most recent
    final sessions = snapshot.docs
        .map((doc) => ChatSession.fromMap(doc.id, doc.data()))
        .toList();

    sessions.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    return sessions.first;
  }
}