import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'message_model.dart';
import 'socket.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';

class ChatPage extends StatefulWidget {
  final int roomId;
  final String loggedInUser;
  final String partnerUser;

  const ChatPage({
    Key? key,
    required this.roomId,
    required this.loggedInUser,
    required this.partnerUser,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController _messageController = TextEditingController();
  List<Message> _messages = [];
  late SocketService _socketService;
  File? _selectedFile;
  Uint8List? _selectedImageBytes;
  VideoPlayerController? _videoPlayerController;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _socketService = SocketService();

    if (widget.partnerUser == 'new') {
      print(widget.roomId);
      _socketService.createroom(widget.roomId, widget.loggedInUser);
    } else {
      _socketService.joinroom(widget.roomId);
      _fetchMessages();
      _socketService.updateseenforall(widget.roomId, widget.loggedInUser);
    }
    //_socketService.getRoomId();

    _socketService.ListenSeenUpdate((message) {
      print(message);
      _updateSeenStatus(message);
    });

    _socketService.ListenSeenUpdateforall((data) {
      print("for all $data");
      _updateSeenStatusAll();
    });
    // _socketService.ListenSeenUpdate((messageid) {
    //   for (var i = 0; i < _messages.length; i++) {
    //     if (_messages[i].messageId == messageid) {
    //       print("TAG1");
    //       print(_messages[i].message);
    //       //messages[i].seen = true;
    //       print("TAG2");
    //       break;
    //     }
    //   }
    // });
    print(SocketService().socket.id);
    SocketService().socket.on('receive_message', (data) {
      print('Message received from server cp: $data');
    });

    SocketService().socket.on('listen_seen_update', (data) {
      print('listen_seen_update  from server cp: $data');
    });

    _socketService.onMessages((data) {
      print("New ");
      print(_socketService.socket.id);
      if (data is Map<String, dynamic>) {
        try {
          final message = Message.fromJson(data);
          _socketService.updateseen(message);
          setState(() {
            _messages.add(message);
          });
        } catch (e) {
          print('Error parsing message: $e');
        }
      } else {
        print('Unexpected data format: $data');
      }
    });
  }

  void _updateSeenStatus(data) {
    print("Function");
    Message message = Message.fromJson(data);
    String messageId = message.messageId;
    setState(() {
      for (var message in _messages) {
        if (message.messageId == messageId) {
          message.seen = true;
          print("Updated seen status for messageId: $messageId");
          break;
        }
      }
    });
  }

  void _updateSeenStatusAll() {
    print("all seen updated");
    setState(() {
      for (var message in _messages) {
        message.seen = true;
      }
    });
  }

  Future<void> _fetchMessages() async {
    final String getmessage = 'http://192.168.2.106:8000/getmessages';
    try {
      final response = await http.post(
        Uri.parse(getmessage),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'roomId': widget.roomId}),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['data'] is List) {
          setState(() {
            _messages = (responseData['data'] as List)
                .map((messageData) => Message.fromJson(messageData))
                .toList();
          });
        } else {
          print('No messages found in response.');
        }
      } else {
        print('Failed to load messages: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching messages: $error');
    }
  }

  Future<String> uploadFile(String? base64File, String fileType) async {
    final String uploadUrl = 'http://192.168.2.106:8000/uploadfiles';

    try {
      final Map<String, dynamic> body = {"file": base64File};
      var response = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print(response.body);
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        String filePath = jsonResponse['filePath'];
        return filePath;
      } else {
        print('Failed to upload file: ${response.statusCode}');
        return "";
      }
    } catch (error) {
      print('Error uploading file: $error');
      return "";
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;

      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      final base64FileData = base64Encode(fileBytes);

      final fileName = result.files.single.name;

      final fileExtension = filePath.split('.').last.toLowerCase();
      String mimeType;
      switch (fileExtension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        case 'doc':
        case 'docx':
          mimeType =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          break;
        case 'ppt':
        case 'pptx':
          mimeType =
              'application/vnd.openxmlformats-officedocument.presentationml.presentation';
          break;
        case 'txt':
          mimeType = 'text/plain';
          break;
        case 'mp4':
          mimeType = 'video/mp4';
          break;
        case 'avi':
          mimeType = 'video/x-msvideo';
          break;
        case 'mov':
          mimeType = 'video/quicktime';
          break;
        case 'mkv':
          mimeType = 'video/x-matroska';
          break;
        default:
          mimeType = 'application/octet-stream';
          break;
      }

      final base64File = 'data:$mimeType;base64,$base64FileData';

      if ([
        'jpg',
        'jpeg',
        'png',
        'gif',
      ].contains(fileExtension)) {
        setState(() {
          _selectedFile = file;
          _selectedImageBytes = fileBytes;
        });
        _sendMessage(isFile: true, base64Data: base64File, fileType: 'image');
      } else if ([
        'mp4',
        'avi',
        'mov',
        'mkv',
      ].contains(fileExtension)) {
        setState(() {
          _selectedFile = file;
        });
        _sendMessage(isFile: true, base64Data: base64File, fileType: 'video');
      } else {
        setState(() {
          _selectedFile = file;
          _sendMessage(
              isFile: true, base64Data: base64File, fileType: 'document');
        });
      }
    }
  }

  void _sendMessage({
    bool isFile = false,
    String? base64Data,
    String fileType = 'text',
  }) async {
    String messageText = _messageController.text;
    String timestamp = DateTime.now().toString();

    if (isFile && _selectedFile != null) {
      String path = await uploadFile(base64Data, fileType);
      final filePath = _selectedFile!.path;
      final messageType = fileType;

      final fileMessage = Message(
        messageId: timestamp,
        roomId: widget.roomId,
        sender: widget.loggedInUser,
        message: fileType == 'image'
            ? 'Image selected'
            : fileType == 'video'
                ? 'Video selected'
                : 'File selected: ${filePath.split('/').last}',
        timestamp: timestamp,
        seen: false,
        type: messageType,
        fileType: filePath.split('.').last,
        name: filePath.split('/').last,
        data: path,
      );

      _socketService.sendMessage(fileMessage.toJson());

      setState(() {
        _messages.add(fileMessage);
        _selectedFile = null;
        _selectedImageBytes = null;
      });
    } else if (messageText.isNotEmpty) {
      final textMessage = Message(
        messageId: timestamp,
        roomId: widget.roomId,
        sender: widget.loggedInUser,
        message: messageText,
        timestamp: timestamp,
        seen: false,
        type: 'text',
        fileType: '',
        name: '',
      );

      _socketService.sendMessage(textMessage.toJson());

      setState(() {
        _messages.add(textMessage);
        _messageController.clear();
      });
    }
  }

  Future<void> _requestPermission() async {
    if (await Permission.storage.request().isGranted) {
      print("Permission denied.");
    } else {
      print("Permission granted");
    }
  }

  void _downloadFileToDownloadsFolder(Message message) async {
    if (message.data == null || message.data!.isEmpty) {
      print("No file path available");
      return;
    }

    await _requestPermission();

    final fileUrl = 'http://192.168.2.106:8000/${message.data}';
    final fileName = message.data!.split('/').last;

    try {
      Directory? downloadsDirectory = await getExternalStorageDirectory();

      if (downloadsDirectory == null) {
        print("Could not access Downloads folder");
        return;
      }
      final filePath = '${downloadsDirectory.path}/$fileName';

      Dio dio = Dio();

      await dio.download(fileUrl, filePath);

      print("File downloaded successfully: $filePath");
    } catch (e) {
      print("Error downloading file: $e");
    }
  }

  Future<VideoPlayerController?> _initializeVideoController(
      String videoUrl) async {
    try {
      print("Video URL: $videoUrl");

      if (_videoPlayerController != null) {
        _videoPlayerController!.dispose();
      }
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();
      print("Video player initialized successfully");
      return _videoPlayerController;
    } catch (e) {
      print("Error initializing video player: $e");
      return null;
    }
  }

  Widget _buildMessageWidget(Message message) {
    final isSentByMe = message.sender == widget.loggedInUser;

    String baseUrl = 'http://192.168.2.106:8000/';
    String fileUrl = "";
    if (message.data != null) {
      fileUrl = baseUrl + message.data;
      print(fileUrl);
    }

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        margin: EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isSentByMe
              ? Color.fromARGB(255, 108, 224, 118)
              : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
            bottomLeft: isSentByMe ? Radius.circular(10) : Radius.zero,
            bottomRight: isSentByMe ? Radius.zero : Radius.circular(10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == 'image')
              Stack(
                children: [
                  Image.network(
                    fileUrl,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (BuildContext context, Widget child,
                        ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (BuildContext context, Object error,
                        StackTrace? stackTrace) {
                      return Center(
                        child: Text('Failed to load image'),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: IconButton(
                      icon: Icon(Icons.download,
                          color: const Color.fromARGB(255, 57, 238, 96)),
                      onPressed: () => _downloadFileToDownloadsFolder(message),
                    ),
                  ),
                ],
              )
            else if (message.type == 'document' || message.type == 'file')
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'File: ${message.name}',
                      style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.download),
                    onPressed: () => _downloadFileToDownloadsFolder(message),
                  ),
                ],
              )
            else if (message.type == 'video')
              FutureBuilder<VideoPlayerController?>(
                future: _initializeVideoController(fileUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasData && snapshot.data != null) {
                      VideoPlayerController? videoController = snapshot.data;
                      return Column(
                        children: [
                          AspectRatio(
                            aspectRatio: videoController!.value.aspectRatio,
                            child: VideoPlayer(videoController),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  videoController.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                                onPressed: () {
                                  setState(() {
                                    videoController.value.isPlaying
                                        ? videoController.pause()
                                        : videoController.play();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    } else {
                      return Center(
                        child: Text('Failed to load video'),
                      );
                    }
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading video: ${snapshot.error}'),
                    );
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              )
            else
              Text(
                message.message!,
                style: TextStyle(fontSize: 16.0),
              ),
            SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.timestamp,
                  style: TextStyle(fontSize: 12.0, color: Colors.grey),
                ),
                if (isSentByMe) SizedBox(width: 5),
                if (isSentByMe)
                  Icon(
                    message.seen
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    size: 16,
                    color: message.seen ? Colors.blue : Colors.grey,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController
            .position.maxScrollExtent); // Scrolls to the end immediately.
        // _scrollController.animateTo(
        //   _scrollController.position.maxScrollExtent,
        //   duration: Duration(milliseconds: 300), // Optional: Smooth scroll animation.
        //   curve: Curves.easeOut,
        // );
      }
    });
  }

  @override
  void dispose() {
    if (_videoPlayerController != null) {
      _videoPlayerController!.dispose();
    }
    _socketService.receivemessageoff();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.partnerUser}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return _buildMessageWidget(message);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: _pickFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
