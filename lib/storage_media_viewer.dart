import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';
import 'package:vertexai_101/debuging_model_tools.dart';

class StoragePhotoList extends StatefulWidget {
  const StoragePhotoList({super.key});

  @override
  StoragePhotoListState createState() => StoragePhotoListState();
}

class StoragePhotoListState extends State<StoragePhotoList> {
  List<Reference> _photoRefs = [];
  Reference? _selectedPhoto;
  String? _description;
  late final GenerativeModel _model;
  late final Reference _storageRef;
  bool _isLoading = false;
  bool _isFetchingPhotos = true;
  Image? _image;

  @override
  void initState() {
    super.initState();
    configDebug().then(onConfigFinished);
  }

  Future<void> configDebug() async {
    await ModelDebugingTools.setDebugSession();
  }

  Future<void> onConfigFinished(void value) async {
    _storageRef = FirebaseStorage.instance.ref();
    _model =
        FirebaseVertexAI.instance.generativeModel(model: 'gemini-1.5-flash');

    _fetchPhotoRefs();
  }

  Future<void> _fetchPhotoRefs() async {
    const errorMessage = '''No photos found!\n 
            \n1 Make sure you've created a "Photos" folder in your Cloud Storage with photos. 
            \n2 For this demo, the "Photos" folder should be publicly accessible. We'll improve security later 😊''';

    setState(() {
      _isFetchingPhotos = true;
    });

    try {
      final photosStorageRef = _storageRef.child('Photos');
      final listResult = await photosStorageRef.listAll();

      if (listResult.items.isEmpty) {
        setState(() {
          _description = errorMessage;
          _isFetchingPhotos = false;
        });
      } else {
        setState(() {
          _photoRefs = listResult.items;
          _isFetchingPhotos = false;
        });
      }
    } catch (error) {
      setState(() {
        _description = errorMessage;
        _isFetchingPhotos = false;
      });
    }
  }

  Future<void> _selectPhoto(Reference storageItemRef) async {
    final imageBytes = await storageItemRef.getData();
    setState(() {
      _image = Image.memory(imageBytes!);
      _description = null;
      _isLoading = true;
      _selectedPhoto = storageItemRef; // Update the selected photo immediately
    });

    try {
      var filePart = await _createFileData(storageItemRef);
      var textPart = TextPart('''Describe the photo shortly.''');

      final requestContent = Content.multi([textPart, filePart]);

      final response = await _model.generateContent([requestContent]);
      setState(() {
        _description = response.text!;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _description = 'An error occurred while generating the quote.';
        _isLoading = false;
      });
    }
  }

  Future<FileData> _createFileData(Reference photoRef) async {
    final metadata = await photoRef.getMetadata();
    final mimeType = metadata.contentType;
    final bucket = photoRef.bucket;
    final fullPath = photoRef.fullPath;
    final storageUrl = 'gs://$bucket/$fullPath';
    final filePart = FileData(mimeType!, storageUrl);
    return filePart;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Photo List',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Storage Photo List'),
        ),
        body: _isFetchingPhotos
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _photoRefs.length,
                      itemBuilder: (context, index) {
                        final photoRef = _photoRefs[index];
                        final isSelected = photoRef == _selectedPhoto;
                        return ListTile(
                          title: Text(photoRef.name),
                          selected: isSelected,
                          onTap: () => _selectPhoto(photoRef),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedPhoto != null)
                              Text(
                                _selectedPhoto!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            const SizedBox(height: 16),
                            if (_image != null)
                              Center(
                                child: SizedBox(
                                  width: 100, // Set maximum width
                                  child: _image,
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Use SizedBox to control the text area size
                            SizedBox(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : Text(
                                      _description ?? '',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
