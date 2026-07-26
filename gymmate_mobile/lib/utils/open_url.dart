import 'open_url_stub.dart'
    if (dart.library.html) 'open_url_web.dart'
    if (dart.library.io) 'open_url_io.dart'
    as impl;

/// Opens [url] in a new browser tab (web) so the user can view/print/save it
/// (e.g. a receipt page). No-op where not supported.
void openUrlInNewTab(String url) {
  impl.openUrlInNewTabImpl(url);
}
