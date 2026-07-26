import 'dart:html' as html;

void openUrlInNewTabImpl(String url) {
  html.window.open(url, '_blank');
}
