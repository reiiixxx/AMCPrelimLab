import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/persona.dart';
import '../models/chat_session.dart';
import '../providers/chat_provider.dart';
import '../providers/persona_provider.dart';
import '../services/gemini_service.dart';
import '../services/response_validator.dart';
import '../widgets/input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _currentSessionId;
  bool _isInitialized = false;
  String? _lastPersonaId; // Track which persona we're currently showing

  @override
  void initState() {
    super.initState();
    // Defer initialization to after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSession();
    });
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset initialization when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final persona = ref.read(selectedPersonaProvider);
      if (persona != null && mounted) {
        final sessions = ref.read(currentSessionProvider);
        final sessionId = sessions[persona.id];
        if (sessionId != null && sessionId != _currentSessionId) {
          setState(() {
            _currentSessionId = sessionId;
            _isInitialized = true;
          });
        } else if (!_isInitialized) {
          _initializeSession();
        }
      }
    });
  }

  Future<void> _initializeSession() async {
    final persona = ref.read(selectedPersonaProvider);
    if (persona == null) return;

    // If persona changed, reset initialization
    if (_lastPersonaId != null && _lastPersonaId != persona.id) {
      setState(() {
        _isInitialized = false;
        _currentSessionId = null;
      });
    }

    if (_isInitialized && _lastPersonaId == persona.id) return;

    _lastPersonaId = persona.id;

    // Get existing session for this persona - DON'T AUTO-CREATE
    final sessions = ref.read(currentSessionProvider);
    final existingSessionId = sessions[persona.id];

    if (existingSessionId != null) {
      setState(() {
        _currentSessionId = existingSessionId;
        _isInitialized = true;
      });
    } else {
      // Load most recent session if exists
      final firestoreService = ref.read(firestoreServiceProvider);
      final recentSession = await firestoreService.getMostRecentSession(persona.id);

      if (recentSession != null) {
        setState(() {
          _currentSessionId = recentSession.id;
          _isInitialized = true;
        });

        final updatedSessions = {...ref.read(currentSessionProvider)};
        updatedSessions[persona.id] = recentSession.id;
        ref.read(currentSessionProvider.notifier).state = updatedSessions;
      } else {
        // No session exists - create one automatically
        final chatNotifier = ref.read(chatProvider.notifier);
        final newSessionId = await chatNotifier.createNewSession(persona.id);

        setState(() {
          _currentSessionId = newSessionId;
          _isInitialized = true;
        });

        final updatedSessions = {...ref.read(currentSessionProvider)};
        updatedSessions[persona.id] = newSessionId;
        ref.read(currentSessionProvider.notifier).state = updatedSessions;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _createNewChat() async {
    final persona = ref.read(selectedPersonaProvider);
    if (persona == null) return;

    try {
      // Create new session in Firestore
      final sessionId = await ref.read(chatProvider.notifier).createNewSession(persona.id);

      // Update current session
      setState(() {
        _currentSessionId = sessionId;
        _isInitialized = true;
        _lastPersonaId = persona.id;
      });

      // Update session map
      final sessions = {...ref.read(currentSessionProvider)};
      sessions[persona.id] = sessionId;
      ref.read(currentSessionProvider.notifier).state = sessions;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New chat started'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isInitialized = true;
      });
      if (mounted) {
        _showErrorDialog('Failed to create new chat: $e');
      }
    }
  }

  Future<void> _handleSendMessage(String text) async {
    final persona = ref.read(selectedPersonaProvider);
    if (persona == null || _currentSessionId == null) return;

    // Add user message
    final userMessage = ChatMessage(
      text: text,
      role: 'user',
      timestamp: DateTime.now(),
    );

    // Add to local state
    ref.read(chatProvider.notifier).addMessage(persona.id, userMessage);

    // Add to Firestore
    await ref.read(chatProvider.notifier).addMessageToFirestore(_currentSessionId!, userMessage);

    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      // Get conversation history
      final history = ref.read(chatProvider.notifier).getHistory(persona.id);

      // Send to Gemini
      final response = await GeminiService.sendMessage(
        systemPrompt: persona.systemPrompt,
        conversationHistory: history.sublist(0, history.length - 1),
        newUserMessage: text,
      );

      // Validate response
      final validation = ResponseValidator.validateResponse(persona.id, response);

      if (!validation.isValid && validation.violatingDomain != null) {
        // AI broke character - show warning
        _showViolationDialog(validation.suggestedPersona ?? 'another persona');
      }

      // ✅ ADD DISCLAIMER TO EVERY AI RESPONSE
      final responseWithDisclaimer = '$response\n\n${persona.disclaimer}';

      // Add AI response
      final aiMessage = ChatMessage(
        text: responseWithDisclaimer,
        role: 'model',
        timestamp: DateTime.now(),
      );

      // Add to local state
      ref.read(chatProvider.notifier).addMessage(persona.id, aiMessage);

      // Add to Firestore
      await ref.read(chatProvider.notifier).addMessageToFirestore(_currentSessionId!, aiMessage);

      _scrollToBottom();
    } catch (e) {
      _showErrorDialog('Failed to send message: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showViolationDialog(String suggestedPersona) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Domain Violation Detected'),
        content: Text(
          'The AI may have provided information outside its domain. '
              'Consider switching to $suggestedPersona for better results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _loadChatHistory(ChatSession session) {
    final persona = ref.read(selectedPersonaProvider);
    if (persona == null) return;

    setState(() => _currentSessionId = session.id);

    // Update current session
    final sessions = {...ref.read(currentSessionProvider)};
    sessions[persona.id] = session.id;
    ref.read(currentSessionProvider.notifier).state = sessions;

    // Clear local history to force reload from Firestore
    ref.read(chatProvider.notifier).clearHistory(persona.id);

    Navigator.pop(context); // Close menu
  }

  void _showBurgerMenu() {
    final currentPersona = ref.read(selectedPersonaProvider);
    if (currentPersona == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: MediaQuery.of(context).size.height,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 20,
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // New Chat Button
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _createNewChat();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('New Chat'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const Divider(color: Colors.grey, height: 32),

                          // SWITCH AI PERSONA SECTION
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'SWITCH AI PERSONA',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400],
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ALL PERSONAS LIST
                          ...PersonaData.personas.map((persona) {
                            final isSelected = currentPersona.id == persona.id;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? persona.color.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: persona.color, width: 2)
                                    : null,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: persona.color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(persona.icon, color: persona.color, size: 24),
                                ),
                                title: Text(
                                  persona.name,
                                  style: TextStyle(
                                    color: isSelected ? persona.color : Colors.black,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  _getPersonaDescription(persona.id),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle, color: persona.color)
                                    : null,
                                onTap: () {
                                  if (!isSelected) {
                                    ref.read(selectedPersonaProvider.notifier).state = persona;
                                    Navigator.pop(context);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ChatScreen()),
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),

                          const Divider(color: Colors.grey, height: 32),

                          // CHAT HISTORY SECTION - ALL PERSONAS COMBINED
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'CHAT HISTORY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400],
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Combined chat history from ALL personas
                          Consumer(
                            builder: (context, ref, child) {
                              // Get all sessions from all personas
                              final allSessionsAsyncList = PersonaData.personas.map((persona) {
                                return ref.watch(chatSessionsProvider(persona.id));
                              }).toList();

                              // Combine all sessions
                              List<ChatSession> allSessions = [];
                              bool isLoading = false;
                              bool hasError = false;

                              for (var sessionAsync in allSessionsAsyncList) {
                                sessionAsync.when(
                                  data: (sessions) => allSessions.addAll(sessions),
                                  loading: () => isLoading = true,
                                  error: (_, __) => hasError = true,
                                );
                              }

                              if (isLoading && allSessions.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (hasError && allSessions.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'Error loading history',
                                    style: TextStyle(color: Colors.red[300]),
                                  ),
                                );
                              }

                              if (allSessions.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'No chat history yet',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }

                              // Sort all sessions by lastMessageAt (most recent first)
                              allSessions.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

                              return Column(
                                children: allSessions.map((session) {
                                  final persona = PersonaData.getPersonaById(session.personaId);
                                  final isCurrentSession = session.id == _currentSessionId;

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCurrentSession
                                          ? persona.color.withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isCurrentSession
                                          ? Border.all(color: persona.color.withValues(alpha: 0.5))
                                          : null,
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: persona.color.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getPersonaEmoji(persona.id),
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                                      title: Text(
                                        session.firstMessage ?? 'New chat',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Row(
                                        children: [
                                          Text(
                                            persona.name,
                                            style: TextStyle(
                                              color: persona.color,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            ' • ${_formatTimestamp(session.lastMessageAt)}',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrentSession)
                                            Icon(
                                              Icons.circle,
                                              color: persona.color,
                                              size: 12,
                                            ),
                                          if (isCurrentSession) const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  backgroundColor: Colors.white,
                                                  title: const Text(
                                                    'Delete Chat',
                                                    style: TextStyle(color: Colors.black),
                                                  ),
                                                  content: Text(
                                                    'Are you sure you want to delete this chat?',
                                                    style: TextStyle(color: Colors.grey[700]),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        await ref.read(chatProvider.notifier).deleteSession(
                                                          session.id,
                                                          persona.id,
                                                        );

                                                        // If deleting current session, clear it
                                                        if (session.id == _currentSessionId) {
                                                          setState(() {
                                                            _currentSessionId = null;
                                                          });
                                                        }
                                                        Navigator.pop(ctx);
                                                      },
                                                      child: const Text(
                                                        'Delete',
                                                        style: TextStyle(color: Colors.red),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      onTap: () => _loadChatHistory(session),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  String _getPersonaDescription(String id) {
    switch (id) {
      case 'translator':
        return 'Language & Translation';
      case 'games':
        return 'Video & Board Games';
      case 'sports':
        return 'Athletic Training';
      case 'chef':
        return 'Cooking & Recipes';
      case 'musician':
        return 'Music Theory';
      default:
        return '';
    }
  }

  String _getPersonaEmoji(String id) {
    switch (id) {
      case 'translator':
        return '🌐';
      case 'games':
        return '🎮';
      case 'sports':
        return '⚽';
      case 'chef':
        return '👨‍🍳';
      case 'musician':
        return '🎵';
      default:
        return '🤖';
    }
  }

  @override
  Widget build(BuildContext context) {
    final persona = ref.watch(selectedPersonaProvider);
    if (persona == null) {
      return const Scaffold(
        body: Center(child: Text('No persona selected')),
      );
    }

    // Check if persona changed and reinitialize if needed
    if (_lastPersonaId != persona.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeSession();
      });
    }

    // Don't try to watch messages until we have a session ID
    if (!_isInitialized || _currentSessionId == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _showBurgerMenu,
            tooltip: 'Menu',
          ),
          title: Row(
            children: [
              Icon(persona.icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(persona.name),
            ],
          ),
          backgroundColor: persona.color,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                Navigator.pop(context);
              },
              tooltip: 'Back to Dashboard',
            ),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Now safe to watch messages
    final messagesAsync = ref.watch(chatMessagesProvider(_currentSessionId!));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _showBurgerMenu,
          tooltip: 'Menu',
        ),
        title: Row(
          children: [
            Icon(persona.icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(persona.name),
          ],
        ),
        backgroundColor: persona.color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pop(context);
            },
            tooltip: 'Back to Dashboard',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          persona.icon,
                          size: 80,
                          color: persona.color.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start chatting with ${persona.name}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Sync messages to local state for sending
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final localHistory = ref.read(chatProvider.notifier).getHistory(persona.id);
                  if (localHistory.length != messages.length) {
                    // Clear and reload
                    ref.read(chatProvider.notifier).clearHistory(persona.id);
                    for (var message in messages) {
                      ref.read(chatProvider.notifier).addMessage(persona.id, message);
                    }
                    _scrollToBottom();
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(
                      message: messages[index],
                      personaColor: persona.color,
                      personaEmoji: _getPersonaEmoji(persona.id), // ✅ Pass emoji
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading messages'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _createNewChat(),
                      child: const Text('Start New Chat'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(persona.color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${persona.name} is thinking...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          InputBar(onSendMessage: _handleSendMessage),
        ],
      ),
    );
  }
}