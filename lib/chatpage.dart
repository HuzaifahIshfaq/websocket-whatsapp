import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'message_model.dart';
import 'socket.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';

import 'package:intl/intl.dart';

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
  AudioPlayer globalAudioPlayer = AudioPlayer();
  bool isAnyAudioPlaying = false;
  FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _recordedAudioPath;
  String? _currentAudioFile;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void initState() {
    super.initState();
    _openRecorder();

    _socketService = SocketService();

    if (widget.partnerUser == 'new') {
      print(widget.roomId);
      _socketService.createroom(widget.roomId, widget.loggedInUser);
    } else {
      _socketService.joinroom(widget.roomId);
      _fetchMessages();
      _socketService.updateseenforall(widget.roomId, widget.loggedInUser);
    }

    _socketService.ListenSeenUpdate((message) {
      print(message);
      _updateSeenStatus(message);
    });

    _socketService.ListenSeenUpdateforall((data) {
      print("for all $data");
      _updateSeenStatusAll();
    });

    _socketService.DeleteMessageListenForEveryone((data) {
      print('message deleted');
      deleteForEveryone(data);
    });

    print(SocketService().socket.id);
    SocketService().socket.on('receive_message', (data) {
      print('Message received from server cp: $data');
    });

    SocketService().socket.on('listen_delete_message', (data) {
      print('listen_delete_message from server cp: $data');
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
        body: jsonEncode({'roomId': widget.roomId, 'role': 'user'}),
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
        print("audioooo ${response.body}");
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
          mimeType = 'video/mp4';
          break;
        case 'mov':
          mimeType = 'video/quicktime';
          break;
        case 'mkv':
          mimeType = 'video/x-matroska';
          break;
        case 'mp3':
          mimeType = 'video/mp3';
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
      } else if ([
        'mp3',
      ].contains(fileExtension)) {
        setState(() {
          _selectedFile = file;
        });
        _sendMessage(isFile: true, base64Data: base64File, fileType: 'audio');
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
    String timestamp = TimestampUtil.getCurrentTimestamp().toString();
    String time = DateTime.now().toString();

    if (isFile) {
      String? path;
      String messageType;

      if (fileType == 'audio' && base64Data != null) {
        path = await uploadFile(base64Data, 'audio');
        messageType = 'audio';
      } else if (_selectedFile != null) {
        path = await uploadFile(base64Data, fileType);
        messageType = fileType;
      } else {
        return;
      }

      final filePath = _selectedFile?.path ?? _recordedAudioPath;
      final fileMessage = Message(
        messageId: time,
        roomId: widget.roomId,
        sender: widget.loggedInUser,
        message: messageType == 'image'
            ? 'Image selected'
            : messageType == 'video'
                ? 'Video selected'
                : messageType == 'audio'
                    ? 'Audio file selected: ${filePath?.split('/').last}'
                    : 'File selected: ${filePath?.split('/').last}',
        timestamp: timestamp,
        seen: false,
        type: messageType,
        fileType: filePath?.split('.').last,
        name: filePath?.split('/').last,
        data: path,
      );

      _socketService.sendMessage(fileMessage.toJson());

      setState(() {
        _messages.add(fileMessage);
        _selectedFile = null;
        _recordedAudioPath = null;
      });
    } else if (messageText.isNotEmpty) {
      final textMessage = Message(
        messageId: time,
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

  Map<String, ChewieController?> _chewieControllers = {};
  Map<String, VideoPlayerController?> _videoControllers = {};

  Future<ChewieController?> _initializeChewieController(
      String messageId, String videoUrl) async {
    if (_chewieControllers.containsKey(messageId) &&
        _chewieControllers[messageId] != null) {
      return _chewieControllers[messageId];
    }

    VideoPlayerController videoPlayerController =
        VideoPlayerController.network(videoUrl);
    await videoPlayerController.initialize();

    ChewieController chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: false,
      looping: false,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: TextStyle(color: Colors.white),
          ),
        );
      },
    );

    _chewieControllers[messageId] = chewieController;
    _videoControllers[messageId] = videoPlayerController;

    return chewieController;
  }

  void deleteMessage(String messageId) {
    _socketService.deletemessage(messageId);

    setState(() {
      _messages.removeWhere((message) => message.messageId == messageId);
    });

    print('Message with id $messageId deleted.');
  }

  void deleteFromui(String messageId) {
    _socketService.deletemessageforEveryone(messageId);
    deleteForEveryone(messageId);
  }

  void deleteForEveryone(String messageId) {
    setState(() {
      Message? message = _findMessageById(messageId);
      if (message != null) {
        message.message = "This message was deleted";
      }
    });

    print('Message with id $messageId updated to "This message was deleted."');
  }

  Message? _findMessageById(String messageId) {
    for (var message in _messages) {
      if (message.messageId == messageId) {
        return message;
      }
    }
    return null;
  }

  void showDeleteDialog(BuildContext context, String messageId, bool isSentByMe,
      Function deleteMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Message"),
          content: Text("Are you sure you want to delete this message?"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                deleteMessage(messageId);
                Navigator.of(context).pop();
              },
              child: Text('Delete for me'),
            ),
            isSentByMe
                ? TextButton(
                    onPressed: () {
                      deleteFromui(messageId);
                      Navigator.of(context).pop();
                    },
                    child: Text('Delete for everyone'),
                  )
                : Text(''),
          ],
        );
      },
    );
  }

  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  Future<void> _openRecorder() async {
    await _audioRecorder.openRecorder();
  }

  Future<void> startRecording() async {
    if (_isRecording) {
      print("Recording is already in progress");
      return;
    }

    var status = await Permission.microphone.request();
    if (status.isGranted) {
      Directory tempDir = await getTemporaryDirectory();
      _recordedAudioPath = '${tempDir.path}/audio_message.aac';

      try {
        await _audioRecorder.startRecorder(
          toFile: _recordedAudioPath,
          codec: Codec.aacADTS,
        );
        setState(() {
          _isRecording = true;
        });
        print("Recording started");
      } catch (e) {
        print("Error starting recording: $e");
      }
    } else {
      print("Microphone permission not granted");
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) {
      print("No recording in progress");
      return;
    }

    try {
      await _audioRecorder.stopRecorder();
    } catch (e) {
      print("Error stopping recording: $e");
      return;
    }

    File audioFile = File(_recordedAudioPath!);
    if (!await audioFile.exists()) {
      print(
          "Audio file does not exist at the specified path: $_recordedAudioPath");
      return;
    }

    try {
      List<int> audioBytes = await audioFile.readAsBytes();
      String base64Audio = base64Encode(audioBytes);

      String base64AudioWithPrefix = 'data:audio/aac;base64,$base64Audio';

      print("Audio bytes length: ${audioBytes.length}");
      print("Base64 audio length: ${base64Audio.length}");

      _sendMessage(
          isFile: true, base64Data: base64AudioWithPrefix, fileType: 'audio');

      setState(() {
        _isRecording = false;
        _recordedAudioPath = null;
      });

      print("Recording stopped and audio sent");
    } catch (e) {
      print("Error converting audio to Base64: $e");
    }
  }

  Widget _buildMessageWidget(Message message) {
    final isSentByMe = message.sender == widget.loggedInUser;

    String baseUrl = 'http://192.168.2.106:8000/';
    String fileUrl = message.data != null ? baseUrl + message.data : "";

    return Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () {
            showDeleteDialog(
                context, message.messageId, isSentByMe, deleteMessage);
          },
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
                if (message.message == "This message was deleted")
                  Text(
                    "This message was deleted",
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  )
                else if (message.type == 'image')
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
                          onPressed: () =>
                              _downloadFileToDownloadsFolder(message),
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
                        onPressed: () =>
                            _downloadFileToDownloadsFolder(message),
                      ),
                    ],
                  )
                else if (message.type == 'video')
                  FutureBuilder<ChewieController?>(
                    future:
                        _initializeChewieController(message.messageId, fileUrl),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasData && snapshot.data != null) {
                          ChewieController? chewieController = snapshot.data;
                          return Column(
                            children: [
                              AspectRatio(
                                aspectRatio:
                                    _videoControllers[message.messageId]!
                                        .value
                                        .aspectRatio,
                                child: Chewie(controller: chewieController!),
                              ),
                              IconButton(
                                icon: Icon(Icons.download),
                                onPressed: () =>
                                    _downloadFileToDownloadsFolder(message),
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
                else if (message.type == 'audio')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio ',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                                _isPlaying && _currentAudioFile == fileUrl
                                    ? Icons.pause
                                    : Icons.play_arrow),
                            onPressed: () => _playPauseAudio(fileUrl),
                          ),
                          Expanded(
                            child: Slider(
                              min: 0.0,
                              max: _audioDuration.inSeconds.toDouble(),
                              value: _audioPosition.inSeconds.toDouble().clamp(
                                  0.0, _audioDuration.inSeconds.toDouble()),
                              onChanged: (value) async {
                                await _audioPlayer
                                    .seek(Duration(seconds: value.toInt()));
                              },
                            ),
                          ),
                          Text(
                              "${_audioPosition.inMinutes}:${(_audioPosition.inSeconds % 60).toString().padLeft(2, '0')}/${_audioDuration.inMinutes}:${(_audioDuration.inSeconds % 60).toString().padLeft(2, '0')}"),
                        ],
                      ),
                    ],
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
        ));
  }

  Future<void> _requestPermissionsAudio() async {}

  AudioPlayer _audioPlayer = AudioPlayer();
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _isPlaying = false;

  void _initAudioPlayer() {
    globalAudioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _audioDuration = duration;
      });
    });

    globalAudioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _audioPosition = position;
      });
    });

    globalAudioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _audioPosition = Duration.zero;
      });
    });
  }

  void _playPauseAudio(String fileUrl) async {
    print("Requested to play: $fileUrl");

    if (_isPlaying && _currentAudioFile == fileUrl) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
      print("Audio paused");
    } else {
      if (_isPlaying && _currentAudioFile != fileUrl) {
        await _audioPlayer.stop();
        print("Audio stopped");
      }
      Source source;
      if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
        source = UrlSource(fileUrl);
        print("Using UrlSource for remote playback");
      } else {
        source = File(fileUrl) as Source;
        print("Using File for local playback");
      }

      try {
        await _audioPlayer.play(source);
        setState(() {
          _isPlaying = true;
          _currentAudioFile = fileUrl;
        });
        print("Playback started");
      } catch (e) {
        print("Error during playback: $e");
      }
    }
  }

  void _seekAudio(double value) async {
    final position = Duration(seconds: value.toInt());
    await globalAudioPlayer.seek(position);
  }

  @override
  @override
  void dispose() {
    _chewieControllers.forEach((key, controller) {
      controller?.dispose();
    });
    _videoControllers.forEach((key, controller) {
      controller?.dispose();
    });
    globalAudioPlayer.stop();
    globalAudioPlayer.dispose();
    _audioRecorder.closeRecorder();
    _socketService.receivemessageoff();
    _messageController.dispose();
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
                ElevatedButton(
                  onPressed: _isRecording ? stopRecording : startRecording,
                  child:
                      Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                ),
                if (_recordedAudioPath != null)
                  ElevatedButton(
                    onPressed: () {
                      _sendMessage(
                          isFile: true, base64Data: null, fileType: 'audio');
                    },
                    child: Text('Send Audio'),
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

class TimestampUtil {
  static String getCurrentTimestamp() {
    DateFormat dateFormat = DateFormat('hh:mm a');
    return dateFormat.format(DateTime.now());
  }
}
