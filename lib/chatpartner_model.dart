class ChatPartner {
  final String currentUser;
  final String partnerUser;
  final String roomId;

  ChatPartner({
    required this.currentUser,
    required this.partnerUser,
    required this.roomId,
  });

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'currentUser': currentUser,
      'partnerUser': partnerUser,
      'roomId': roomId,
    };
  }

  // JSON deserialization
  factory ChatPartner.fromJson(Map<String, dynamic> json) {
    return ChatPartner(
      currentUser: json['currentUser'],
      partnerUser: json['partnerUser'],
      roomId: json['roomId'],
    );
  }
}
