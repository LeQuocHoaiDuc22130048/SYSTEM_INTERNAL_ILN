import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_banner.dart';
import '../theme/app_motion.dart';
import 'banner_canvas.dart';
import 'smooth_banner_physics.dart';

/// Shared 2:1 promotional banner carousel rendered from Banner Management data.
class AppBannerCarousel extends StatefulWidget {
  const AppBannerCarousel({
    super.key,
    required this.banners,
    required this.baseUrl,
    this.showLoadingPlaceholder = false,
    this.horizontalPadding = 6,
    this.onActionTap,
  });

  final List<AppBanner> banners;
  final String baseUrl;
  final bool showLoadingPlaceholder;
  final double horizontalPadding;
  final Future<void> Function(AppBannerButton button)? onActionTap;

  @override
  State<AppBannerCarousel> createState() => _AppBannerCarouselState();
}

class _AppBannerCarouselState extends State<AppBannerCarousel>
    with WidgetsBindingObserver {
  static const int _kInitialVirtualPage = 10080;

  late final PageController _bannerController;
  int _currentBannerIndex = 0;
  Timer? _bannerAutoPlayTimer;
  int _lastAutoPlayBannerCount = 0;

  static int _toRealBannerIndex(int index, int length) {
    if (length <= 0) return 0;
    final mod = index % length;
    return mod < 0 ? mod + length : mod;
  }

  List<AppBanner> get _effectiveBanners =>
      widget.banners.isNotEmpty ? widget.banners : const [AppBanner.defaultBanner];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerController = PageController(initialPage: _kInitialVirtualPage);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopBannerAutoPlay();
    } else if (mounted) {
      _startBannerAutoPlay(_effectiveBanners.length);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopBannerAutoPlay();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoPlay(int bannerCount) {
    _stopBannerAutoPlay();
    if (bannerCount <= 1) return;
    _bannerAutoPlayTimer = Timer.periodic(AppMotion.bannerHold, (_) {
      if (!mounted ||
          !_bannerController.hasClients ||
          _bannerController.positions.length != 1) {
        return;
      }
      if (_bannerController.position.isScrollingNotifier.value ||
          MediaQuery.disableAnimationsOf(context)) {
        return;
      }
      final currentPage =
          _bannerController.page?.round() ?? _kInitialVirtualPage;
      _bannerController.animateToPage(
        currentPage + 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.banner,
        curve: AppMotion.curve,
      );
    });
  }

  void _stopBannerAutoPlay() {
    _bannerAutoPlayTimer?.cancel();
    _bannerAutoPlayTimer = null;
  }

  void _syncBannerAutoPlay(int bannerCount) {
    if (bannerCount <= 1) {
      _stopBannerAutoPlay();
      _lastAutoPlayBannerCount = bannerCount;
      return;
    }
    if (_bannerAutoPlayTimer == null ||
        _lastAutoPlayBannerCount != bannerCount) {
      _lastAutoPlayBannerCount = bannerCount;
      _startBannerAutoPlay(bannerCount);
    }
  }

  void _animateToBannerIndex(int targetBannerIndex, int totalCount) {
    if (!_bannerController.hasClients || totalCount <= 1) return;
    _stopBannerAutoPlay();
    final currentPage = _bannerController.page?.round() ?? _kInitialVirtualPage;
    final currentModulo = _toRealBannerIndex(currentPage, totalCount);
    final forwardDelta = (targetBannerIndex - currentModulo) % totalCount;
    final backwardDelta = (currentModulo - targetBannerIndex) % totalCount;
    final targetPage = forwardDelta <= backwardDelta
        ? currentPage + forwardDelta
        : currentPage - backwardDelta;

    _bannerController.animateToPage(
      targetPage,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.banner,
      curve: AppMotion.curve,
    );
    _startBannerAutoPlay(totalCount);
  }

  Future<void> _handleButtonAction(AppBannerButton btn) async {
    if (btn.actionType == 'LINK' || btn.actionType == 'CALL') {
      final rawTarget = (btn.actionValue ?? '').trim();
      final target = btn.actionType == 'CALL'
          ? rawTarget
                .replaceFirst(RegExp(r'^tel:', caseSensitive: false), '')
                .replaceAll(RegExp(r'[\s().-]'), '')
          : rawTarget;
      if (btn.actionType == 'CALL' &&
          !RegExp(r'^\+?[0-9]{3,15}$').hasMatch(target)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Số điện thoại của banner không hợp lệ.'),
            ),
          );
        }
        return;
      }
      final uri = btn.actionType == 'CALL'
          ? Uri(scheme: 'tel', path: target)
          : Uri.tryParse(target);
      if (target.isEmpty ||
          uri == null ||
          (btn.actionType == 'LINK' &&
              (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty))) {
        return;
      }
      try {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                btn.actionType == 'CALL'
                    ? 'Không thể mở ứng dụng Điện thoại.'
                    : 'Không thể mở liên kết này.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                btn.actionType == 'CALL'
                    ? 'Không thể mở ứng dụng Điện thoại.'
                    : 'Không thể mở liên kết này.',
              ),
            ),
          );
        }
      }
      return;
    }

    if (widget.onActionTap != null) {
      await widget.onActionTap!(btn);
    }
  }

  void _handleBannerTap(AppBanner banner) {
    _handleButtonAction(
      AppBannerButton(
        text: banner.buttonText ?? '',
        actionType: banner.actionType,
        actionValue: banner.actionValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banners = _effectiveBanners;
    final horizontalPad = widget.horizontalPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerHeight = (constraints.maxWidth - horizontalPad * 2) / 2;
        if (widget.showLoadingPlaceholder) {
          _stopBannerAutoPlay();
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: SizedBox(
              key: const ValueKey('banner-loading'),
              height: bannerHeight,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          );
        }

        if (banners.length == 1) {
          _stopBannerAutoPlay();
          return SizedBox(
            height: bannerHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: _buildBannerCard(banners.first, 0, 1),
            ),
          );
        }

        _syncBannerAutoPlay(banners.length);

        return SizedBox(
          height: bannerHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _stopBannerAutoPlay();
              } else if (notification is ScrollEndNotification) {
                _startBannerAutoPlay(banners.length);
              }
              return false;
            },
            child: PageView.builder(
              controller: _bannerController,
              physics: const SmoothBannerPhysics(),
              clipBehavior: Clip.hardEdge,
              onPageChanged: (index) {
                setState(() {
                  _currentBannerIndex = _toRealBannerIndex(
                    index,
                    banners.length,
                  );
                });
              },
              itemBuilder: (context, index) {
                final realIndex = _toRealBannerIndex(index, banners.length);
                return Padding(
                  key: ValueKey('banner-slide-${banners[realIndex].id}'),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                  child: _buildBannerCard(
                    banners[realIndex],
                    _currentBannerIndex,
                    banners.length,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerCard(
    AppBanner banner,
    int currentIndex,
    int totalCount,
  ) {
    final design = banner.canvasDesign;
    if (design != null) {
      return BannerCanvas(
        banner: banner,
        design: design,
        baseUrl: widget.baseUrl,
        mascot: _buildBannerImage(
          banner,
          imageAlignment: Alignment.center,
        ),
        onTap: () => _handleBannerTap(banner),
        onButtonTap: _handleButtonAction,
        textStyle: (font, style) =>
            _getBannerTextStyle(fontFamily: font, baseStyle: style),
      );
    }

    return GestureDetector(
      onTap: () => _handleBannerTap(banner),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient:
              (banner.backgroundImageUrl == null ||
                  banner.backgroundImageUrl!.isEmpty)
              ? LinearGradient(
                  colors: banner.gradientColorList,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          image:
              (banner.backgroundImageUrl != null &&
                  banner.backgroundImageUrl!.isNotEmpty)
              ? DecorationImage(
                  image: NetworkImage(
                    banner.backgroundImageUrl!.startsWith('http')
                        ? banner.backgroundImageUrl!
                        : '${widget.baseUrl}${banner.backgroundImageUrl}',
                  ),
                  fit: BoxFit.cover,
                  colorFilter: banner.darkenOverlay
                      ? ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.35),
                          BlendMode.darken,
                        )
                      : null,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: banner.gradientColorList.first.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: _getBannerTextPadding(banner.imagePosition),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (banner.badgeText != null &&
                        banner.badgeText!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          banner.badgeText!,
                          style: _getBannerTextStyle(
                            fontFamily: banner.fontFamily,
                            baseStyle: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    if (banner.title.trim().isNotEmpty) ...[
                      Text(
                        banner.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _getBannerTextStyle(
                          fontFamily: banner.fontFamily,
                          baseStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.18,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                    if (banner.subtitle != null &&
                        banner.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _buildSubtitle(banner.subtitle!, banner.fontFamily),
                    ],
                    if (banner.buttons.isNotEmpty &&
                        banner.buttonPosition != 'TOP_RIGHT' &&
                        banner.buttonPosition != 'TOP_LEFT' &&
                        banner.buttonPosition != 'CUSTOM') ...[
                      const SizedBox(height: 5),
                      _buildButtonsContainer(banner),
                    ],
                  ],
                ),
              ),
            ),
            _buildCustomPositionedButtons(banner),
            _buildPositionedMascot(banner),
            Positioned(
              bottom: 5,
              left: banner.imagePosition == 'LEFT' ? null : 14,
              right: banner.imagePosition == 'LEFT' ? 14 : null,
              child: Row(
                children: List.generate(totalCount > 1 ? totalCount : 3, (
                  dotIdx,
                ) {
                  final isDotActive = dotIdx == currentIndex;
                  return GestureDetector(
                    onTap: () {
                      if (totalCount > 1) {
                        _animateToBannerIndex(dotIdx, totalCount);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(right: 4),
                      width: isDotActive ? 14 : 4.5,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDotActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _getBannerTextStyle({
    required String? fontFamily,
    required TextStyle baseStyle,
  }) {
    if (fontFamily == null ||
        fontFamily.trim().isEmpty ||
        fontFamily == 'DEFAULT') {
      return baseStyle;
    }
    try {
      return GoogleFonts.getFont(fontFamily.trim(), textStyle: baseStyle);
    } catch (_) {
      return baseStyle;
    }
  }

  Widget _buildSubtitle(String text, [String? fontFamily]) {
    final normalized = text
        .replaceAll(
          RegExp(r'^(Địa chỉ|Đ/c|Address)\s*:\s*', caseSensitive: false),
          '',
        )
        .replaceAll('\n', ' • ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final baseStyle = _getBannerTextStyle(
      fontFamily: fontFamily,
      baseStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.96),
        height: 1.2,
        shadows: const [
          Shadow(color: Color(0xB3000000), blurRadius: 5, offset: Offset(0, 1)),
        ],
      ),
    );
    final highlightStyle = _getBannerTextStyle(
      fontFamily: fontFamily,
      baseStyle: const TextStyle(
        fontSize: 10,
        color: Color(0xFFFDE047),
        fontWeight: FontWeight.bold,
        height: 1.2,
        shadows: [
          Shadow(color: Color(0xB3000000), blurRadius: 5, offset: Offset(0, 1)),
        ],
      ),
    );

    if (normalized.contains('25% GIÁ TRỊ')) {
      final parts = normalized.split('25% GIÁ TRỊ');
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: parts.first),
            TextSpan(text: '25% GIÁ TRỊ', style: highlightStyle),
            if (parts.length > 1)
              TextSpan(text: parts.sublist(1).join('25% GIÁ TRỊ')),
          ],
        ),
      );
    }
    return Text(
      normalized,
      style: baseStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  EdgeInsets _getBannerTextPadding(String imagePosition) {
    switch (imagePosition) {
      case 'LEFT':
        return const EdgeInsets.fromLTRB(104, 8, 14, 10);
      case 'RIGHT_TOP':
        return const EdgeInsets.fromLTRB(14, 8, 76, 10);
      case 'NONE':
        return const EdgeInsets.fromLTRB(14, 8, 14, 10);
      case 'RIGHT':
      default:
        return const EdgeInsets.fromLTRB(14, 8, 98, 10);
    }
  }

  Widget _buildPositionedMascot(AppBanner banner) {
    if (banner.imagePosition == 'NONE' || banner.imagePosition == 'EMPTY') {
      return const SizedBox.shrink();
    }
    if (banner.imagePosition == 'LEFT') {
      return Positioned(
        left: 0,
        bottom: 0,
        top: 0,
        width: 104,
        child: _buildBannerImage(banner),
      );
    }
    if (banner.imagePosition == 'RIGHT_TOP') {
      return Positioned(
        right: 8,
        top: 4,
        width: 60,
        height: 60,
        child: _buildBannerImage(banner),
      );
    }
    return Positioned(
      right: 0,
      bottom: 0,
      top: 0,
      width: 112,
      child: _buildBannerImage(banner),
    );
  }

  Widget _buildBannerImage(
    AppBanner banner, {
    Alignment? imageAlignment,
  }) {
    final imgUrl = banner.imageUrl;
    final alignment =
        imageAlignment ??
        (banner.imagePosition == 'LEFT'
            ? Alignment.bottomLeft
            : Alignment.bottomRight);
    if (imgUrl != null && imgUrl.isNotEmpty) {
      final fullUrl = imgUrl.startsWith('http')
          ? imgUrl
          : '${widget.baseUrl}$imgUrl';
      return Image.network(
        fullUrl,
        fit: BoxFit.contain,
        alignment: alignment,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/image_character.png',
          fit: BoxFit.contain,
          alignment: alignment,
        ),
      );
    }
    return Image.asset(
      'assets/images/image_character.png',
      fit: BoxFit.contain,
      alignment: alignment,
    );
  }

  Widget _buildButtonsContainer(AppBanner banner) {
    final pos = banner.buttonPosition;
    final buttonsWidget = _buildBannerButtons(banner);

    if (pos == 'BOTTOM_CENTER') {
      return Center(child: buttonsWidget);
    } else if (pos == 'BOTTOM_RIGHT') {
      return Align(alignment: Alignment.centerRight, child: buttonsWidget);
    }
    return Align(alignment: Alignment.centerLeft, child: buttonsWidget);
  }

  Widget _buildCustomPositionedButtons(AppBanner banner) {
    if (banner.buttons.isEmpty) return const SizedBox.shrink();

    if (banner.buttonPosition == 'CUSTOM') {
      return Positioned(
        top: banner.buttonTop,
        bottom: banner.buttonBottom,
        left: banner.buttonLeft,
        right: banner.buttonRight,
        child: _buildBannerButtons(banner),
      );
    }

    if (banner.buttonPosition == 'TOP_RIGHT') {
      return Positioned(
        top: banner.buttonTop ?? 14,
        right: banner.buttonRight ?? 14,
        bottom: banner.buttonBottom,
        left: banner.buttonLeft,
        child: _buildBannerButtons(banner),
      );
    }

    if (banner.buttonPosition == 'TOP_LEFT') {
      return Positioned(
        top: banner.buttonTop ?? 14,
        left: banner.buttonLeft ?? 18,
        bottom: banner.buttonBottom,
        right: banner.buttonRight,
        child: _buildBannerButtons(banner),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBannerButtons(AppBanner banner) {
    if (banner.buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    final brandColor = banner.gradientColorList.length > 2
        ? banner.gradientColorList[2]
        : const Color(0xFF1D4ED8);

    final buttonWidgets = banner.buttons.map((btn) {
      final isSecondary = btn.styleType == 'SECONDARY';
      final isOutline = btn.styleType == 'OUTLINE';

      if (isSecondary) {
        return OutlinedButton(
          onPressed: () => _handleButtonAction(btn),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  btn.text,
                  style: _getBannerTextStyle(
                    fontFamily: banner.fontFamily,
                    baseStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                btn.actionType == 'CALL'
                    ? LucideIcons.phone
                    : LucideIcons.arrowRight,
                size: 11,
              ),
            ],
          ),
        );
      }

      if (isOutline) {
        return OutlinedButton(
          onPressed: () => _handleButtonAction(btn),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: Colors.white, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  btn.text,
                  style: _getBannerTextStyle(
                    fontFamily: banner.fontFamily,
                    baseStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                btn.actionType == 'CALL'
                    ? LucideIcons.phone
                    : LucideIcons.arrowRight,
                size: 11,
              ),
            ],
          ),
        );
      }

      return ElevatedButton(
        onPressed: () => _handleButtonAction(btn),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: brandColor,
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                btn.text,
                style: _getBannerTextStyle(
                  fontFamily: banner.fontFamily,
                  baseStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              btn.actionType == 'CALL'
                  ? LucideIcons.phone
                  : LucideIcons.arrowRight,
              size: 12,
            ),
          ],
        ),
      );
    }).toList();

    return Wrap(spacing: 8, runSpacing: 6, children: buttonWidgets);
  }
}
