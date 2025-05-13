import 'dart:async';
import 'dart:convert';

import 'package:ansicolor/ansicolor.dart';
import 'package:dio/dio.dart';
import 'package:nocturnal_flutter_logging/src/traits/logs.dart';

const int maxWaitInSeconds = 5;
const int batchToFlush = 10;

class ApplicationLogs extends LogsEXT {
  late Uri uri;
  late String service;
  late Environment env;
  late Severity logLevel;
  late String logAPIToken;
  List<Map<String, String>> logs = [];
  Timer? _publishTimer;
  String Function()? _callback;
  final Dio _dio = Dio();

  ApplicationLogs(
    this.uri,
    this.env,
    this.service,
    this.logLevel,
    this.logAPIToken,
  );

  void registerUserIdCallback(String Function() cb) {
    _callback = cb;
  }

  void log(Severity severity, String message, Map<String, String>? extra) {
    var userId = "";

    if (_callback != null) {
      userId = _callback!();
    }

    var timestamp = DateTime.now().toUtc().toIso8601String();

    final Map<String, String> logPayload = {
      "timestamp": timestamp,
      "service": service,
      "environment": env.toString(),
      "severity": severity.toString(),
      "userId": userId,
      "message": message,
    };

    if (extra != null) {
      extra.forEach((k, v) => logPayload[k] = v);
    }

    // log the messages to the console for dev environment
    if (env == Environment.dev) {
      prettyPrint(
        severity: severity,
        message: message,
        serviceName: service,
        timestamp: timestamp,
        extra: extra ?? <String, String>{},
      );
      return;
    }

    logs.add(logPayload);

    if (_publishTimer != null) {
      _publishTimer!.cancel();
    }

    if (logs.length == batchToFlush) {
      publish();
    } else {
      _publishTimer = Timer(Duration(seconds: maxWaitInSeconds), () {
        publish();
      });
    }
  }

  void prettyPrint({
    required Severity severity,
    required String message,
    required String serviceName,
    required String timestamp,
    String? userId,
    required Map<String, String> extra,
  }) {
    final blue = AnsiPen()..blue();
    final green = AnsiPen()..green();
    final yellow = AnsiPen()..yellow();
    final red = AnsiPen()..red();
    final brightRed = AnsiPen()..red(bold: true);
    final dim = AnsiPen()..gray(level: 0.5);
    final italic = (String text) => '\x1B[3m$text\x1B[0m';
    final bold = (String text) => '\x1B[1m$text\x1B[0m';
    final magenta = AnsiPen()..magenta();
    final black = AnsiPen()..black();

    String severityStr = severity.name.toUpperCase();
    String coloredSeverity;
    switch (severity) {
      case Severity.debug:
        coloredSeverity = blue(severityStr);
        break;
      case Severity.info:
        coloredSeverity = green(severityStr);
        break;
      case Severity.warn:
        coloredSeverity = yellow(severityStr);
        break;
      case Severity.error:
        coloredSeverity = red(severityStr);
        break;
      case Severity.critical:
        coloredSeverity = brightRed(severityStr);
        break;
    }

    final formattedTimestamp = dim(italic(timestamp));
    final formattedService = dim(italic(serviceName));
    final formattedMessage = black(message);

    final metadata = extra.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(' | ');
    final metadataStr = metadata.isNotEmpty ? ' | $metadata' : '';

    if (userId != null) {
      print(
        '[$formattedTimestamp ${bold(coloredSeverity)} $formattedService] $formattedMessage | User ID: ${magenta(userId)}$metadataStr',
      );
    } else {
      print(
        '[$formattedTimestamp ${bold(coloredSeverity)} $formattedService] $formattedMessage$metadataStr',
      );
    }
  }

  void publish() async {
    try {
      _dio.options.headers['Content-Type'] = 'application/json';
      _dio.options.headers['X-API-Token'] = logAPIToken;

      var _ = await _dio.post(uri.toString(), data: jsonEncode(logs));

      logs.clear();
    } catch (e) {
      print("Error publishing logs: $e");
    }
  }

  @override
  void critical(String message, {Map<String, String>? extra}) {
    if (levelsRanking(Severity.critical) < levelsRanking(logLevel)) {
      return;
    }

    log(Severity.critical, message, extra);
  }

  @override
  void debug(String message, {Map<String, String>? extra}) {
    if (levelsRanking(Severity.debug) < levelsRanking(logLevel)) {
      return;
    }

    log(Severity.debug, message, extra);
  }

  @override
  void error(String message, {Map<String, String>? extra}) {
    if (levelsRanking(Severity.error) < levelsRanking(logLevel)) {
      return;
    }

    log(Severity.error, message, extra);
  }

  @override
  void info(String message, {Map<String, String>? extra}) {
    if (levelsRanking(Severity.info) < levelsRanking(logLevel)) {
      return;
    }

    log(Severity.info, message, extra);
  }

  @override
  void warn(String message, {Map<String, String>? extra}) {
    if (levelsRanking(Severity.warn) < levelsRanking(logLevel)) {
      return;
    }

    log(Severity.warn, message, extra);
  }

  int levelsRanking(Severity s) {
    switch (s) {
      case Severity.debug:
        return 0;
      case Severity.info:
        return 1;
      case Severity.warn:
        return 2;
      case Severity.error:
        return 3;
      case Severity.critical:
        return 4;
    }
  }
}
