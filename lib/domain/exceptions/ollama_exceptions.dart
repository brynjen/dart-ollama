/// Exception thrown when trying to use thinking on a model that doesn't support it
class ThinkingNotAllowed implements Exception {
  final String message;
  final String model;
  
  const ThinkingNotAllowed(this.model, this.message);
  
  @override
  String toString() => 'ThinkingNotAllowed: $message';
}

/// Exception thrown when trying to use tools on a model that doesn't support them  
class ToolsNotAllowed implements Exception {
  final String message;
  final String model;
  
  const ToolsNotAllowed(this.model, this.message);
  
  @override
  String toString() => 'ToolsNotAllowed: $message';
} 