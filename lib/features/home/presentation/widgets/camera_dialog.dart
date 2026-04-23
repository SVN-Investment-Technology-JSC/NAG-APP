import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';

class CameraDialog extends StatefulWidget {
  final Station station;

  const CameraDialog({super.key, required this.station});

  static void show(BuildContext context, Station station) {
    showDialog(
      context: context,
      builder: (_) => CameraDialog(station: station),
    );
  }

  @override
  State<CameraDialog> createState() => _CameraDialogState();
}

class _CameraDialogState extends State<CameraDialog> {
  late Timer _timer;
  bool _isDisposed = false;
  Uint8List? _currentFrame;
  bool _isError = false;
  String _errorMessage = '';
  bool _isLoading = true;

  // Digest Auth state
  String? _authHeader;
  int _ncCount = 1;
  bool _isFetching = false;
  bool _minLoadingDone = false;

  @override
  void initState() {
    super.initState();
    _startStream();
    
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_isDisposed) {
        setState(() {
          _minLoadingDone = true;
        });
      }
    });
  }

  void _startStream() {
    _fetchFrame();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!_isDisposed && !_isFetching) {
        _fetchFrame();
      }
    });
  }

  Future<void> _fetchFrame() async {
    final ip = widget.station.stationIpAddress;
    final port = widget.station.stationId == 1 ? '81' : 
                 widget.station.stationId == 2 ? '82' : 
                 widget.station.stationId == 3 ? '80' : '80';

    if (ip == null || ip.isEmpty) {
      setState(() { _isLoading = false; _isError = true; });
      return;
    }

    _isFetching = true;
    final targetUrl = 'http://$ip:$port/ISAPI/Streaming/channels/102/picture';

    try {
      final dio = Dio(BaseOptions(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        validateStatus: (status) => true,
      ));

      final headers = <String, dynamic>{};
      if (_authHeader != null) {
        headers['Authorization'] = _authHeader;
      }

      var res = await dio.get(targetUrl, options: Options(headers: headers));

      if (res.statusCode == 401) {
        final wwwAuth = res.headers.value('www-authenticate');
        if (wwwAuth != null && wwwAuth.contains('Digest')) {
          _authHeader = _generateDigestAuthHeader(wwwAuth, 'GET', '/ISAPI/Streaming/channels/102/picture');
          headers['Authorization'] = _authHeader;
          res = await dio.get(targetUrl, options: Options(headers: headers));
        } else {
          final basic = 'Basic ${base64Encode(utf8.encode('admin:14526525aA@'))}';
          headers['Authorization'] = basic;
          res = await dio.get(targetUrl, options: Options(headers: headers));
        }
      }

      if (res.statusCode == 200 && res.data != null) {
        if (!_isDisposed) {
          setState(() {
            _currentFrame = Uint8List.fromList(res.data);
            _isLoading = false;
            _isError = false;
            _errorMessage = '';
          });
        }
      } else {
        if (!_isDisposed && _currentFrame == null) {
          setState(() { _isError = true; _errorMessage = 'HTTP ${res.statusCode}'; _isLoading = false; });
        }
      }
    } on DioException catch (e) {
      if (!_isDisposed && _currentFrame == null) {
        setState(() { _isError = true; _errorMessage = e.message ?? e.toString(); _isLoading = false; });
      }
    } catch (e) {
      if (!_isDisposed && _currentFrame == null) {
        setState(() { _isError = true; _errorMessage = e.toString(); _isLoading = false; });
      }
    } finally {
      _isFetching = false;
    }
  }

  String _generateDigestAuthHeader(String wwwAuth, String method, String uri) {
    const user = 'admin';
    const pass = '14526525aA@';

    final realmMatch = RegExp(r'realm="([^"]+)"').firstMatch(wwwAuth);
    final nonceMatch = RegExp(r'nonce="([^"]+)"').firstMatch(wwwAuth);
    final qopMatch = RegExp(r'qop="([^"]+)"').firstMatch(wwwAuth);

    if (realmMatch == null || nonceMatch == null) return '';

    final realm = realmMatch.group(1)!;
    final nonce = nonceMatch.group(1)!;
    final qop = qopMatch != null ? qopMatch.group(1)! : 'auth';

    final ha1 = md5.convert(utf8.encode('$user:$realm:$pass')).toString();
    final ha2 = md5.convert(utf8.encode('$method:$uri')).toString();
    
    final nc = _ncCount.toRadixString(16).padLeft(8, '0');
    _ncCount++;
    
    final cnonce = md5.convert(utf8.encode(DateTime.now().millisecondsSinceEpoch.toString())).toString().substring(0, 8);

    final response = md5.convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2')).toString();

    return 'Digest username="$user", realm="$realm", nonce="$nonce", uri="$uri", qop=$qop, nc=$nc, cnonce="$cnonce", response="$response"';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final ip = widget.station.stationIpAddress;
    final port = widget.station.stationId == 1 ? '81' : 
                 widget.station.stationId == 2 ? '82' : 
                 widget.station.stationId == 3 ? '80' : '80';
    final bool hasConfig = ip != null && ip.isNotEmpty;

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
                children: [
                  Icon(Icons.videocam_rounded, color: const Color(0xFF6366F1), size: 24.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Camera Giám Sát - ${widget.station.stationName}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'IP: ${ip ?? 'Chưa cấu hình'} | Port: $port',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 24.sp),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.black,
              height: 250.h,
              child: Builder(
                builder: (context) {
                  if (!hasConfig) {
                    return Center(
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
                    );
                  }
                  if (_currentFrame != null) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          _currentFrame!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                        Positioned(
                          bottom: 12.h,
                          right: 12.w,
                          child: IconButton(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => FullScreenCameraPage(station: widget.station),
                              ));
                            },
                            icon: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 28.sp),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  if (!_minLoadingDone) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                    );
                  }
                  if (_isError) {
                    return Center(
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
                    );
                  }
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  );
                },
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

  const FullScreenCameraPage({super.key, required this.station});

  @override
  State<FullScreenCameraPage> createState() => _FullScreenCameraPageState();
}

