import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'message_model.dart';

class SocketService {
  late IO.Socket _socket;
  static final SocketService _instance = SocketService._internal();

  SocketService._internal() {
    _connect();
  }

  factory SocketService() {
    return _instance;
  }
  IO.Socket get socket => _socket;

  void _connect() {
    _socket = IO.io('ws://192.168.2.106:8000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket.connect();

    _socket.onConnect((_) {
      print('Connected to Socket.IO server');
    });

    _socket.onDisconnect((_) {
      print('Disconnected from Socket.IO server');
    });
  }

  void onMessages(Function(dynamic) callback) {
    print('On Message yoyo');
    _socket.on('receive_message', (data) {
      print('Message received from server: socket $data');
      callback(data);
    });
    print('On Message..');
  }

  void ListenSeenUpdate(Function(dynamic) callback) {
    print('On Listening yoyo');
    _socket.on('listen_seen_update', (data) {
      print('listen received from server: socket $data');
      callback(data);
    });
  }

  void ListenSeenUpdateforall(Function(dynamic) callback) {
    print("tag 50");
    _socket.on('listen_update_seen_for_all', (data) {
      print('listen received from server: socket $data');
      callback(data);
    });
  }

  void createroom(int roomId, String username) {
    _socket.emit('create_room', {'roomId': roomId, 'username': username});
  }

  void getRoomId() {
    print(_socket.id);
  }

  void joinroom(int roomId) {
    _socket.emit('join_room', roomId);
  }

  void getrooms() {
    _socket.emit('get_room');
  }

  void updateseen(Message data) {
    print("Updating Seen");
    _socket.emit('update_seen', data.toJson());
  }

  void updateseenforall(int roomId, String username) {
    print("Updating Seen for all");
    final data = {
      'roomId': roomId,
      'username': username,
    };
    _socket.emit('update_seen_for_all', data);
  }

  void deletemessage(String messageid) {
    print("message deleted from socket $messageid");
    _socket.emit('delete_message', messageid);
  }

  void deletemessageforEveryone(String messageid) {
    print("message deleted from socket $messageid");
    _socket.emit('delete_for_everyone', messageid);
  }

  void DeleteMessageListenForEveryone(Function(dynamic) callback) {
    print('message delete notification received from admin');
    _socket.on('listen_delete_message', (data) {
      print('listen received from server: socket $data');
      callback(data);
    });
  }

  void sendMessage(Map<String, dynamic> data) {
    print("Emitting Message");
    _socket.emit('send_message', data);
  }

  void disconnect() {
    print("Socket Disconnected");
    _socket.disconnect();
  }

  void receivemessageoff() {
    print("off message");
    _socket.off("receive_message");
  }
}
