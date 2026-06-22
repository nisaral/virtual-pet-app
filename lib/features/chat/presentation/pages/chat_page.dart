import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_pet_app/features/pet/application/pet_controller.dart';
import 'package:virtual_pet_app/features/pet/application/llm_chat_service.dart';

/// "Talk" screen - demonstrates RAG + in-character responses.
/// Messages are local only. The pet "remembers" via the RAG service.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _input = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    final controller = ref.read(petControllerProvider.notifier);
    final pet = ref.read(petControllerProvider).value;

    if (pet == null) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _sending = true;
      _input.clear();
    });

    // Record the "talk" action (creates memory)
    await controller.performAction('talk');

    // Generate reply using RAG + real LLM (OpenRouter)
    final result = await LLMChatService.generateReply(pet: pet, userMessage: text);

    // Add a memory of the conversation itself (so future retrieval sees it)
    // (the controller already created a 'talk' memory; we could enhance here)

    await Future.delayed(const Duration(milliseconds: 650)); // "thinking"

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(
        text: result.reply,
        isUser: false,
        memorySnippets: result.usedMemorySnippets,
      ));
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final petAsync = ref.watch(petControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Talk to your pet')),
      body: Column(
        children: [
          Expanded(
            child: petAsync.when(
              data: (_) => ListView.builder(
                padding: const EdgeInsets.all(12),
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[_messages.length - 1 - index];
                  return _ChatBubble(message: msg);
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      hintText: 'Say something to your pet...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_sending,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your pet uses its memories (RAG) to reply in character.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String> memorySnippets;
  _ChatMessage({required this.text, required this.isUser, this.memorySnippets = const []});
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = message.isUser ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(message.text),
          ),
          if (message.memorySnippets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Text(
                '🧠 Recalled: ${message.memorySnippets.first}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}