class _FullScreenCameraPageState extends State<FullScreenCameraPage> {
  late Timer _timer;
  bool _isDisposed = false;
  Uint8List? _currentFrame;
  bool _isError = false;
  String _errorMessage = '';
  bool _isLoading = true;
  bool _minLoadingDone = false;

  // Digest Auth state
  String? _authHeader;
  int _ncCount = 1;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _startStream();
    
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && !_isDisposed) {
        setState(() {
          _minLoadingDone = true;
        });
      }
    });
  }

  void _startStream() {
    _fetchFrame();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!_isDisposed && !_isFetching) {
        _fetchFrame();
      }
    });
  }

  Future<void> _fetchFrame() async {
    final ip = widget.station.stationIpAddress;
    final port = widget.station.stationId == 1 ? '81' : 
                 widget.station.stationId == 2 ? '82' : 
                 widget.station.stationId == 3 ? '80' : '80';

    if (ip == null || ip.isEmpty) {
      setState(() { _isLoading = false; _isError = true; });
      return;
    }

    _isFetching = true;
    final targetUrl = 'http://$ip:$port/ISAPI/Streaming/channels/102/picture';

    try {
      final dio = Dio(BaseOptions(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
        validateStatus: (status) => true,
      ));

      final headers = <String, dynamic>{};
      if (_authHeader != null) {
        headers['Authorization'] = _authHeader;
      }

      var res = await dio.get(targetUrl, options: Options(headers: headers));

      if (res.statusCode == 401) {
        final wwwAuth = res.headers.value('www-authenticate');
        if (wwwAuth != null && wwwAuth.contains('Digest')) {
          _authHeader = _generateDigestAuthHeader(wwwAuth, 'GET', '/ISAPI/Streaming/channels/102/picture');
          headers['Authorization'] = _authHeader;
          res = await dio.get(targetUrl, options: Options(headers: headers));
        } else {
          final basic = 'Basic ${base64Encode(utf8.encode('admin:14526525aA@'))}';
          headers['Authorization'] = basic;
          res = await dio.get(targetUrl, options: Options(headers: headers));
        }
      }

      if (res.statusCode == 200 && res.data != null) {
        if (!_isDisposed) {
          setState(() {
            _currentFrame = Uint8List.fromList(res.data);
            _isLoading = false;
            _isError = false;
            _errorMessage = '';
          });
        }
      } else {
        if (!_isDisposed && _currentFrame == null) {
          setState(() { _isError = true; _errorMessage = 'HTTP ${res.statusCode}'; _isLoading = false; });
        }
      }
    } on DioException catch (e) {
      if (!_isDisposed && _currentFrame == null) {
        setState(() { _isError = true; _errorMessage = e.message ?? e.toString(); _isLoading = false; });
      }
    } catch (e) {
      if (!_isDisposed && _currentFrame == null) {
        setState(() { _isError = true; _errorMessage = e.toString(); _isLoading = false; });
      }
    } finally {
      _isFetching = false;
    }
  }

  String _generateDigestAuthHeader(String wwwAuth, String method, String uri) {
    const user = 'admin';
    const pass = '14526525aA@';
    final realmMatch = RegExp(r'realm="([^"]+)"').firstMatch(wwwAuth);
    final nonceMatch = RegExp(r'nonce="([^"]+)"').firstMatch(wwwAuth);
    final qopMatch = RegExp(r'qop="([^"]+)"').firstMatch(wwwAuth);

    if (realmMatch == null || nonceMatch == null) return '';

    final realm = realmMatch.group(1)!;
    final nonce = nonceMatch.group(1)!;
    final qop = qopMatch != null ? qopMatch.group(1)! : 'auth';

    final ha1 = md5.convert(utf8.encode('$user:$realm:$pass')).toString();
    final ha2 = md5.convert(utf8.encode('$method:$uri')).toString();
    
    final nc = _ncCount.toRadixString(16).padLeft(8, '0');
    _ncCount++;
    
    final cnonce = md5.convert(utf8.encode(DateTime.now().millisecondsSinceEpoch.toString())).toString().substring(0, 8);
    final response = md5.convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2')).toString();

    return 'Digest username="$user", realm="$realm", nonce="$nonce", uri="$uri", qop=$qop, nc=$nc, cnonce="$cnonce", response="$response"';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.station.stationName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_currentFrame != null) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: Center(
                  child: Image.memory(
                    _currentFrame!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              );
            }
            if (!_minLoadingDone) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              );
            }
            if (_isError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 64.sp),
                    SizedBox(height: 16.h),
                    Text(
                      'Mất kết nối Camera',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            );
          },
        ),
      ),
    );
  }
}
