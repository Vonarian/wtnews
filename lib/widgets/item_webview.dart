import 'package:fluent_ui/fluent_ui.dart';
import 'package:webview_windows/webview_windows.dart';

class ItemWebView extends StatefulWidget {
  final String url;

  const ItemWebView({Key? key, required this.url}) : super(key: key);

  @override
  State<ItemWebView> createState() => _ItemWebViewState();
}

class _ItemWebViewState extends State<ItemWebView> {
  final _controller = WebviewController();

  Future<void> initPlatformState() async {
    await _controller.initialize();
    await _controller.setBackgroundColor(Colors.transparent);
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    await _controller.loadUrl(widget.url);

    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget compositeView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
              child: Card(
                  child: Stack(
            children: [
              Webview(
                _controller,
                permissionRequested: (url, kind, isUserInitiated) =>
                    _onPermissionRequested(url, kind, isUserInitiated, context),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: StreamBuilder<LoadingState>(
                    stream: _controller.loadingState,
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.data == LoadingState.loading) {
                        return const ProgressRing(
                          strokeWidth: 1,
                        );
                      } else {
                        return const SizedBox();
                      }
                    }),
              ),
            ],
          ))),
        ],
      ),
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url,
      WebviewPermissionKind kind,
      bool isUserInitiated,
      BuildContext context) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: context,
      builder: (BuildContext context) => ContentDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? compositeView(context)
        : const SizedBox();
  }
}
