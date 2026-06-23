import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';

class CameraSnapshotService {
  static Future<Uint8List?> fetchCameraSnapshot(String? ip, String? port) async {
    if (ip == null || ip.isEmpty) return null;
    
    final user = 'admin';
    final pass = '14526525aA@';
    
    final dio = Dio();
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );

    Future<Uint8List?> attemptFetch(String targetUrl) async {
      try {
        final res = await dio.get(
          targetUrl,
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => true,
            receiveTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 8),
          ),
        );

        if (res.statusCode == 200) return Uint8List.fromList(res.data);

        if (res.statusCode == 401) {
          final wwwAuth = res.headers.value('www-authenticate') ?? '';
          if (wwwAuth.contains('Digest')) {
            final realmMatch = RegExp(r'realm="([^"]+)"').firstMatch(wwwAuth);
            final nonceMatch = RegExp(r'nonce="([^"]+)"').firstMatch(wwwAuth);

            if (realmMatch != null && nonceMatch != null) {
              final realm = realmMatch.group(1)!;
              final nonce = nonceMatch.group(1)!;
              final uri = '/ISAPI/Streaming/channels/102/picture';
              final method = 'GET';
              final nc = '00000001';
              final randomBytes = List.generate(4, (_) => Random().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
              final cnonce = randomBytes;

              final ha1 = md5.convert(utf8.encode('$user:$realm:$pass')).toString();
              final ha2 = md5.convert(utf8.encode('$method:$uri')).toString();
              final response = md5.convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:auth:$ha2')).toString();

              final authHeader = 'Digest username="$user", realm="$realm", nonce="$nonce", uri="$uri", qop=auth, nc=$nc, cnonce="$cnonce", response="$response"';

              final authRes = await dio.get(
                targetUrl,
                options: Options(
                  responseType: ResponseType.bytes,
                  headers: {'Authorization': authHeader},
                  validateStatus: (status) => true,
                  receiveTimeout: const Duration(seconds: 8),
                ),
              );

              if (authRes.statusCode == 200) return Uint8List.fromList(authRes.data);
              throw Exception('Digest auth failed: ${authRes.statusCode}');
            }
          }
          
          final basicAuth = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
          final basicRes = await dio.get(
            targetUrl,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {'Authorization': basicAuth},
              validateStatus: (status) => true,
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

          if (basicRes.statusCode == 200) return Uint8List.fromList(basicRes.data);
          throw Exception('Basic auth failed: ${basicRes.statusCode}');
        }

        throw Exception('HTTP ${res.statusCode}');
      } catch (e) {
        rethrow;
      }
    }

    try {
      final httpUrl = 'http://$ip:${port ?? '80'}/ISAPI/Streaming/channels/102/picture';
      return await attemptFetch(httpUrl);
    } catch (e) {
      try {
        final httpsUrl = 'https://$ip:${port ?? '443'}/ISAPI/Streaming/channels/102/picture';
        return await attemptFetch(httpsUrl);
      } catch (httpsErr) {
        throw Exception('Mất kết nối Camera (HTTP & HTTPS)');
      }
    }
  }
}

class CameraFeedConfig {
  final String name;
  final String port;
  final String channel;
  final String? overrideIp;

  const CameraFeedConfig({
    required this.name,
    required this.port,
    this.channel = '102',
    this.overrideIp,
  });
}

const Map<int, List<CameraFeedConfig>> stationCamerasConfig = {
  1: [
    CameraFeedConfig(
      name: 'Trạm C (Hướng chính)',
      port: '81',
    ),
    CameraFeedConfig(
      name: 'Trạm C (Hướng phụ)',
      port: '83',
    ),
  ],
};

List<CameraFeedConfig> getStationCameras(Station station) {
  final configured = stationCamerasConfig[station.stationId];
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }

  final defaultPort = station.stationId == 2 ? '82' : '80';
  return [
    CameraFeedConfig(
      name: 'Camera ${station.stationName}',
      port: defaultPort,
    ),
  ];
}

class CameraDialog extends StatelessWidget {
  final Station station;

  const CameraDialog({super.key, required this.station});

