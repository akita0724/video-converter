# 開発・リリース手順

## 開発環境セットアップ

### 必須

- Flutter SDK 3.19.2 以降 (CI と揃えるなら `3.19.2`)
- Dart 3.0 以降 (Flutter SDK に同梱されるもので OK)

### プラットフォーム別ツール

- **Windows**: Visual Studio (C++ デスクトップ開発ワークロード) + CMake
- **macOS**: Xcode + CocoaPods (`brew install cocoapods`)
  - Xcode を全部入れた直後は `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` で開発者ディレクトリを Xcode 本体側に切り替え

### ffmpeg バイナリ

ローカルビルド前に下記いずれかで `ffmpeg` / `ffprobe` を用意:

- **Windows**: [gyan.dev release-essentials](https://www.gyan.dev/ffmpeg/builds/) を展開して
  - `windows/ffmpeg/bin/ffmpeg.exe`
  - `windows/ffmpeg/bin/ffprobe.exe`
  - `windows/ffmpeg/LICENSE.txt`
- **macOS**: `brew install ffmpeg` で PATH 上に入れる (CI ビルドの `.app` には evermeet.cx の static が同梱されます)

`lib/ff_lib.dart` の `_resolveFfBinary()` が実行ファイルと同階層の `ffmpeg`/`ffprobe` を優先し、無ければ PATH を探します。

## ローカルビルド

```sh
flutter pub get
flutter run -d macos          # macOS で開発実行
flutter run -d windows        # Windows で開発実行
flutter build macos --release
flutter build windows --release
```

## CI

`.github/workflows/main.yml` が `push` で発火します。

| ジョブ | ランナー | 動作 |
|---|---|---|
| `build-and-release-windows` | `windows-latest` | ffmpeg 取得 → `flutter build windows --release` → zip |
| `build-and-release-macos` | `macos-latest` | `flutter build macos --release` → `.app/Contents/MacOS/` に ffmpeg/ffprobe 同梱 → ditto で zip |

### Release を作るには tag push が必要

通常の `git push origin main` ではビルド検証だけが走り、GitHub Release は作成されません。
両ジョブの最後にある `if: startsWith(github.ref, 'refs/tags/')` で **tag push 時だけ** リリース作成ステップが走ります。

リリース手順:

```sh
git tag v1.2.3
git push origin v1.2.3
```

これで `release-windows-v1.2.3.zip` と `release-macos-v1.2.3.zip` が
[GitHub Releases](../../releases) に添付されます。

リポジトリ Secret に `CI_TOKEN` (リポジトリ書き込み権限付き PAT) が必要です。

## ハードウェアエンコーディング

`lib/ff_lib.dart::detectHwEncoder()` が起動後の最初の変換時に一度だけ
NVENC → QSV → AMF の順で実エンコード probe を行い、結果をキャッシュします。
全て失敗した場合は H.264 / MPEG-2 のソフトウェアエンコーダー
(`libx264` / `mpeg2video`) にフォールバックします。

## 進捗表示

`ffmpegMain(..., onProgress: (double p) {...})` でファイル単位の 0.0–1.0 進捗を
受け取れます。内部では `ffmpeg -progress pipe:1 -nostats` の `out_time_ms` を
ffprobe 取得の総再生時間で割って算出しています。

## トラブルシューティング

- **Windows ビルドが `win32` の `UnmodifiableUint8ListView` エラーで落ちる**: 古い transitive 依存。`flutter pub upgrade` で `win32 >= 5.15.0` に上げる。
- **macOS で `xcrun: error: unable to find utility "xcodebuild"`**: `xcode-select -p` が `/Library/Developer/CommandLineTools` を指している。上記の `sudo xcode-select -s ...` で切替。
- **`.app` を開こうとして「開発元を確認できないため開けません」**: 非署名のため。Finder で右クリック→開く で初回ダイアログを承認。CI 産出物は `xattr -dr com.apple.quarantine` で quarantine 属性を剥がしているのでクリーンに開きます。
