import 'dart:async';
import 'dart:convert';

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

    final Map<String, String> logPayload = {
      "timestamp": DateTime.now().toIso8601String(),
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
      print(logPayload);
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
