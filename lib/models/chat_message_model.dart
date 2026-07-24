import 'ai_chat_model.dart';
import 'wallet_model.dart';

enum ChatRole { user, assistant }

enum ChatMessageType {
  text,
  transactionPreview,
  statisticCard,
  warningCard,
  errorCard,
}

enum ChatMessageStatus { sending, sent, failed }

class ChatMessageModel {
  final String id;
  final ChatRole role;
  ChatMessageType type;
  String content;
  final DateTime createdAt;
  ChatMessageStatus status;
  AiChatResult? transactionPreview;
  WalletModel? wallet;
  Map<String, dynamic>? statisticCard;
  String? retryText;
  bool saved;
  bool saving;
  bool cancelled;

  ChatMessageModel({
    required this.id,
    required this.role,
    required this.type,
    required this.content,
    DateTime? createdAt,
    this.status = ChatMessageStatus.sent,
    this.transactionPreview,
    this.wallet,
    this.statisticCard,
    this.retryText,
    this.saved = false,
    this.saving = false,
    this.cancelled = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == ChatRole.user;
}
