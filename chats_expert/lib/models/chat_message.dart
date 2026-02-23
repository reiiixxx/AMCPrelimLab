import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String text;
  final String role;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
  });

  bool get isUserMessage => role == "user";

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'role': role,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Create from Firestore document
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      role: map['role'] ?? 'user',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}