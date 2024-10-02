import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chatpage.dart';
import 'db_helper.dart';

class Chatlist extends StatefulWidget {
  final String currentUser;

  const Chatlist({super.key, required this.currentUser});

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
    List<int> usernam =
        await DBHelper().searchRoomByUsername(widget.currentUser);
    print(usernam);
    if (usernam.length > 0) {
      int roomId = usernam[0];
      print(roomId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            roomId: roomId,
            loggedInUser: widget.currentUser,
            partnerUser: "old",
          ),
        ),
      );
      return;
    }
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
        body: jsonEncode({
          'username': widget.currentUser,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final int roomId = responseData['roomId'];

        await DBHelper().insertRoom(roomId, widget.currentUser);

        await _saveRoomId(roomId);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              roomId: roomId,
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
