import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'ff_lib.dart';

final _fileType = [
  [
    '映像ファイル -> mp4',
    ['mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv', 'webm'],
    '.mp4',
  ],
  [
    '音声ファイル -> mp3',
    ['mp3', 'wav', 'flac', 'm4a', 'ogg'],
    '.mp3',
  ],
  [
    '映像ファイル -> mp3',
    ['mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv', 'webm'],
    '.mp3',
  ],
  [
    'mp4 -> DVD形式',
    ['mp4'],
    '.MPG',
  ],
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'へんかんくん',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 104, 205, 195),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'へんかんくん'),
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
  int _target = 0;
  bool _isConverting = false;
  double _fileProgress = 0;
  int _currentIndex = 0;
  int _totalFiles = 0;

  void _filePicker(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _fileType[_target][1] as List<String>,
    );
    if (result != null) {
      List<String> filePath = result.files.map((e) => e.path ?? '').toList();
      setState(() {
        _isConverting = true;
        _fileProgress = 0;
        _currentIndex = 0;
        _totalFiles = filePath.length;
      });
      for (int i = 0; i < filePath.length; i++) {
        setState(() {
          _currentIndex = i;
          _fileProgress = 0;
        });
        int code = await ffmpegMain(
          _target,
          filePath[i],
          _fileType[_target][2] as String,
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _fileProgress = p);
          },
        );
        if (code == 1) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Center(
                  child: Text(
                    'ファイル名, パスに空白は利用できません\n空白を削除してからもう一度お試しください',
                    style: TextStyle(color: Colors.black, fontSize: 18),
                  ),
                ),
              );
            },
          );
          break;
        } else {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Center(
                  child: Text(
                    '変換が完了しました!',
                    style: TextStyle(color: Colors.black, fontSize: 18),
                  ),
                ),
              );
            },
          );
        }
      }
      setState(() {
        _isConverting = false; // Stop converting
      });
    } else {
      // User canceled the picker
    }
  }

  @override
  Widget build(BuildContext context) {
    return !_isConverting
        ? Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              title: Text(widget.title),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('入力ファイル形式'),
                  Center(
                    child: RadioListTile<int>(
                      title: const Text('映像ファイル -> mp4'),
                      value: 0,
                      groupValue: _target,
                      onChanged: (int? value) {
                        setState(() {
                          _target = value!;
                        });
                      },
                    ),
                  ),
                  Center(
                    child: RadioListTile<int>(
                      title: const Text('音声ファイル -> mp3'),
                      value: 1,
                      groupValue: _target,
                      onChanged: (int? value) {
                        setState(() {
                          _target = value!;
                        });
                      },
                    ),
                  ),
                  Center(
                    child: RadioListTile<int>(
                      title: const Text('映像ファイル -> mp3'),
                      value: 2,
                      groupValue: _target,
                      onChanged: (int? value) {
                        setState(() {
                          _target = value!;
                        });
                      },
                    ),
                  ),
                  Center(
                    child: RadioListTile<int>(
                      title: const Text('mp4 -> DVD形式'),
                      value: 3,
                      groupValue: _target,
                      onChanged: (int? value) {
                        setState(() {
                          _target = value!;
                        });
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _filePicker(context),
                    child: Text('ファイルを選択'),
                  ),
                ],
              ),
            ),
          )
        : _buildConvertingView();
  }

  Widget _buildConvertingView() {
    final overall = _totalFiles == 0
        ? 0.0
        : (_currentIndex + _fileProgress) / _totalFiles;
    final percent = (overall * 100).toStringAsFixed(1);
    return Container(
      decoration: BoxDecoration(color: Color.fromRGBO(202, 190, 190, 0.559)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: overall > 0 ? overall : null,
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: 16),
          Text(
            '$percent%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _totalFiles > 1
                ? '変換中... (${_currentIndex + 1} / $_totalFiles)'
                : '変換中...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
