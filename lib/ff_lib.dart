import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_cli/ffmpeg_cli.dart';
import 'package:path/path.dart' as p;

enum HwEncoder { nvenc, qsv, amf, none }

String _resolveFfBinary(String name) {
  final exeName = Platform.isWindows ? '$name.exe' : name;
  if (Platform.isWindows) {
    final bundled = p.join(p.dirname(Platform.resolvedExecutable), exeName);
    if (File(bundled).existsSync()) return bundled;
  }
  return name;
}

String _ffmpegPath() => _resolveFfBinary('ffmpeg');
String _ffprobePath() => _resolveFfBinary('ffprobe');

Future<({int width, int height, double durationSec})> _probeMediaInfo(
  String filepath,
) async {
  final r = await Process.run(_ffprobePath(), [
    '-v',
    'quiet',
    '-print_format',
    'json',
    '-show_format',
    '-show_streams',
    filepath,
  ]);
  if (r.exitCode != 0) {
    return (width: 0, height: 0, durationSec: 0.0);
  }
  final out = r.stdout is String
      ? r.stdout as String
      : utf8.decode(r.stdout as List<int>);
  if (out.isEmpty) return (width: 0, height: 0, durationSec: 0.0);
  final json = jsonDecode(out) as Map<String, dynamic>;
  final streams = (json['streams'] as List?) ?? const [];

  int width = 0;
  int height = 0;
  for (final s in streams) {
    final m = s as Map<String, dynamic>;
    if (m['codec_type'] == 'video' && width == 0) {
      width = (m['width'] as int?) ?? 0;
      height = (m['height'] as int?) ?? 0;
      break;
    }
  }

  double duration = 0;
  final format = json['format'] as Map<String, dynamic>?;
  final formatDur = format?['duration'];
  if (formatDur is String) {
    duration = double.tryParse(formatDur) ?? 0;
  } else if (formatDur is num) {
    duration = formatDur.toDouble();
  }
  if (duration <= 0) {
    for (final s in streams) {
      final m = s as Map<String, dynamic>;
      final d = m['duration'];
      double v = 0;
      if (d is String) v = double.tryParse(d) ?? 0;
      if (d is num) v = d.toDouble();
      if (v > duration) duration = v;
    }
  }

  return (width: width, height: height, durationSec: duration);
}

Future<HwEncoder>? _cachedHw;

Future<HwEncoder> detectHwEncoder() => _cachedHw ??= _probeHwEncoder();

Future<HwEncoder> _probeHwEncoder() async {
  const candidates = <(HwEncoder, String)>[
    (HwEncoder.nvenc, 'h264_nvenc'),
    (HwEncoder.qsv, 'h264_qsv'),
    (HwEncoder.amf, 'h264_amf'),
  ];
  for (final (encoder, name) in candidates) {
    try {
      final r = await Process.run(_ffmpegPath(), [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'nullsrc=s=64x64:d=0.1',
        '-c:v',
        name,
        '-f',
        'null',
        '-',
      ]);
      if (r.exitCode == 0) return encoder;
    } on ProcessException {
      return HwEncoder.none;
    }
  }
  return HwEncoder.none;
}

List<CliArg> _h264EncoderArgs(HwEncoder hw) {
  switch (hw) {
    case HwEncoder.nvenc:
      return [
        CliArg(name: 'c:v', value: 'h264_nvenc'),
        CliArg(name: 'preset', value: 'p5'),
        CliArg(name: 'tune', value: 'hq'),
        CliArg(name: 'rc', value: 'vbr'),
        CliArg(name: 'cq', value: '23'),
        CliArg(name: 'b:v', value: '0'),
      ];
    case HwEncoder.qsv:
      return [
        CliArg(name: 'c:v', value: 'h264_qsv'),
        CliArg(name: 'preset', value: 'slower'),
        CliArg(name: 'global_quality', value: '23'),
        CliArg(name: 'look_ahead', value: '1'),
      ];
    case HwEncoder.amf:
      return [
        CliArg(name: 'c:v', value: 'h264_amf'),
        CliArg(name: 'quality', value: 'quality'),
        CliArg(name: 'rc', value: 'cqp'),
        CliArg(name: 'qp_i', value: '23'),
        CliArg(name: 'qp_p', value: '23'),
      ];
    case HwEncoder.none:
      return [
        CliArg(name: 'c:v', value: 'libx264'),
        CliArg(name: 'preset', value: 'medium'),
        CliArg(name: 'crf', value: '23'),
      ];
  }
}

