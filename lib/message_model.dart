class Message {
  final String messageId;
  final dynamic roomId;
  final String sender;
  final String? message;
  bool seen;
  final String timestamp;
  final String? type;
  final String? fileType;
  final String? name;
  final dynamic data;

  Message({
    required this.messageId,
    required this.roomId,
    required this.sender,
    this.message,
    required this.timestamp,
    this.seen = false,
    this.type,
    this.fileType,
    this.name,
    this.data,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
        messageId: json['messageId'],
        roomId: json['roomId'],
        sender: json['sender'],
        message: json['message'],
        timestamp: json['time'],
        seen: json['seen'] == 1,
        type: json['type'],
        fileType: json['fileType'],
        name: json['name'],
        data: json['data']);
  }

  Map<String, dynamic> toJson() {
    print(data);
    return {
      'messageId': messageId,
      'roomId': roomId,
      'sender': sender,
      'message': message as String?,
      'time': timestamp,
      'seen': seen ? 1 : 0,
      'type': type,
      'fileType': fileType,
      'name': name,
      'data': data
    };
  }
}
