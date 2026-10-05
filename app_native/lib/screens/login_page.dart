import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app/app_routes.dart';
import '../theme/app_colors.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../utils/network_provider.dart';
import 'privacy_policy_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _showPassword = false;
  bool _isLogin = true;
  String _error = '';
  bool _loading = false;
  bool _checkingAutoLogin = true;
  bool _showAuthModal = false;

  void _openAuthModal({required bool isLogin}) {
    setState(() {
      _isLogin = isLogin;
      _showAuthModal = true;
      _error = '';
    });
  }

  void _closeAuthModal() {
    setState(() {
      _showAuthModal = false;
      _error = '';
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoLogin();
    });
  }

  Future<void> _checkAutoLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.tryAutoLogin();
    if (!mounted) return;

    if (success) {
      if (!auth.isAttendanceAccount) {
        context.read<BackendDataProvider>().loadAll(
          isManagerOrAbove: auth.isManagerOrAbove,
        );
      }
      final targetRoute = auth.isAttendanceAccount
          ? AppRoutes.dashboard
          : AppRoutes.home;
      Navigator.of(context).pushReplacementNamed(targetRoute);
    } else {
      setState(() {
        _checkingAutoLogin = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _error = '';
    });

    if (_usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _fullNameController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      setState(() {
        _error = 'Vui lòng điền đầy đủ thông tin.';
      });
      return;
    }

    final strongPassword = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$',
    ).hasMatch(_passwordController.text);
    if (!strongPassword) {
      setState(() {
        _error =
            'Mật khẩu cần tối thiểu 8 ký tự, có chữ hoa, chữ thường và số.';
      });
      return;
    }

    final hasInternet = await Provider.of<NetworkProvider>(
      context,
      listen: false,
    ).checkNow();
    if (!hasInternet) {
      setState(() {
        _error = 'Thiết bị đang mất kết nối internet. Vui lòng kiểm tra mạng.';
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await auth.register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        department: 'Nhân viên',
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _isLogin = true;
        _error = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đăng ký thành công! Vui lòng chờ duyệt trước khi đăng nhập.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      debugPrint('[AUTH] Register unexpected error: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = kDebugMode
            ? error.toString()
            : 'Không thể đăng ký. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _handleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _error = '';
    });

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = 'Vui lòng điền đầy đủ thông tin.';
      });
      return;
    }

    final hasInternet = await Provider.of<NetworkProvider>(
      context,
      listen: false,
    ).checkNow();
    if (!hasInternet) {
      setState(() {
        _error = 'Thiết bị đang mất kết nối internet. Vui lòng kiểm tra mạng.';
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await auth.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _loading = false);
      if (!auth.isAttendanceAccount) {
        context.read<BackendDataProvider>().loadAll(
          isManagerOrAbove: auth.isManagerOrAbove,
        );
      }
      final targetRoute = auth.isAttendanceAccount
          ? AppRoutes.dashboard
          : AppRoutes.home;
      Navigator.of(context).pushReplacementNamed(targetRoute);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      debugPrint('[AUTH] Login unexpected error: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = kDebugMode
            ? error.toString()
            : 'Không thể đăng nhập. Vui lòng thử lại.';
      });
    }
  }

  Future<String?> _resetPassword({
    required String username,
    required String phone,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await Provider.of<AuthProvider>(context, listen: false).forgotPassword(
        username: username,
        phone: phone,
        otp: otp,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Không thể đặt lại mật khẩu. Vui lòng thử lại.';
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final pageContext = context;
    final usernameController = TextEditingController(
      text: _usernameController.text,
    );
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    bool loading = false;
    bool otpRequested = false;
    String error = '';

    await showDialog<void>(
      context: context,
      barrierDismissible: !loading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            Future<void> submit() async {
              final dialogNavigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(pageContext);
              final auth = Provider.of<AuthProvider>(
                dialogContext,
                listen: false,
              );

              setDialogState(() => error = '');

              if (usernameController.text.trim().isEmpty ||
                  phoneController.text.trim().isEmpty) {
                setDialogState(() {
                  error = 'Vui lòng điền đầy đủ thông tin.';
                });
                return;
              }

              final hasInternet = await Provider.of<NetworkProvider>(
                dialogContext,
                listen: false,
              ).checkNow();
              if (!hasInternet) {
                setDialogState(() {
                  error =
                      'Thiết bị đang mất kết nối internet. Vui lòng kiểm tra mạng.';
                });
                return;
              }

              if (!otpRequested) {
                setDialogState(() => loading = true);
                try {
                  await auth.requestPasswordResetOtp(
                    username: usernameController.text.trim(),
                    phone: phoneController.text.trim(),
                  );
                  setDialogState(() {
                    loading = false;
                    otpRequested = true;
                  });
                } on ApiException catch (requestError) {
                  setDialogState(() {
                    loading = false;
                    error = requestError.message;
                  });
                } catch (_) {
                  setDialogState(() {
                    loading = false;
                    error = 'Không thể gửi mã OTP. Vui lòng thử lại.';
                  });
                }
                return;
              }

              if (otpController.text.trim().isEmpty ||
                  newPasswordController.text.isEmpty ||
                  confirmPasswordController.text.isEmpty) {
                setDialogState(() {
                  error = 'Vui lòng nhập mã OTP và mật khẩu mới.';
                });
                return;
              }

              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                setDialogState(() {
                  error = 'Mật khẩu xác nhận không khớp.';
                });
                return;
              }

              if (newPasswordController.text.length < 8) {
                setDialogState(() {
                  error = 'Mật khẩu mới phải có ít nhất 8 ký tự.';
                });
                return;
              }

              final strongPassword = RegExp(
                r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$',
              ).hasMatch(newPasswordController.text);
              if (!strongPassword) {
                setDialogState(() {
                  error = 'Mật khẩu mới cần có chữ hoa, chữ thường và số.';
                });
                return;
              }

              setDialogState(() => loading = true);
              final resetError = await _resetPassword(
                username: usernameController.text.trim(),
                phone: phoneController.text.trim(),
                otp: otpController.text.trim(),
                newPassword: newPasswordController.text,
                confirmPassword: confirmPasswordController.text,
              );
              setDialogState(() => loading = false);

              if (!mounted) return;
              if (resetError != null) {
                setDialogState(() => error = resetError);
                return;
              }

              dialogNavigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đặt lại mật khẩu thành công. Vui lòng đăng nhập.',
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              title: const Text(
                'Quên mật khẩu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInputField(
                      label: 'Tên đăng nhập',
                      hint: 'Nhập username...',
                      controller: usernameController,
                      icon: LucideIcons.user,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Số điện thoại đã đăng ký',
                      hint: 'Nhập số điện thoại...',
                      controller: phoneController,
                      icon: LucideIcons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    if (otpRequested) ...[
                      const SizedBox(height: 16),
                      _buildInputField(
                        label: 'Mã OTP',
                        hint: 'Nhập mã OTP...',
                        controller: otpController,
                        icon: LucideIcons.shieldCheck,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        label: 'Mật khẩu mới',
                        hint: 'Nhập mật khẩu mới...',
                        controller: newPasswordController,
                        icon: LucideIcons.lock,
                        isPassword: true,
                        obscurePassword: !showNewPassword,
                        onTogglePassword: () => setDialogState(
                          () => showNewPassword = !showNewPassword,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        label: 'Xác nhận mật khẩu',
                        hint: 'Nhập lại mật khẩu mới...',
                        controller: confirmPasswordController,
                        icon: LucideIcons.lockKeyhole,
                        isPassword: true,
                        obscurePassword: !showConfirmPassword,
                        onTogglePassword: () => setDialogState(
                          () => showConfirmPassword = !showConfirmPassword,
                        ),
                      ),
                    ],
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        error,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          FocusScope.of(dialogContext).unfocus();
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: loading ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(otpRequested ? 'Đặt lại mật khẩu' : 'Gửi mã OTP'),
                ),
              ],
            );
          },
        );
      },
    );

    // Delay controller disposal to prevent text fields from accessing disposed controllers during transition
    Future.delayed(const Duration(milliseconds: 500), () {
      usernameController.dispose();
      phoneController.dispose();
      otpController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAutoLogin) {
      return const Scaffold(
        body: Stack(
          children: [
            LoginBackground(),
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !_showAuthModal,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showAuthModal) {
          _closeAuthModal();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const LoginBackground(),
            Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: true,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final availableHeight = constraints.maxHeight;

                    final isDesktop = width >= 1024;
                    final isTablet = width >= 640 && width < 1024;
                    final isMobile = width < 640;
                    final isShort = availableHeight < 620;

                    // Determine branding scale (prominent hero logo)
                    double brandingScale = 1.0;
                    if (isMobile) {
                      brandingScale = isShort ? 0.75 : 1.0;
                    } else if (isTablet) {
                      brandingScale = 1.15;
                    }

                    if (isDesktop) {
                      return _buildDesktopLayout(
                        availableHeight: availableHeight,
                      );
                    }

                    return _buildMobileLayout(
                      availableHeight: availableHeight,
                      brandingScale: brandingScale,
                      isShort: isShort,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingSection({
    required double scale,
    required bool isMobile,
    bool isShort = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand Wordmark Pill with Live Status Indicator (Stitch style)
        Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SYSTEM INVERTER LIKENEW',
                    style: TextStyle(
                      fontSize: isMobile ? 13.5 : 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1.25, 1.25),
                        duration: 900.ms,
                      )
                      .fade(begin: 0.5, end: 1.0, duration: 900.ms),
                ],
              ),
            )
            .animate(target: 1)
            .fadeIn(duration: 500.ms)
            .slideY(begin: -0.3, end: 0, duration: 500.ms),

        SizedBox(height: isShort ? 10 : 20 * scale),

        // Hero Stage with 3D Logo Levitation, Breathing Halo Glow and Floating Badges
        SizedBox(
          width: 320 * scale,
          height: 280 * scale,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Breathing glowing halo behind the logo (matching Stitch @keyframes logoGlow)
              Container(
                    width: 220 * scale,
                    height: 220 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF38BDF8).withValues(alpha: 0.50),
                          const Color(0xFF2563EB).withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00F2FE,
                          ).withValues(alpha: 0.40),
                          blurRadius: 55 * scale,
                          spreadRadius: 20 * scale,
                        ),
                      ],
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1.10, 1.10),
                    duration: 2500.ms,
                    curve: Curves.easeInOut,
                  )
                  .fade(
                    begin: 0.40,
                    end: 0.85,
                    duration: 2500.ms,
                    curve: Curves.easeInOut,
                  ),

              // 3D Logo with levitation & subtle tilt (matching Stitch @keyframes logoLevitate)
              SizedBox(
                    width: 270 * scale,
                    height: 270 * scale,
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.contain,
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .moveY(
                    begin: 0,
                    end: -8 * scale,
                    duration: 2200.ms,
                    curve: Curves.easeInOut,
                  )
                  .rotate(
                    begin: 0,
                    end: 0.012,
                    duration: 2200.ms,
                    curve: Curves.easeInOut,
                  ),

              if (!isShort) ...[
                // Floating Badge 1 (Top-Right): 100% Bảo mật (matching Stitch badgeFloatA)
                Positioned(
                  top: -4 * scale,
                  right: -10 * scale,
                  child:
                      _buildFloatingBadge(
                            icon: LucideIcons.shieldCheck,
                            iconColor: const Color(0xFF2563EB),
                            iconBg: const Color(0xFFDBEAFE),
                            text: '100% Bảo mật',
                            scale: scale,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(
                            begin: 0,
                            end: -6 * scale,
                            duration: 2400.ms,
                            curve: Curves.easeInOut,
                          )
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(1.03, 1.03),
                            duration: 2400.ms,
                            curve: Curves.easeInOut,
                          ),
                ),

                // Floating Badge 2 (Bottom-Left): Truy cập nhanh (matching Stitch badgeFloatB)
                Positioned(
                  bottom: 4 * scale,
                  left: -14 * scale,
                  child:
                      _buildFloatingBadge(
                            icon: LucideIcons.zap,
                            iconColor: const Color(0xFFD97706),
                            iconBg: const Color(0xFFFEF3C7),
                            text: 'Truy cập nhanh',
                            scale: scale,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(
                            begin: 0,
                            end: 6 * scale,
                            duration: 2700.ms,
                            curve: Curves.easeInOut,
                          )
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(0.97, 0.97),
                            duration: 2700.ms,
                            curve: Curves.easeInOut,
                          ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingBadge({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String text,
    required double scale,
  }) {
    final effectiveScale = scale.clamp(0.75, 1.0);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * effectiveScale,
        vertical: 6 * effectiveScale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22 * effectiveScale,
            height: 22 * effectiveScale,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Center(
              child: Icon(icon, size: 13 * effectiveScale, color: iconColor),
            ),
          ),
          SizedBox(width: 6 * effectiveScale),
          Text(
            text,
            style: TextStyle(
              fontSize: 11 * effectiveScale,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout({required double availableHeight}) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: availableHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBrandingSection(scale: 1.1, isMobile: false),
                  ),
                  const SizedBox(width: 70),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AnimatedCrossFade(
                          crossFadeState: _showAuthModal
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 280),
                          firstChild: _buildDesktopWelcomeCard(),
                          secondChild: _buildDesktopFormCard(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout({
    required double availableHeight,
    required double brandingScale,
    required bool isShort,
  }) {
    final modalHeightRatio = isShort ? 0.74 : 0.70;
    const welcomeActionsHeight = 175.0;

    return Stack(
      children: [
        // Hero Logo Section: smoothly animates from full screen center to compact top frame above modal
        AnimatedPositioned(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          top: 0,
          left: 0,
          right: 0,
          bottom: _showAuthModal
              ? (availableHeight * modalHeightRatio)
              : welcomeActionsHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showAuthModal ? _closeAuthModal : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedScale(
                    scale: _showAuthModal ? 0.75 : 1.0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: _buildBrandingSection(
                      scale: brandingScale,
                      isMobile: true,
                      isShort: isShort || _showAuthModal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom Action Section with Login and Sign Up buttons (slides down & fades out when modal opens)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          left: 24,
          right: 24,
          bottom: _showAuthModal ? -220 : 16,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _showAuthModal ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: _showAuthModal,
              child: _buildWelcomeActions(isMobile: true),
            ),
          ),
        ),

        // Bottom Sheet Auth Modal (sliding from bottom, capped so logo remains visible above)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: _showAuthModal ? 0 : -availableHeight,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 240) {
                _closeAuthModal();
              }
            },
            child: _buildMobileBottomSheet(
              maxHeight: availableHeight * modalHeightRatio,
            ),
          ),
        ),
      ],
    );
  }

  // Welcome Action Section matching Stitch Start / Welcome Screen
  Widget _buildWelcomeActions({required bool isMobile}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Button: Login (White pill with blue text, Stitch style)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            key: const Key('btn-welcome-login'),
            onPressed: () => _openAuthModal(isLogin: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              elevation: 4,
              shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary Button: Sign Up (Outlined translucent pill, Stitch style)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            key: const Key('btn-welcome-register'),
            onPressed: () => _openAuthModal(isLogin: false),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Đăng ký',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Privacy Policy Link
        Center(
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
            icon: Icon(
              LucideIcons.shieldCheck,
              size: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            label: Text(
              'Chính sách bảo mật',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),

        // iOS Home Bar Indicator (Stitch style)
        Center(
          child: Container(
            width: 120,
            height: 4,
            margin: const EdgeInsets.only(top: 6, bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
                SizedBox(width: 6),
                Text(
                  'System Inverter Likenew',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Chào mừng bạn đến với hệ thống',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hệ thống quản lý dịch vụ & kho linh kiện System Inverter LikeNew. Vui lòng đăng nhập hoặc đăng ký tài khoản để tiếp tục.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          // Primary Login Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _openAuthModal(isLogin: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Đăng nhập ngay',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Secondary Sign up Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _openAuthModal(isLogin: false),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                foregroundColor: const Color(0xFF1E293B),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Đăng ký tài khoản mới',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(LucideIcons.userPlus, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                );
              },
              icon: const Icon(
                LucideIcons.shieldCheck,
                size: 14,
                color: Color(0xFF64748B),
              ),
              label: const Text(
                'Chính sách bảo mật & Điều khoản',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFormCard() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _buildAuthFormContent(isDesktop: true),
    );
  }

  Widget _buildMobileBottomSheet({required double maxHeight}) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle (Stitch style)
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
                child: _buildAuthFormContent(isDesktop: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthFormContent({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLogin ? 'Đăng nhập' : 'Đăng ký tài khoản',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLogin
                        ? 'Nhập thông tin tài khoản để tiếp tục'
                        : 'Điền thông tin để đăng ký tài khoản mới',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              key: const Key('btn-auth-close'),
              onTap: _closeAuthModal,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.x,
                  size: 18,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isLogin) ...[
                _buildInputField(
                      label: 'Họ và tên',
                      hint: 'Nhập họ và tên...',
                      controller: _fullNameController,
                      icon: LucideIcons.user,
                    )
                    .animate()
                    .fadeIn(duration: 220.ms)
                    .slideY(begin: -0.08, end: 0),
                const SizedBox(height: 16),
                _buildInputField(
                      label: 'Số điện thoại',
                      hint: 'Nhập số điện thoại...',
                      controller: _phoneController,
                      icon: LucideIcons.phone,
                      keyboardType: TextInputType.phone,
                    )
                    .animate()
                    .fadeIn(duration: 220.ms)
                    .slideY(begin: -0.08, end: 0),
                const SizedBox(height: 16),
              ],

              _buildInputField(
                label: 'Tên đăng nhập',
                hint: 'Nhập username...',
                controller: _usernameController,
                icon: LucideIcons.user,
              ),
              const SizedBox(height: 16),

              _buildInputField(
                label: 'Mật khẩu',
                hint: 'Nhập mật khẩu...',
                controller: _passwordController,
                icon: LucideIcons.lock,
                isPassword: true,
              ),
            ],
          ),
        ),

        if (_isLogin) ...[
          const SizedBox(height: 6),
          _buildForgotPasswordButton(),
        ],
        const SizedBox(height: 20),

        // Error Message
        if (_error.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.circleAlert,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(target: 1).fadeIn().shake(),
          const SizedBox(height: 20),
        ],

        _buildSubmitButton(),
        const SizedBox(height: 20),
        _buildToggleModeButton(),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    bool? obscurePassword,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && (obscurePassword ?? !_showPassword),
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 19, color: const Color(0xFF94A3B8)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      (obscurePassword ?? !_showPassword)
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                      size: 18,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed:
                        onTogglePassword ??
                        () => setState(() => _showPassword = !_showPassword),
                  )
                : null,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.8,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _loading ? null : _showForgotPasswordDialog,
        icon: const Icon(
          LucideIcons.keyRound,
          size: 15,
          color: Color(0xFF2563EB),
        ),
        label: const Text(
          'Quên mật khẩu?',
          style: TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        key: const Key('btn-auth-submit'),
        onPressed: _loading
            ? null
            : (_isLogin ? _handleLogin : _handleRegister),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'Đăng nhập' : 'Đăng ký',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.arrowRight, size: 18),
                ],
              ),
      ),
    );
  }

  Widget _buildToggleModeButton() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'hoặc',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _isLogin = !_isLogin;
                _error = '';
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFFF8FAFC),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _isLogin
                  ? 'Chưa có tài khoản? Đăng ký ngay'
                  : 'Đã có tài khoản? Đăng nhập',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
            icon: const Icon(
              LucideIcons.shieldCheck,
              size: 14,
              color: Color(0xFF64748B),
            ),
            label: const Text(
              'Chính sách bảo mật',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const gridSize = 60.0;

    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    // Use sizeOf instead of of(context).size to prevent rebuilding on viewInsets changes
    final size = MediaQuery.sizeOf(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gradientStart,
            AppColors.gradientMiddle,
            AppColors.gradientEnd,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -size.height * 0.2,
            right: -size.width * 0.1,
            child:
                Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.12),
                            blurRadius: 120,
                            spreadRadius: 40,
                          ),
                        ],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.12, 1.12),
                      duration: 5000.ms,
                      curve: Curves.easeInOut,
                    )
                    .fade(
                      begin: 0.7,
                      end: 1.0,
                      duration: 5000.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          Positioned(
            bottom: -size.height * 0.2,
            left: -size.width * 0.1,
            child:
                Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.indigo.withValues(alpha: 0.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withValues(alpha: 0.12),
                            blurRadius: 120,
                            spreadRadius: 40,
                          ),
                        ],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1.12, 1.12),
                      end: const Offset(0.95, 0.95),
                      duration: 5500.ms,
                      curve: Curves.easeInOut,
                    )
                    .fade(
                      begin: 0.6,
                      end: 1.0,
                      duration: 5500.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          Positioned(
            top: size.height / 2 - 250,
            left: size.width / 2 - 250,
            child:
                Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.15),
                            blurRadius: 150,
                            spreadRadius: 50,
                          ),
                        ],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.08, 1.08),
                      duration: 4000.ms,
                      curve: Curves.easeInOut,
                    )
                    .fade(
                      begin: 0.8,
                      end: 1.0,
                      duration: 4000.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
        ],
      ),
    );
  }
}
