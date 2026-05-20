import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class OfflineMapTileProvider extends TileProvider {
  OfflineMapTileProvider({super.headers})
    : _cacheDirectory = _createCacheDirectory();

  final Future<Directory> _cacheDirectory;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _OfflineMapTileImageProvider(
      url: getTileUrl(coordinates, options),
      headers: Map.unmodifiable(headers),
      cacheFile: _cacheFile(coordinates),
    );
  }

  Future<File> _cacheFile(TileCoordinates coordinates) async {
    final directory = await _cacheDirectory;
    return File(
      path.join(
        directory.path,
        coordinates.z.toString(),
        coordinates.x.toString(),
        '${coordinates.y}.png',
      ),
    );
  }

  static Future<Directory> _createCacheDirectory() async {
    final root = await getApplicationCacheDirectory();
    final directory = Directory(path.join(root.path, 'map_tiles'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

class _OfflineMapTileImageProvider
    extends ImageProvider<_OfflineMapTileImageProvider> {
  const _OfflineMapTileImageProvider({
    required this.url,
    required this.headers,
    required this.cacheFile,
  });

  final String url;
  final Map<String, String> headers;
  final Future<File> cacheFile;

  @override
  ImageStreamCompleter loadImage(
    _OfflineMapTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: url,
      informationCollector: () => [
        DiagnosticsProperty('URL', url),
        DiagnosticsProperty('Provider', key),
      ],
    );
  }

  Future<ui.Codec> _load(
    _OfflineMapTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final file = await cacheFile;
    final cachedBytes = await _readCachedTile(file);
    if (cachedBytes != null) {
      return _decode(cachedBytes, decode);
    }

    final downloadedBytes = await _downloadTile();
    if (downloadedBytes != null) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(downloadedBytes, flush: false);
      return _decode(downloadedBytes, decode);
    }

    return _decode(TileProvider.transparentImage, decode);
  }

  Future<Uint8List?> _readCachedTile(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } on Object {
      return null;
    }
  }

  Future<Uint8List?> _downloadTile() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

    try {
      final request = await client.getUrl(Uri.parse(url));
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      return bytes.isEmpty ? null : bytes;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<ui.Codec> _decode(Uint8List bytes, ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  Future<_OfflineMapTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture(this);
  }
}
