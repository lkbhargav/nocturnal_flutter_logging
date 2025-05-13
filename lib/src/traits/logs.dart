enum Severity {
  debug,
  info,
  warn,
  error,
  critical;

  @override
  String toString() {
    return name;
  }

  static Severity fromString(String env) {
    switch (env) {
      case "info":
        return Severity.info;
      case "warn":
        return Severity.warn;
      case "error":
        return Severity.error;
      case "critical":
        return Severity.critical;
      default:
        return Severity.debug;
    }
  }
}

enum Environment {
  dev,
  stage,
  prod,
  research;

  @override
  String toString() {
    return name;
  }

  static Environment fromString(String env) {
    switch (env) {
      case "stage":
        return Environment.stage;
      case "prod":
        return Environment.prod;
      case "research":
        return Environment.research;
      default:
        return Environment.dev;
    }
  }
}

abstract class LogsEXT {
  void debug(String message, {Map<String, String> extra});
  void info(String message, {Map<String, String> extra});
  void warn(String message, {Map<String, String> extra});
  void error(String message, {Map<String, String> extra});
  void critical(String message, {Map<String, String> extra});
}
