import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'theme_manager.dart'; // Theme manager import করুন

class BookPreviewScreen extends StatefulWidget {
  final String url;
  final String title;

  const BookPreviewScreen({super.key, required this.url, required this.title});

  @override
  State<BookPreviewScreen> createState() => _BookPreviewScreenState();
}

class _BookPreviewScreenState extends State<BookPreviewScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeWebViewController();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  void _initializeWebViewController() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // You can use progress for a progress bar if needed
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              hasError = false;
              errorMessage = '';
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              isLoading = false;
              hasError = true;
              errorMessage = 'Failed to load the book preview: ${error.description}';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _reloadPage() {
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });
    controller.reload();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _currentTheme.primary,
        foregroundColor: Colors.black,
        elevation: 2,
        shadowColor: _currentTheme.primary.withOpacity(0.5),
        actions: [
          // Reload Button
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Colors.black,
            ),
            onPressed: _reloadPage,
            tooltip: 'Reload',
          ),
          // Close Button
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.black,
            ),
            onPressed: _goBack,
            tooltip: 'Close',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_currentTheme.gradientStart, _currentTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // WebView Content
            if (!hasError)
              WebViewWidget(controller: controller)
            else
              _buildErrorState(),

            // Loading Indicator
            if (isLoading)
              Container(
                color: _currentTheme.containerColor.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: _currentTheme.primary,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading Book Preview...',
                        style: TextStyle(
                          fontSize: 16,
                          color: _currentTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error State
            if (hasError && !isLoading)
              Container(
                color: _currentTheme.containerColor,
                child: _buildErrorState(),
              ),
          ],
        ),
      ),
      // Bottom Navigation for additional controls
      bottomNavigationBar: isLoading || hasError
          ? null
          : Container(
              height: 50,
              decoration: BoxDecoration(
                color: _currentTheme.primary,
                border: Border(
                  top: BorderSide(
                    color: _currentTheme.primary,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Back button for web navigation
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () async {
                      if (await controller.canGoBack()) {
                        await controller.goBack();
                      }
                    },
                    tooltip: 'Go Back',
                  ),
                  // Forward button for web navigation
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () async {
                      if (await controller.canGoForward()) {
                        await controller.goForward();
                      }
                    },
                    tooltip: 'Go Forward',
                  ),
                  // Reload button
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: _reloadPage,
                    tooltip: 'Reload',
                  ),
                  // Share button (optional)
                  IconButton(
                    icon: Icon(
                      Icons.share,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () {
                      // Implement share functionality
                      _showShareOptions();
                    },
                    tooltip: 'Share',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: _currentTheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Preview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _currentTheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage.isNotEmpty 
                  ? errorMessage 
                  : 'There was a problem loading the book preview.',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Retry Button
                ElevatedButton(
                  onPressed: _reloadPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Close Button
                OutlinedButton(
                  onPressed: _goBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _currentTheme.primary,
                    side: BorderSide(
                      color: _currentTheme.primary,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Additional Help Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _currentTheme.containerColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _currentTheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Check your internet connection and try again',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _currentTheme.containerColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Book Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _currentTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.link,
                  color: _currentTheme.primary,
                ),
                title: const Text('Copy Link'),
                onTap: () {
                  Navigator.pop(context);
                  _copyToClipboard();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.open_in_browser,
                  color: _currentTheme.primary,
                ),
                title: const Text('Open in Browser'),
                onTap: () {
                  Navigator.pop(context);
                  _openInBrowser();
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _currentTheme.primary,
                  side: BorderSide(color: _currentTheme.primary),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyToClipboard() {
    // Implement copy to clipboard functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied to clipboard'),
        backgroundColor: _currentTheme.primary,
      ),
    );
  }

  void _openInBrowser() {
    // Implement open in browser functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Opening in browser...'),
        backgroundColor: _currentTheme.primary,
      ),
    );
  }
}