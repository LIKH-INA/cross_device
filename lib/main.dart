import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCKeOPuM6mxUGtiKDvtRjE45ly-29VUh3I",
        authDomain: "cross-device-clipboard-system.firebaseapp.com",
        projectId: "cross-device-clipboard-system",
        storageBucket: "cross-device-clipboard-system.firebasestorage.app",
        messagingSenderId: "270556226556",
        appId: "1:270556226556:web:0000000000000000",
      ),
    );
  } else {
    await Firebase.initializeApp();

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ClipboardHome(),
    );
  }
}

class ClipboardHome extends StatefulWidget {
  const ClipboardHome({super.key});

  @override
  State<ClipboardHome> createState() => _ClipboardHomeState();
}

class _ClipboardHomeState extends State<ClipboardHome> {
  final TextEditingController controller = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final ImagePicker picker = ImagePicker();

  void sendText() async {
    if (controller.text.trim().isEmpty) return;

    await firestore.collection("clipboard").add({
      "type": "text",
      "data": controller.text.trim(),
      "time": FieldValue.serverTimestamp(),
      "device": kIsWeb ? "Web" : "App",
    });

    controller.clear();
  }

  void pickImage() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.bytes != null) {
        String base64Image = base64Encode(result.files.single.bytes!);
        await firestore.collection("clipboard").add({
          "type": "image",
          "data": base64Image,
          "time": FieldValue.serverTimestamp(),
          "device": "Web",
        });
      }
    } else {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        Uint8List bytes = await image.readAsBytes();
        String base64Image = base64Encode(bytes);
        await firestore.collection("clipboard").add({
          "type": "image",
          "data": base64Image,
          "time": FieldValue.serverTimestamp(),
          "device": "App",
        });
      }
    }
  }

  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Copied to clipboard ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        title: const Text("Cross-Device Clipboard"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection("clipboard")
                  .orderBy("time", descending: true)
                  .limit(5)
                  .snapshots(includeMetadataChanges: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    // ✅ FIXED HERE (SAFE ACCESS)
                    var data =
                        docs[index].data() as Map<String, dynamic>;

                    String device = data.containsKey("device")
                        ? data["device"]
                        : "Unknown";

                    Timestamp? ts = data.containsKey("time")
                        ? data["time"]
                        : null;

                    String timeString = ts != null
                        ? ts.toDate().toLocal().toString().substring(0, 19)
                        : "";

                    if (data["type"] == "text") {
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(data["data"] ?? ""),
                          subtitle: Text("$device • $timeString",
                              style: const TextStyle(fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () =>
                                copyText(data["data"] ?? ""),
                          ),
                        ),
                      );
                    } else {
                      Uint8List imageBytes =
                          base64Decode(data["data"] ?? "");

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Image tapped! You can add save/share logic here."),
                                    ),
                                  );
                                },
                                child: Image.memory(imageBytes),
                              ),
                              const SizedBox(height: 4),
                              Text("$device • $timeString",
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  blurRadius: 5,
                  color: Colors.black12,
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Type something...",
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.image,
                      color: Colors.deepPurple),
                  onPressed: pickImage,
                ),
                IconButton(
                  icon: const Icon(Icons.send,
                      color: Colors.deepPurple),
                  onPressed: sendText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
