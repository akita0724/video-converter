import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'ff_lib.dart';
import 'dart:io';

import 'package:path/path.dart' as p;

final _fileType = [
  [
    '映像ファイル -> mp4',
    ['mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv', 'webm'],
    '.mp4'
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
  ]
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
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 104, 205, 195)),
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

  void _filePicker(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _fileType[_target][1] as List<String>,
    );
    if (result != null) {
      List<String> filePath = result.files.map((e) => e.path ?? '').toList();
      setState(() {
        _isConverting = true; // Start converting
      });
      for (int i = 0; i < filePath.length; i++) {
        await ffmpegMain(
          _target,
          p.relative(
            filePath[i],
            from: Platform.environment['HOME'],
          ),
          _fileType[_target][2] as String,
        );
      }
      setState(() {
        _isConverting = false; // Stop converting
      });
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
                title: Center(
              child: Text('変換が完了しました!',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                  )),
            ));
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
        : Container(
            decoration: BoxDecoration(
              color: Color.fromRGBO(202, 190, 190, 0.559),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              ],
            ),
          );
  }
}
