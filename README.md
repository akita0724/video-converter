# video_converter

Convert video or audio file into mp4, mp3, mpg.

H.264 出力時は NVENC / Intel QSV / AMD AMF を自動検出してハードウェアエンコードを利用します。
利用できない場合は `libx264` (mp4) / `mpeg2video` (DVD) に自動でフォールバックします。

## ffmpeg バイナリの配置

本アプリは `ffmpeg.exe` / `ffprobe.exe` を実行ファイルと同階層から探します。

### Windows ローカルビルド

[gyan.dev の ffmpeg release-essentials](https://www.gyan.dev/ffmpeg/builds/) を解凍し、

```
windows/ffmpeg/bin/ffmpeg.exe
windows/ffmpeg/bin/ffprobe.exe
windows/ffmpeg/LICENSE.txt
```

の位置に配置してから `flutter build windows` を実行してください。CMake が `install` 時に `runner` の出力ディレクトリへコピーします。

### CI

`.github/workflows/main.yml` 内で release-essentials zip を自動的に取得します。

### macOS

ローカル開発時は PATH 上の `ffmpeg` / `ffprobe` (`brew install ffmpeg`) を利用します。
CI ビルドの `.app` には evermeet.cx の static ビルドが `Contents/MacOS/` に同梱されます。

### Linux

PATH 上の `ffmpeg` / `ffprobe` を利用します。

## Getting Started

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