List<CliArg> _mpeg2EncoderArgs(HwEncoder hw) {
  if (hw == HwEncoder.qsv) {
    return [
      CliArg(name: 'c:v', value: 'mpeg2_qsv'),
      CliArg(name: 'global_quality', value: '5'),
      CliArg(name: 'maxrate', value: '9000k'),
    ];
  }
  return [
    CliArg(name: 'c:v', value: 'mpeg2video'),
    CliArg(name: 'q:v', value: '5'),
    CliArg(name: 'maxrate', value: '9000k'),
  ];
}

Future<int> _runFfmpeg(
  FfmpegCommand command, {
  double totalDurationSec = 0,
  void Function(double progress)? onProgress,
}) async {
  final cli = command.toCli();
  // Inject "-progress pipe:1 -nostats" just before the output filepath so
  // ffmpeg writes structured key=value progress to stdout instead of the
  // human-readable status line on stderr.
  final args = [...cli.args];
  final injectAt = args.length - 1;
  args.insertAll(injectAt, ['-progress', 'pipe:1', '-nostats']);

  final process = await Process.start(cli.executable, args);

  final stderrBuf = StringBuffer();
  process.stderr.transform(utf8.decoder).listen(stderrBuf.write);

  if (onProgress != null && totalDurationSec > 0) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.startsWith('out_time_ms=')) {
            final us = int.tryParse(line.substring('out_time_ms='.length));
            if (us != null && us > 0) {
              final p = (us / 1e6) / totalDurationSec;
              onProgress(p.clamp(0.0, 0.999));
            }
          } else if (line == 'progress=end') {
            onProgress(1.0);
          }
        });
  } else {
    process.stdout.drain();
  }

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln('ffmpeg failed (exit $exitCode)');
    stderr.writeln(stderrBuf);
  } else {
    onProgress?.call(1.0);
  }
  return exitCode;
}

/// Executes the main conversion logic.
///
/// [execType]:
///   0: Video -> mp4
///   1: Audio -> mp3
///   2: Video -> mp3
///   3: Video -> DVD (mpg)
Future<int> ffmpegMain(
  int execType,
  String filePath,
  String fileExtention, {
  void Function(double progress)? onProgress,
}) async {
  final hw = await detectHwEncoder();

  String outputFilePath =
      '${filePath.replaceAll(RegExp(r'\.[^.]*$'), '')}_out$fileExtention';
  if (outputFilePath.endsWith('.')) {
    outputFilePath = outputFilePath.substring(0, outputFilePath.length - 1);
  }

  if ([2, 3].contains(execType) && outputFilePath.contains(' ')) {
    return 1;
  }

  final ffmpegPath = _ffmpegPath();
  final info = await _probeMediaInfo(filePath);
  onProgress?.call(0.0);

  late final FfmpegCommand command;
  switch (execType) {
    case 0:
      command = FfmpegCommand.simple(
        ffmpegPath: ffmpegPath,
        inputs: [FfmpegInput.asset(filePath)],
        args: [
          ..._h264EncoderArgs(hw),
          CliArg(name: 'c:a', value: 'aac'),
          CliArg(name: 'b:a', value: '192k'),
          CliArg(name: 'y', value: null),
        ],
        outputFilepath: outputFilePath,
      );
      break;
    case 1:
      command = FfmpegCommand.simple(
        ffmpegPath: ffmpegPath,
        inputs: [FfmpegInput.asset(filePath)],
        args: [
          CliArg(name: 'c:a', value: 'libmp3lame'),
          CliArg(name: 'q:a', value: '2'),
          CliArg(name: 'y', value: null),
        ],
        outputFilepath: outputFilePath,
      );
      break;
    case 2:
      command = FfmpegCommand.simple(
        ffmpegPath: ffmpegPath,
        inputs: [FfmpegInput.asset(filePath)],
        args: [
          CliArg(name: 'vn', value: null),
          CliArg(name: 'c:a', value: 'libmp3lame'),
          CliArg(name: 'q:a', value: '2'),
          CliArg(name: 'y', value: null),
        ],
        outputFilepath: outputFilePath,
      );
      break;
    case 3:
      final w = info.width > 0 ? info.width : 720;
      final h = info.height > 0 ? info.height : 480;
      command = FfmpegCommand.simple(
        ffmpegPath: ffmpegPath,
        inputs: [FfmpegInput.asset(filePath)],
        args: [
          CliArg(
            name: 'vf',
            value: 'scale=$w:$h,format=yuv420p,fps=30000/1001',
          ),
          ..._mpeg2EncoderArgs(hw),
          CliArg(name: 'target', value: 'ntsc-dvd'),
          CliArg(name: 'aspect', value: '16:9'),
          CliArg(name: 'y', value: null),
        ],
        outputFilepath: outputFilePath,
      );
      break;
    default:
      return 2;
  }

  await _runFfmpeg(
    command,
    totalDurationSec: info.durationSec,
    onProgress: onProgress,
  );
  return 0;
}
