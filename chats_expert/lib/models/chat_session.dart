import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSession {
  final String id;
  final String personaId;
  final String userId;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String? firstMessage; // Preview of first user message

  ChatSession({
    required this.id,
    required this.personaId,
    required this.userId,
    required this.createdAt,
    required this.lastMessageAt,
    this.firstMessage,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'personaId': personaId,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'firstMessage': firstMessage,
    };
  }

  // Create from Firestore document
  factory ChatSession.fromMap(String id, Map<String, dynamic> map) {
    return ChatSession(
      id: id,
      personaId: map['personaId'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firstMessage: map['firstMessage'],
    );
  }

  ChatSession copyWith({
    String? id,
    String? personaId,
    String? userId,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? firstMessage,
  }) {
    return ChatSession(
      id: id ?? this.id,
      personaId: personaId ?? this.personaId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      firstMessage: firstMessage ?? this.firstMessage,
    );
  }
}