import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';
import 'dart:io';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dance Video App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Dance Video Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _videoFile;
  VideoPlayerController? _controller;
  final picker = ImagePicker();
  bool _isPlaying = false;
  double _sliderValue = 0.0;
  String _overlayText = '';
  bool _applyFilter = false;
  Color _filterColor = Colors.blue;
  double _startTrim = 0.0;
  double _endTrim = 0.0;
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

  Future<void> _pickVideo() async {
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
      });
      _controller = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          setState(() {
            // _isPlaying = true;
            //_controller!.play();
            _overlayText = ''; // Réinitialiser l'overlay
            _applyFilter = false; // Réinitialiser le filtre
            _startTrim = 0.0; // Réinitialiser les trims
            _endTrim = _controller!.value.duration.inMilliseconds.toDouble();
          });
        });
      _controller!.addListener(() {
        setState(() {
          _sliderValue = _controller!.value.position.inMilliseconds.toDouble();
        });
      });
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller != null && _controller!.value.isInitialized) {
        if (_isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
        _isPlaying = !_isPlaying;
      }
    });
  }

  Future<void> _seekToPosition(double value) async {
    if (_controller != null && _controller!.value.isInitialized) {
      final position = Duration(milliseconds: value.toInt());
      await _controller!.seekTo(position);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _videoFile == null
                  ? const Text('No video selected.')
                  : Stack(
                      children: [
                        if (_controller != null && _controller!.value.isInitialized)
                          Center(
                            child: AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: GestureDetector(
                              onTap: _togglePlayPause,  // Tap to toggle play/pause
                              child: Container(
                                child: _applyFilter
                                    ? ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          _filterColor.withOpacity(0.5),  // Adjust opacity as needed
                                          BlendMode.modulate,
                                        ),
                                        child: VideoPlayer(_controller!),
                                      )
                                    : VideoPlayer(_controller!),
                              ),
                            ),
                          ),
                          ),
                        if (_overlayText.isNotEmpty)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                _overlayText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          if (_controller != null && _controller!.value.isInitialized)
            Column(
              children: [
                _buildTrimSlider(),
                _buildSlider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      onPressed: _pickMusic,
                      child: Icon(Icons.music_note),
                      tooltip: 'Add Music',
                    ),
                    FloatingActionButton(
                      onPressed: _showOverlayEditor,
                      child: Icon(Icons.filter),
                      tooltip: 'Add Overlay/Mask',
                    ),
                    FloatingActionButton(
                      onPressed: _saveVideo,
                      child: Icon(Icons.save),
                      tooltip: 'Save',
                    ),
                    FloatingActionButton(
                      onPressed: _shareVideo,
                      child: Icon(Icons.share),
                      tooltip: 'Share',
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickVideo,
        tooltip: 'Pick Video',
        child: const Icon(Icons.video_library),
      ),
    );
  }




  Widget _buildSlider() {
    return Slider(
      value: _sliderValue,
      min: 0.0,
      max: _controller!.value.duration.inMilliseconds.toDouble(),
      onChanged: (value) {
        setState(() {
          _sliderValue = value;
        });
        _seekToPosition(value);
      },
    );
  }

  Widget _buildTrimSlider() {
    return RangeSlider(
      values: RangeValues(_startTrim, _endTrim),
      min: 0.0,
      max: _controller!.value.duration.inMilliseconds.toDouble(),
      onChanged: (RangeValues values) {
        setState(() {
          _startTrim = values.start.clamp(0.0, _controller!.value.duration.inMilliseconds.toDouble());
          _endTrim = values.end.clamp(0.0, _controller!.value.duration.inMilliseconds.toDouble());
        });
        _controller!.seekTo(Duration(milliseconds: _startTrim.toInt()));
      },
    );
  }

  void _showOverlayEditor() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.text_fields),
              title: Text('Add Text Overlay'),
              onTap: () {
                Navigator.pop(context);
                _showTextOverlayDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.color_lens),
              title: Text('Add Color Filter'),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker();
              },
            ),
          ],
        );
      },
    );
  }

  void _showTextOverlayDialog() {
    TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Text Overlay'),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(hintText: 'Enter text'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _overlayText = textController.text;
                });
                Navigator.pop(context);
              },
              child: Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Filter Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BlockPicker(
                pickerColor: _filterColor,
                onColorChanged: (color) {
                  setState(() {
                    _filterColor = color;
                    _applyFilter = true;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _pickMusic() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            ListTile(
              leading: Icon(Icons.music_note),
              title: Text('Jaymes Young - Infinity [Official Audio]'),
              onTap: () {
                Navigator.pop(context);
                _applyMusic('assets/Jaymes Young - Infinity [Official Audio].mp3', 'JaymesY.mp3');
              },
            ),
            ListTile(
              leading: Icon(Icons.music_note),
              title: Text('Kaiju - Vide la tête'),
              onTap: () {
                Navigator.pop(context);
                _applyMusic('assets/Kaiju - Vide la tête.mp3', 'Kaiju.mp3');
              },
            ),
            // Ajoutez d'autres pistes ici
          ],
        );
      },
    );
  }
  Future<File> _loadAssetToFile(String assetPath, String fileName) async {
    final byteData = await rootBundle.load(assetPath);
    final file = File('${(await getTemporaryDirectory()).path}/$fileName');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }
  
  void _applyMusic(String assetPath, String fileName) async {
    final musicFile = await _loadAssetToFile(assetPath, fileName);
    final directory = await getApplicationDocumentsDirectory();

    // Create a unique filename for the edited video
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFilename = 'edited_video_$timestamp.mp4';
    final outputFile = File('${directory.path}/$outputFilename');

    // Correct FFmpeg command to replace the video audio with the new audio
    final command = '-i ${_videoFile!.path} -i ${musicFile.path} -map 0:v -map 1:a -c:v copy -c:a aac -strict experimental -shortest ${outputFile.path}';

    print('Executing FFmpeg command: $command');

    final result = await _flutterFFmpeg.execute(command);
    print('FFmpeg result code: $result');

    if (result == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Music added successfully!')),
      );
      setState(() {
        _videoFile = outputFile; // Update the video file state
        _initializeVideoController(); // Reinitialize the video player with the new file
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add music.')),
      );
    }
  }

  void _initializeVideoController() {
    if (_videoFile != null) {
      _controller = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          setState(() {
            //_controller!.play();
            //_isPlaying = true;

            // Update trim values to fit the new video's duration
            _startTrim = 0.0;
            _endTrim = _controller!.value.duration.inMilliseconds.toDouble();

            // Reset the slider value to the start
            _sliderValue = 0.0;
          });

          // Set up the listener to update the slider as the video plays
          _controller!.addListener(() {
            setState(() {
              _sliderValue = _controller!.value.position.inMilliseconds.toDouble();
            });
          });
        });
    }
  }

  

  void _trimVideo() async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDirectory = directory.path;

    final outputFile = File('$outputDirectory/trimmed_video.mp4');
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final outputDir = outputFile.parent;
    if (!(await outputDir.exists())) {
      await outputDir.create(recursive: true);
    }

    final command = '-i ${_videoFile!.path} -ss ${_startTrim / 1000} -to ${_endTrim / 1000} -c copy ${outputFile.path}';
    print('Executing FFmpeg command: $command');

    final result = await _flutterFFmpeg.execute(command);
    print('FFmpeg result code: $result');

    if (result == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video trimmed successfully!')),
      );
      setState(() {
        _videoFile = File('$outputDirectory/trimmed_video.mp4');
        _controller = VideoPlayerController.file(_videoFile!)
          ..initialize().then((_) {
            _controller!.play();
            _endTrim = _controller!.value.duration.inMilliseconds.toDouble();
          });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trim video.')),
      );
    }
  }


  void _saveVideo() async {
  if (_videoFile == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No video to save.')),
    );
    return;
  }

  final directory = await getExternalStorageDirectory();
  final outputPath = '${directory!.path}/final_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

  // Préparer la commande FFmpeg
  String filter = '';
  
  // Ajouter filtre de couleur si activé
  if (_applyFilter) {
    filter += 'colorchannelmixer=rr=${_filterColor.red / 255}:rg=${_filterColor.green / 255}:rb=${_filterColor.blue / 255},';
  }

  // Ajouter texte d'overlay si présent
  if (_overlayText.isNotEmpty) {
    filter += 'drawtext=text=\'${_overlayText}\':fontsize=24:fontcolor=white:x=(w-tw)/2:y=(h-th)/2,';
  }

  // Supprimer la virgule finale
  if (filter.isNotEmpty) {
    filter = filter.substring(0, filter.length - 1);
  }

  final command = '-i ${_videoFile!.path} -vf "$filter" -c:a copy -shortest $outputPath';

  print('Executing FFmpeg command: $command');

  final result = await _flutterFFmpeg.execute(command);
  if (result == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Video saved successfully to $outputPath')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save video.')),
    );
  }
}



  void _shareVideo() {
    if (_videoFile != null) {
      Share.shareFiles([_videoFile!.path], text: 'Check out my video!');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video to share')),
      );
    }
  }
  

}
