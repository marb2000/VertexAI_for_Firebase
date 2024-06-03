import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';

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
  late final _storageRef;
  bool _isLoading = false;
  late Image _image;

  @override
  void initState() {
    super.initState();

    _storageRef = FirebaseStorage.instance.ref();
    _model =
        FirebaseVertexAI.instance.generativeModel(model: 'gemini-1.5-flash');

    _fetchPhotoRefs();
  }

  Future<void> _fetchPhotoRefs() async {
    final storageRef = FirebaseStorage.instance.ref().child('Photos');
    final listResult = await storageRef.listAll();
    setState(() {
      _photoRefs = listResult.items;
    });
  }

  Future<void> _selectPhoto(Reference photoRef) async {
    //Future<dynamic> image =   await photoRef.getDownloadURL();

    setState(() {
      _description = null;
      _isLoading = true;
      _selectedPhoto = photoRef; // Update the selected photo immediately
    });

    try {
      var filePart = await _createFileData(photoRef);
      var textPart =
          TextPart('''Describe the photo. First and overview of the photo, 
      and then the details of each part of the photo''');

      final prompt = Content.multi([textPart, filePart]);

      final response = await _model.generateContent([prompt]);
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
        body: _photoRefs.isEmpty
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
                  Container(
                    height: MediaQuery.of(context).size.height * 0.5,
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

                        // Use SizedBox to control the text area size
                        SizedBox(
                          height: MediaQuery.of(context).size.height *
                              0.3, // 50% of screen height
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : SingleChildScrollView(
                                  child: Text(
                                    _description ?? '',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
