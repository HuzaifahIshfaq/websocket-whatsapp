import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chatpage.dart';

class Chatlist extends StatefulWidget {
  final String currentUser;
  final int userId;

  const Chatlist({super.key, required this.currentUser, required this.userId});

  @override
  State<Chatlist> createState() => _ChatlistState();
}

class _ChatlistState extends State<Chatlist> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveRoomId(int roomId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('roomId', roomId);
  }

  Future<void> _createRoomAndNavigate() async {
    final String apii = "http://192.168.2.106:8000/checkroom";
    try {
      final response = await http.post(Uri.parse(apii),
          headers: {
            'Content-type': 'application/json',
          },
          body: jsonEncode({
            'roomId': widget.userId,
          }));
      final responseData = jsonDecode(response.body);
      print("taggg1 ${responseData}");
      if (responseData == true)
        print("Room Exists");
      else
        print("New Room");
      if (response.statusCode == 200) {
        // final responseData = jsonDecode(response.body);
        print("taggg $responseData");

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              roomId: widget.userId,
              loggedInUser: widget.currentUser,
              partnerUser: "old",
            ),
          ),
        );
        return;
      }
    } catch (e) {}
    setState(() {
      _isLoading = true;
    });

    final String roomApiUrl = "http://192.168.2.106:8000/createroom";
    try {
      final response = await http.post(
        Uri.parse(roomApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
            {'username': widget.currentUser, 'roomId': widget.userId}),
      );

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              roomId: widget.userId,
              loggedInUser: widget.currentUser,
              partnerUser: "new",
            ),
          ),
        );
      } else {
        _showErrorDialog(
            'Failed to create room. Status code: ${response.statusCode}');
      }
    } catch (error) {
      _showErrorDialog('An error occurred: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat List'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _createRoomAndNavigate,
                child: Text('Start Chat with admin'),
              ),
      ),
    );
  }
}
