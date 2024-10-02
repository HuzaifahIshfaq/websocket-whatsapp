import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';
import 'message_model.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late IO.Socket socket;

  SocketService._internal() {
    _connect();
  }

  factory SocketService() {
    return _instance;
  }

  void _connect() {
    socket = IO.io('ws://192.168.2.106:8000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to Socket.IO server');
    });

    socket.onDisconnect((_) {
      print('Disconnected from Socket.IO server');
    });
  }

  onMessages(Function(dynamic) callback) {
    print('On Message..........hasudhasdh');
    socket.on('receive_message', callback);
  }

  void createroom(String roomId, String username) {
    socket.emit('create_room', {'roomId': roomId, 'username': username});
  }

  void getRoomId() {
    print("Getting Room ID");
    print(socket.id);
  }

  void joinroom(String roomId) {
    socket.emit('join_room', roomId);
  }

  void getrooms() {
    socket.emit(
      'get_room',
    );
  }

  void updateseen(Message data) {
    print("Updating Seen");
    socket.emit('update_seen', data.toJson());
  }

  void sendMessage(Map<String, dynamic> data) {
    getRoomId();
    print("Emitting Message");
    socket.emit('send_message', data);
  }

  void disconnect() {
    print("Socekt Disconnected");
    socket.disconnect();
  }
}