  static void show(BuildContext context, Station station) {
    showDialog(
      context: context,
      builder: (_) => CameraDialog(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeCameras = getStationCameras(station);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_rounded, color: const Color(0xFF6366F1), size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Camera Giám Sát - ${station.stationName}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                            fontSize: 18.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          station.stationIpAddress != null && station.stationIpAddress!.isNotEmpty
                              ? 'IP: ${station.stationIpAddress}${activeCameras.length == 1 ? ' | Port: ${activeCameras[0].port}' : ''}'
                              : 'Chưa cấu hình IP',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 20.sp, color: colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.all(4.w),
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(backgroundColor: Colors.transparent),
                  ),
                ],
              ),
            ),
            
            // Body
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(activeCameras.length, (index) {
                      final cam = activeCameras[index];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (index > 0) Container(height: 2.h, color: Colors.grey[800]),
                          CameraFrameWidget(
                            station: station,
                            config: cam,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraFrameWidget extends StatefulWidget {
  final Station station;
  final CameraFeedConfig config;

  const CameraFrameWidget({
    super.key,
    required this.station,
    required this.config,
  });

  @override
  State<CameraFrameWidget> createState() => _CameraFrameWidgetState();
}

class _CameraFrameWidgetState extends State<CameraFrameWidget> {
  bool _isDisposed = false;
  Uint8List? _currentFrame;
  bool _isError = false;
  String _errorMessage = '';
  bool _isLoading = true;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _fetchFrame();
  }

  Future<void> _fetchFrame() async {
    final ip = widget.config.overrideIp ?? widget.station.stationIpAddress;
    final port = widget.config.port;

    if (ip == null || ip.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _isError = true; });
      return;
    }

    if (mounted) {
      setState(() {
        _isFetching = true;
        _isError = false;
        _errorMessage = '';
      });
    }

    try {
      final bytes = await CameraSnapshotService.fetchCameraSnapshot(ip, port);
      if (!_isDisposed && mounted) {
        if (bytes != null) {
          setState(() {
            _currentFrame = bytes;
            _isLoading = false;
            _isError = false;
          });
        } else {
          setState(() { _isError = true; _errorMessage = 'Dữ liệu ảnh rỗng'; _isLoading = false; });
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() { _isError = true; _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ip = widget.config.overrideIp ?? widget.station.stationIpAddress;
    final port = widget.config.port;
    final bool hasConfig = ip != null && ip.isNotEmpty;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: !hasConfig 
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Text(
                  'Vui lòng cấu hình IP và Port cho camera của trạm này trong phần quản lý trạm.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_currentFrame != null)
                  Image.memory(
                    _currentFrame!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                if (_isLoading && _currentFrame == null)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                if (_isError && _currentFrame == null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 48.sp),
                        SizedBox(height: 8.h),
                        Text(
                          'Mất kết nối Camera',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                        if (_errorMessage.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Text(
                              _errorMessage,
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                
                // Overlays
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '${widget.config.name} ($ip:$port)',
                      style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: IconButton(
                    onPressed: _isFetching ? null : _fetchFrame,
                    icon: _isFetching 
                        ? SizedBox(width: 20.sp, height: 20.sp, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(Icons.refresh_rounded, color: Colors.white, size: 24.sp),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
                if (_currentFrame != null)
                  Positioned(
                    bottom: 12.h,
                    right: 12.w,
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => FullScreenCameraPage(
                            station: widget.station,
                            config: widget.config,
                          ),
                        ));
                      },
                      icon: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 28.sp),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}

class FullScreenCameraPage extends StatefulWidget {
  final Station station;
  final CameraFeedConfig config;

  const FullScreenCameraPage({
    super.key,
    required this.station,
    required this.config,
  });

  @override
  State<FullScreenCameraPage> createState() => _FullScreenCameraPageState();
}

class _FullScreenCameraPageState extends State<FullScreenCameraPage> {
  bool _isDisposed = false;
  Uint8List? _currentFrame;
  bool _isError = false;
  String _errorMessage = '';
  bool _isLoading = true;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _fetchFrame();
  }

  Future<void> _fetchFrame() async {
    final ip = widget.config.overrideIp ?? widget.station.stationIpAddress;
    final port = widget.config.port;

    if (ip == null || ip.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _isError = true; });
      return;
    }

    if (mounted) {
      setState(() {
        _isFetching = true;
        _isError = false;
        _errorMessage = '';
      });
    }

    try {
      final bytes = await CameraSnapshotService.fetchCameraSnapshot(ip, port);
      if (!_isDisposed && mounted) {
        if (bytes != null) {
          setState(() {
            _currentFrame = bytes;
            _isLoading = false;
            _isError = false;
          });
        } else {
          setState(() { _isError = true; _errorMessage = 'Dữ liệu ảnh rỗng'; _isLoading = false; });
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() { _isError = true; _errorMessage = e.toString().replaceAll('Exception: ', ''); _isLoading = false; });
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ip = widget.config.overrideIp ?? widget.station.stationIpAddress;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.config.name} - ${widget.station.stationName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isFetching ? null : _fetchFrame,
            icon: _isFetching 
                ? SizedBox(width: 18.sp, height: 18.sp, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Center(
            child: (ip == null || ip.isEmpty)
              ? Center(
                  child: Text(
                    'Chưa cấu hình IP Camera',
                    style: TextStyle(color: Colors.white54, fontSize: 16.sp),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_currentFrame != null)
                      Image.memory(
                        _currentFrame!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    if (_isLoading && _currentFrame == null)
                      const Center(
                        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                      ),
                    if (_isError && _currentFrame == null)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 64.sp),
                            SizedBox(height: 16.h),
                            Text(
                              'Mất kết nối Camera',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                            ),
                            if (_errorMessage.isNotEmpty) ...[
                              SizedBox(height: 8.h),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24.w),
                                child: Text(
                                  _errorMessage,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
