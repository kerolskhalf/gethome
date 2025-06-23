// // lib/screens/chatbot_screen.dart - ALTERNATIVE VERSION WITH flutter_sound
// import 'package:flutter/material.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:path_p rovider/path_provider.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:io';
// import 'property_details_screen_buyer.dart';
//
// // Chatbot Service integrated into the same file
// class ChatbotService {
//   static const String baseUrl = 'https://real-estate-api-production-49bc.up.railway.app';
//
//   static const Map<String, String> headers = {
//     'accept': 'application/json',
//   };
//
//   // Text-based query API
//   static Future<Map<String, dynamic>?> queryProperties(String text) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/query'),
//         headers: {
//           'accept': 'application/json',
//           'Content-Type': 'application/x-www-form-urlencoded',
//         },
//         body: 'text=${Uri.encodeComponent(text)}',
//       );
//
//       if (response.statusCode == 200) {
//         return json.decode(response.body);
//       } else {
//         print('Error querying properties: ${response.statusCode}');
//         print('Response body: ${response.body}');
//         return null;
//       }
//     } catch (e) {
//       print('Exception in queryProperties: $e');
//       return null;
//     }
//   }
//
//   // Voice-based query API
//   static Future<Map<String, dynamic>?> queryFromVoice(File audioFile) async {
//     try {
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('$baseUrl/query/voice'),
//       );
//
//       request.headers.addAll({
//         'accept': 'application/json',
//       });
//
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'file',
//           audioFile.path,
//           filename: 'recording.wav',
//         ),
//       );
//
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);
//
//       if (response.statusCode == 200) {
//         return json.decode(response.body);
//       } else {
//         print('Error querying from voice: ${response.statusCode}');
//         print('Response body: ${response.body}');
//         return null;
//       }
//     } catch (e) {
//       print('Exception in queryFromVoice: $e');
//       return null;
//     }
//   }
// }
//
// class ChatbotScreen extends StatefulWidget {
//   const ChatbotScreen({Key? key}) : super(key: key);
//
//   @override
//   State<ChatbotScreen> createState() => _ChatbotScreenState();
// }
//
// class _ChatbotScreenState extends State<ChatbotScreen> {
//   final TextEditingController _textController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   FlutterSoundRecorder? _recorder;
//
//   List<ChatMessage> _messages = [];
//   bool _isLoading = false;
//   bool _isRecording = false;
//   String? _recordingPath;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeRecorder();
//     _addWelcomeMessage();
//   }
//
//   Future<void> _initializeRecorder() async {
//     _recorder = FlutterSoundRecorder();
//     await _recorder!.openRecorder();
//   }
//
//   void _addWelcomeMessage() {
//     setState(() {
//       _messages.add(ChatMessage(
//         text: "Hello! I'm your real estate assistant. You can ask me about properties by typing or using voice commands.\n\nTry asking:\n• 'I want an apartment in Cairo with 3 bedrooms'\n• 'Show me houses under 5 million'\n• 'Find properties in New Cairo'",
//         isUser: false,
//         timestamp: DateTime.now(),
//       ));
//     });
//   }
//
//   void _sendMessage(String text) async {
//     if (text.trim().isEmpty) return;
//
//     setState(() {
//       _messages.add(ChatMessage(
//         text: text,
//         isUser: true,
//         timestamp: DateTime.now(),
//       ));
//       _isLoading = true;
//     });
//
//     _scrollToBottom();
//     _textController.clear();
//
//     // Call the API
//     final result = await ChatbotService.queryProperties(text);
//
//     setState(() {
//       _isLoading = false;
//     });
//
//     if (result != null) {
//       _handleApiResponse(result);
//     } else {
//       setState(() {
//         _messages.add(ChatMessage(
//           text: "Sorry, I couldn't process your request. Please check your internet connection and try again.",
//           isUser: false,
//           timestamp: DateTime.now(),
//         ));
//       });
//     }
//
//     _scrollToBottom();
//   }
//
//   void _handleApiResponse(Map<String, dynamic> result) {
//     final int resultCount = result['n_results'] ?? 0;
//     final List<dynamic> propertiesData = result['results'] ?? [];
//
//     final List<Map<String, dynamic>> properties = propertiesData
//         .map((item) => item as Map<String, dynamic>)
//         .toList();
//
//     String responseText = "";
//     if (resultCount == 0) {
//       responseText = "I couldn't find any properties matching your criteria. Try adjusting your search terms or being more specific.";
//     } else {
//       responseText = "Great! I found $resultCount properties matching your search. Here are the top results:";
//     }
//
//     setState(() {
//       _messages.add(ChatMessage(
//         text: responseText,
//         isUser: false,
//         timestamp: DateTime.now(),
//         properties: properties.take(10).toList(),
//       ));
//     });
//   }
//
//   Future<void> _startRecording() async {
//     try {
//       final status = await Permission.microphone.request();
//       if (status == PermissionStatus.granted) {
//         final Directory tempDir = await getTemporaryDirectory();
//         final String path = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
//
//         await _recorder!.startRecorder(
//           toFile: path,
//           codec: Codec.pcm16WAV,
//         );
//
//         setState(() {
//           _isRecording = true;
//           _recordingPath = path;
//         });
//
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('🎤 Recording... Release to send'),
//               duration: Duration(seconds: 1),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Microphone permission is required for voice search'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       print('Error starting recording: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Failed to start recording'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   Future<void> _stopRecording() async {
//     try {
//       await _recorder!.stopRecorder();
//       setState(() {
//         _isRecording = false;
//       });
//
//       if (_recordingPath != null) {
//         setState(() {
//           _isLoading = true;
//           _messages.add(ChatMessage(
//             text: "🎤 Processing voice message...",
//             isUser: true,
//             timestamp: DateTime.now(),
//           ));
//         });
//
//         _scrollToBottom();
//
//         final File audioFile = File(_recordingPath!);
//
//         if (!audioFile.existsSync() || audioFile.lengthSync() == 0) {
//           setState(() {
//             _isLoading = false;
//             _messages.add(ChatMessage(
//               text: "Recording was too short or failed. Please try again.",
//               isUser: false,
//               timestamp: DateTime.now(),
//             ));
//           });
//           return;
//         }
//
//         final result = await ChatbotService.queryFromVoice(audioFile);
//
//         setState(() {
//           _isLoading = false;
//         });
//
//         if (result != null) {
//           _handleApiResponse(result);
//         } else {
//           setState(() {
//             _messages.add(ChatMessage(
//               text: "Sorry, I couldn't understand your voice message. Please try speaking clearly or use text input.",
//               isUser: false,
//               timestamp: DateTime.now(),
//             ));
//           });
//         }
//
//         _scrollToBottom();
//
//         try {
//           audioFile.deleteSync();
//         } catch (e) {
//           print('Failed to delete audio file: $e');
//         }
//       }
//     } catch (e) {
//       print('Error stopping recording: $e');
//       setState(() {
//         _isRecording = false;
//         _isLoading = false;
//       });
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Failed to process recording'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   void _clearChat() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: const Color(0xFF1a237e),
//           title: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
//           content: const Text(
//             'Are you sure you want to clear all messages?',
//             style: TextStyle(color: Colors.white),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Cancel', style: TextStyle(color: Colors.white)),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 setState(() {
//                   _messages.clear();
//                   _addWelcomeMessage();
//                 });
//                 Navigator.of(context).pop();
//               },
//               child: const Text('Clear'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1a237e),
//       appBar: AppBar(
//         title: const Text('Property Assistant'),
//         backgroundColor: const Color(0xFF1a237e),
//         elevation: 0,
//         automaticallyImplyLeading: false,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.clear_all, color: Colors.white),
//             onPressed: _clearChat,
//             tooltip: 'Clear Chat',
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               controller: _scrollController,
//               padding: const EdgeInsets.all(16),
//               itemCount: _messages.length + (_isLoading ? 1 : 0),
//               itemBuilder: (context, index) {
//                 if (index == _messages.length && _isLoading) {
//                   return _buildLoadingIndicator();
//                 }
//                 return _buildMessageBubble(_messages[index]);
//               },
//             ),
//           ),
//           _buildInputArea(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLoadingIndicator() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(18),
//             ),
//             child: const SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Text(
//             'Searching properties...',
//             style: TextStyle(
//               color: Colors.white.withOpacity(0.7),
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageBubble(ChatMessage message) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       child: Row(
//         mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           if (!message.isUser) ...[
//             CircleAvatar(
//               radius: 16,
//               backgroundColor: Colors.white.withOpacity(0.2),
//               child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
//             ),
//             const SizedBox(width: 8),
//           ],
//           Flexible(
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: message.isUser
//                     ? const Color(0xFF234E70)
//                     : Colors.white.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(18),
//                 border: Border.all(
//                   color: Colors.white.withOpacity(0.2),
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     message.text,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                     ),
//                   ),
//                   if (message.properties != null && message.properties!.isNotEmpty) ...[
//                     const SizedBox(height: 12),
//                     ...message.properties!.map((property) => _buildPropertyCard(property)),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//           if (message.isUser) ...[
//             const SizedBox(width: 8),
//             CircleAvatar(
//               radius: 16,
//               backgroundColor: const Color(0xFF234E70),
//               child: const Icon(Icons.person, color: Colors.white, size: 18),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPropertyCard(Map<String, dynamic> property) {
//     return Container(
//       margin: const EdgeInsets.only(top: 8),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white.withOpacity(0.2)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF234E70),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   '${property['property_type'] ?? 'Property'}'.toUpperCase(),
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               Text(
//                 '\$${_formatPrice(property['price'] ?? 0)}',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Icon(Icons.location_on, color: Colors.white.withOpacity(0.7), size: 14),
//               const SizedBox(width: 4),
//               Expanded(
//                 child: Text(
//                   '${property['city'] ?? ''}, ${property['region'] ?? ''}',
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(0.8),
//                     fontSize: 12,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 4),
//           Row(
//             children: [
//               _buildPropertyFeature(Icons.square_foot, '${property['area_m2'] ?? 0}m²'),
//               const SizedBox(width: 16),
//               _buildPropertyFeature(Icons.bed, '${property['n_bedrooms'] ?? 0} bed'),
//               const SizedBox(width: 16),
//               _buildPropertyFeature(Icons.bathtub, '${property['n_bathrooms'] ?? 0} bath'),
//             ],
//           ),
//           if (property['is_furnished'] != null) ...[
//             const SizedBox(height: 4),
//             Row(
//               children: [
//                 Icon(
//                   property['is_furnished'] == 'yes' ? Icons.check_circle : Icons.cancel,
//                   color: property['is_furnished'] == 'yes' ? Colors.green : Colors.red,
//                   size: 14,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   property['is_furnished'] == 'yes' ? 'Furnished' : 'Not Furnished',
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(0.8),
//                     fontSize: 11,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//           const SizedBox(height: 8),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => PropertyDetailsScreenBuyer(
//                       property: _convertToPropertyFormat(property),
//                     ),
//                   ),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF234E70),
//                 foregroundColor: Colors.white,
//                 minimumSize: const Size(double.infinity, 32),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               child: const Text('View Details', style: TextStyle(fontSize: 12)),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPropertyFeature(IconData icon, String text) {
//     return Row(
//       children: [
//         Icon(icon, color: Colors.white.withOpacity(0.7), size: 14),
//         const SizedBox(width: 4),
//         Text(
//           text,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.8),
//             fontSize: 11,
//           ),
//         ),
//       ],
//     );
//   }
//
//   String _formatPrice(dynamic price) {
//     if (price == null) return '0';
//     double priceDouble = price.toDouble();
//     if (priceDouble >= 1000000) {
//       return '${(priceDouble / 1000000).toStringAsFixed(1)}M';
//     } else if (priceDouble >= 1000) {
//       return '${(priceDouble / 1000).toStringAsFixed(1)}K';
//     } else {
//       return priceDouble.toStringAsFixed(0);
//     }
//   }
//
//   Map<String, dynamic> _convertToPropertyFormat(Map<String, dynamic> apiProperty) {
//     return {
//       'id': apiProperty['id'] ?? 0,
//       'houseType': apiProperty['property_type'] ?? 'apartment',
//       'area': apiProperty['area_m2'] ?? 0,
//       'bedrooms': apiProperty['n_bedrooms'] ?? 0,
//       'bathrooms': apiProperty['n_bathrooms'] ?? 0,
//       'city': apiProperty['city'] ?? '',
//       'region': apiProperty['region'] ?? '',
//       'price': apiProperty['price'] ?? 0,
//       'isFurnished': apiProperty['is_furnished'] == 'yes',
//       'floor': apiProperty['floor'] ?? 0,
//       'isHighFloor': apiProperty['is_high_floor'] ?? false,
//       'pricePerM2': apiProperty['price_per_m2'] ?? 0,
//       'totalRooms': apiProperty['total_rooms'] ?? 0,
//       'status': 1,
//       'images': [],
//     };
//   }
//
//   Widget _buildInputArea() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.05),
//         border: Border(
//           top: BorderSide(color: Colors.white.withOpacity(0.1)),
//         ),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _textController,
//               decoration: InputDecoration(
//                 hintText: 'Ask about properties...',
//                 hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(25),
//                   borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(25),
//                   borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(25),
//                   borderSide: const BorderSide(color: Colors.white),
//                 ),
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 filled: true,
//                 fillColor: Colors.white.withOpacity(0.1),
//               ),
//               style: const TextStyle(color: Colors.white),
//               onSubmitted: _sendMessage,
//               enabled: !_isLoading && !_isRecording,
//               maxLines: null,
//             ),
//           ),
//           const SizedBox(width: 8),
//           GestureDetector(
//             onTapDown: (_) => _startRecording(),
//             onTapUp: (_) => _stopRecording(),
//             onTapCancel: () => _stopRecording(),
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: _isRecording ? Colors.red : const Color(0xFF234E70),
//                 shape: BoxShape.circle,
//                 boxShadow: _isRecording ? [
//                   BoxShadow(
//                     color: Colors.red.withOpacity(0.3),
//                     blurRadius: 10,
//                     spreadRadius: 2,
//                   )
//                 ] : null,
//               ),
//               child: Icon(
//                 _isRecording ? Icons.stop : Icons.mic,
//                 color: Colors.white,
//                 size: 24,
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           GestureDetector(
//             onTap: () => _sendMessage(_textController.text),
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: const BoxDecoration(
//                 color: Color(0xFF234E70),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.send,
//                 color: Colors.white,
//                 size: 24,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _textController.dispose();
//     _scrollController.dispose();
//     _recorder?.closeRecorder();
//     super.dispose();
//   }
// }
//
// class ChatMessage {
//   final String text;
//   final bool isUser;
//   final DateTime timestamp;
//   final List<Map<String, dynamic>>? properties;
//
//   ChatMessage({
//     required this.text,
//     required this.isUser,
//     required this.timestamp,
//     this.properties,
//   });
// }