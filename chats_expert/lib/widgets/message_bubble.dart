import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Color personaColor;
  final bool isStreaming;
  final String? personaEmoji;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.personaColor,
    this.isStreaming = false,
    this.personaEmoji,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUserMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // PERSONA ICON (left side for AI messages)
          if (!message.isUserMessage) ...[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: personaColor.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 24,
                child: CircleAvatar(
                  backgroundColor: personaColor,
                  radius: 22,
                  child: Text(
                    personaEmoji ?? '🤖',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              decoration: BoxDecoration(
                color: message.isUserMessage
                    ? Colors.black
                    : personaColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: message.isUserMessage
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.isUserMessage)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        message.text,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Check if message contains disclaimer
                          if (message.text.contains('⚠️ Disclaimer:') ||
                              message.text.contains('Disclaimer:')) ...[
                            // Split message into main content and disclaimer
                            MarkdownBody(
                              data: message.text.split(RegExp(r'⚠️?\s*Disclaimer:')).first,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                                code: TextStyle(
                                  backgroundColor: personaColor.withOpacity(0.2),
                                  color: Colors.black,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: personaColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Separator line
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: Colors.black.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            // Disclaimer section
                            MarkdownBody(
                              data: message.text.contains('⚠️ Disclaimer:')
                                  ? '⚠️ Disclaimer:${message.text.split('⚠️ Disclaimer:').last}'
                                  : 'Disclaimer:${message.text.split('Disclaimer:').last}',
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ] else
                          // No disclaimer, just show the message normally
                            MarkdownBody(
                              data: message.text,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                                code: TextStyle(
                                  backgroundColor: personaColor.withOpacity(0.2),
                                  color: Colors.black,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: personaColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 8, left: 12),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(personaColor),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // USER ICON (right side for user messages)
          if (message.isUserMessage) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.black,
              radius: 18,
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}