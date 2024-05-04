// import 'package:ffmpeg_helper/ffmpeg_helper.dart';
// import 'package:process_run/cmd_run.dart'

import 'dart:io';

import 'package:ffmpeg_cli/ffmpeg_cli.dart';

// Get home directory
final homeDir = Platform.environment['HOME'] ?? "";

/// Converts the given [path] to a new format.
///
/// This function takes a [path] as input and returns a new formatted path.
/// The conversion logic is not specified in this function and should be implemented separately.
///
/// Example:
/// ```dart
/// String path = '/Users/yohei/Git/IBC/ibc_video/lib/ff_lib.dart';
/// String convertedPath = convertPath(path);
/// print(convertedPath); // Output: '/Users/yohei/Git/IBC/ibc_video/lib/ff_lib.dart'
/// ```
String convertPath(String path) {
  final index = path.indexOf(homeDir);

  final dir = '$homeDir${path.substring(index + homeDir.length)}';

  return dir;
}

/// Executes FFmpeg commands asynchronously.
///
/// The [command] parameter is a list of [FfmpegCommand] objects that represent the FFmpeg commands to be executed.
/// This function runs the commands asynchronously, allowing other code to continue executing while the FFmpeg commands are running.
Future<void> ffmpegExe(List<FfmpegCommand> command) async {
  for (int i = 0; i < command.length; i++) {
    // await Ffmpeg().run(command[i]);
    await Process.run('ffmpeg', [...command[i].toCli().args]);
  }
  return;
}

/// Executes the main function for FFmpeg.
///
/// This function is responsible for executing the main logic of FFmpeg.
/// It returns a [Future] that completes when the execution is finished.
///
/// Example usage:
/// ```dart
/// await ffmpegMain();
/// ```
///
/// Throws an error if there is an issue with the execution.
Future<void> ffmpegMain(
    int execType, String filePath, String fileExtention) async {
  int width = 0;
  int height = 0;

  // Get media information
  if (execType != 1) {
    FfprobeResult mediaInfo = await Ffprobe.run(convertPath(filePath));
    width = mediaInfo.streams?.first.width ?? 0;
    height = mediaInfo.streams?.first.height ?? 0;
  }

  // int bitrate = int.parse(mediaInfo.streams?.first.bitRate ?? "");

  // Create output file path
  String outputFilePath =
      '${convertPath(filePath.replaceAll(RegExp('\\.[^.]*\$'), ''))}_out$fileExtention';

  if (outputFilePath.endsWith('.')) {
    outputFilePath = outputFilePath.substring(0, outputFilePath.length - 1);
  }

  // Constract FfmpegCommand And Run
  // 0: Video -> mp4
  // 1: Audio -> mp3
  // 2: Video -> mp3
  // 3: Video -> DVD

  final String inputFilePath = convertPath(filePath);

  if (execType == 0) {
    await ffmpegExe([
      FfmpegCommand.simple(
        inputs: [FfmpegInput.asset(inputFilePath)],
        args: [
          CliArg(name: 'c:v', value: 'libx264'),
          CliArg(name: 'y', value: null),
        ],
        outputFilepath: outputFilePath,
      )
    ]);
  } else if (execType == 1) {
    await ffmpegExe([
      FfmpegCommand.simple(
        inputs: [FfmpegInput.asset(inputFilePath)],
        args: [
          // CliArg(name: '-c:a', value: 'libmp3lame'),
          CliArg(name: 'y', value: null),
        ],
        outputFilepath: outputFilePath,
      )
    ]);
  } else if (execType == 2) {
    await ffmpegExe([
      FfmpegCommand.simple(
        inputs: [FfmpegInput.asset(inputFilePath)],
        args: [
          CliArg(name: 'y', value: null),
          CliArg(name: 'acodec', value: 'libmp3lame'),
          CliArg(name: 'ab', value: '256k'),
        ],
        outputFilepath: outputFilePath,
      )
    ]);
  } else if (execType == 3) {
    await ffmpegExe([
      FfmpegCommand.simple(
        inputs: [FfmpegInput.asset(inputFilePath)],
        args: [
          CliArg(name: 'y', value: null),
          CliArg(
              name: 'vf',
              value: 'scale=$width:$height,format=yuv420p,fps=30000/1001'),
          CliArg(name: 'c', value: 'mpeg2video'),
          CliArg(name: 'vsync', value: '1'),
          CliArg(name: 'target', value: 'ntsc-dvd'),
          CliArg(name: 'aspect', value: '16:9'),
        ],
        outputFilepath: outputFilePath,
      ),
      FfmpegCommand.simple(
        inputs: [FfmpegInput.asset(filePath)],
        args: [
          CliArg(name: 'y', value: null),
          CliArg(
              name: 'vf',
              value: 'scale={$width}:{$height},format=yuv420p,fps=30000/1001'),
          CliArg(name: 'c', value: 'mpeg2video'),
          CliArg(name: 'vsync', value: '1'),
          CliArg(name: 'target', value: 'ntsc-dvd'),
          CliArg(name: 'aspect', value: '16:9'),
          CliArg(name: 'maxrate', value: '9000k'),
          // VideoBitrateArgument(bitrate),
        ],
        outputFilepath: outputFilePath,
      )
    ]);
  }
  return;
}
