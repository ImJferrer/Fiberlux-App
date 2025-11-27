class PreticketMessage {
  final int id;
  final int preticketId;
  final int authorId;
  final String username;
  final String firstName;
  final String lastName;
  final String message;
  final DateTime createdAt;

  PreticketMessage({
    required this.id,
    required this.preticketId,
    required this.authorId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.message,
    required this.createdAt,
  });

  factory PreticketMessage.fromJson(Map<String, dynamic> json) {
    return PreticketMessage(
      id: (json['id'] as num).toInt(),
      preticketId: (json['preticket_id'] as num).toInt(),
      authorId: (json['author_id'] as num).toInt(),
      username: (json['author__username'] ?? '').toString(),
      firstName: (json['author__first_name'] ?? '').toString(),
      lastName: (json['author__last_name'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}
