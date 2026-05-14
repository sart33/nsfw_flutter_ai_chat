import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ChatImageFullscreenScreen extends StatefulWidget {
  final List<ImageProvider> imageProviders;
  final int initialIndex;        // index of the tapped image

  const ChatImageFullscreenScreen({
    super.key,
    required this.imageProviders,
    required this.initialIndex,

  });

  @override
  _ChatImageFullscreenScreenState createState() =>
      _ChatImageFullscreenScreenState();
}

class _ChatImageFullscreenScreenState
    extends State<ChatImageFullscreenScreen> {
  late PageController _pageCtrl;
  late int _currentIndex;


  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (widget.imageProviders.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final safeIdx = _currentIndex.clamp(0, widget.imageProviders.length - 1);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView with PhotoView
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.imageProviders.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, index) {
              return PhotoView(
                imageProvider: widget.imageProviders[index],
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.5,
                backgroundDecoration:
                const BoxDecoration(color: Colors.black),
                filterQuality: FilterQuality.medium, // <-- добавить

              );
            },
          ),
          // Desktop-only navigation arrows
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
            // LEFT
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 80,
              child: GestureDetector(
                onTap: () {
                  if (_currentIndex > 0) {
                    _pageCtrl.animateToPage(
                      _currentIndex - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  child: _currentIndex > 0
                      ? const Center(
                      child: Icon(Icons.chevron_left,
                          color: Colors.white70, size: 48))
                      : null,
                ),
              ),
            ),
            // RIGHT
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 80,
              child: GestureDetector(
                onTap: () {
                  if (_currentIndex < widget.imageProviders.length - 1) {
                    _pageCtrl.animateToPage(
                      _currentIndex + 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  color: Colors.transparent,
                  child: _currentIndex < widget.imageProviders.length - 1
                      ? const Center(
                      child: Icon(Icons.chevron_right,
                          color: Colors.white70, size: 48))
                      : null,
                ),
              ),
            ),
          ],
          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      '${safeIdx + 1} / ${widget.imageProviders.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



}


