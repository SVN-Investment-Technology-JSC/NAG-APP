import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:nguyenanh/features/chatbot/data/models/chat_models.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  final Dio _dio;

  ChatService(this._dio);

  String _createChatSessionId() {
    return 'chatbot-flutter-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> runWithTools({
    required List<ChatMessage> messages,
    String? sessionId,
    CancelToken? cancelToken,
    void Function(String status)? onStatus,
    void Function(String chunk)? onContent,
    void Function(String name, Map<String, dynamic> args)? onToolStart,
    void Function(int iteration)? onIteration,
    void Function()? onDone,
    void Function(Exception error)? onError,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final role = prefs.getString('user_role');
      final userFullName = prefs.getString('user_full_name');
      final userToken = prefs.getString('access_token');
      
      final Map<String, dynamic> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppEndpoints.chatAgentApiToken}',
        'X-NAG-Prod-API-URL': AppEndpoints.apiBaseUrl,
      };

      if (userToken != null) {
        headers['X-User-Authorization'] = 'Bearer $userToken';
      }
      
      if (userId != null) {
        headers['X-NAG-User-Id'] = userId.toString();
        headers['X-NAG-Role'] = role ?? 'user';
        
        final userContext = {
          'user_id': userId,
          'role': role ?? 'user',
          'user_full_name': userFullName ?? 'User',
          'permissions': [],
        };
        
        final jsonStr = jsonEncode(userContext);
        final bytes = utf8.encode(jsonStr);
        headers['X-NAG-User-Context'] = base64UrlEncode(bytes).replaceAll('=', '');
      }

      if (sessionId != null && sessionId.trim().isNotEmpty) {
        headers['X-Chat-Session-Id'] = sessionId.trim();
      }

      final agentDio = Dio();

      final response = await agentDio.post<ResponseBody>(
        AppEndpoints.chatAgentStreamUrl,
        data: {
          'messages': messages.map((m) => m.toJson()).toList(),
          'maxIterations': 4,
        },
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(seconds: 30),
        ),
        cancelToken: cancelToken,
      );

      final stream = response.data?.stream;
      if (stream == null) {
        onError?.call(Exception('No stream returned'));
        return;
      }

      String buffer = '';

      await for (final chunk in stream) {
        if (cancelToken?.isCancelled ?? false) break;
        
        final decoded = utf8.decode(chunk, allowMalformed: true);
        buffer += decoded;

        int separatorIndex;
        while ((separatorIndex = buffer.indexOf('\n\n')) != -1) {
          final rawEvent = buffer.substring(0, separatorIndex);
          buffer = buffer.substring(separatorIndex + 2);
          
          final dataLines = <String>[];
          for (final line in rawEvent.split('\n')) {
            if (line.startsWith('data:')) {
              dataLines.add(line.substring(5).trim());
            }
          }
          
          if (dataLines.isEmpty) continue;
          
          final dataString = dataLines.join('\n');
          if (dataString == '[DONE]') {
            onDone?.call();
            return;
          }

          ChatStreamEvent parsed;
          try {
            parsed = ChatStreamEvent.fromJson(jsonDecode(dataString));
          } catch (_) {
            onContent?.call(dataString);
            continue;
          }

          if (parsed.type == 'iteration' && parsed.iteration != null) {
            onIteration?.call(parsed.iteration!);
          }
          if (parsed.type == 'tool_start' && parsed.tool != null) {
            onToolStart?.call(parsed.tool!, parsed.args ?? {});
          }
          if (parsed.status != null && parsed.status!.trim().isNotEmpty) {
            onStatus?.call(parsed.status!);
          }
          
          final contentChunk = parsed.content ?? parsed.text ?? parsed.delta;
          if (contentChunk != null) {
            onContent?.call(contentChunk);
          }
          
          if (parsed.error != null) {
            onError?.call(Exception(parsed.error));
            return;
          }
          
          if (parsed.done == true) {
            onDone?.call();
            return;
          }
        }
      }
      onDone?.call();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      onError?.call(Exception(e.message ?? e.toString()));
    } catch (e) {
      onError?.call(Exception(e.toString()));
    }
  }

  Future<void> clearMemory(String sessionId) async {
    try {
      final agentDio = Dio();
      await agentDio.delete(
        AppEndpoints.chatAgentMemoryUrl,
        options: Options(
          headers: {
            'X-Chat-Session-Id': sessionId,
            'Authorization': 'Bearer ${AppEndpoints.chatAgentApiToken}',
          },
        ),
      );
    } catch (_) {}
  }
}
