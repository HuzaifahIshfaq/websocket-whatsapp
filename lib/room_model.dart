import 'message_model.dart';

class sendmessage {
  final String? roomid;
  final Message? message;

  sendmessage({this.roomid, required this.message});

  Map<String, dynamic> toJson() {
    return {'message': message, 'roomId': roomid};
  }
}
