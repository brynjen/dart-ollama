
import 'dart:async';

class GPTStreamDecoder {
  static StreamTransformer<String, String> get decoder {
    return StreamTransformer<String, String>.fromHandlers(
      handleData: (chunk, sink) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data:')) {
            final content = line.substring(5).trim();
            if (content == '[DONE]') {
              sink.add('[DONE]');
              continue;
            }
            sink.add(content);
          }
        }
      },
      handleDone: (sink) => sink.close(),
    );
  }
}
