import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../utils/network_provider.dart';

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
      context.read<BackendDataProvider>().loadAll();
      Navigator.of(context).pushReplacementNamed('/dashboard');
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
                      : () => Navigator.of(dialogContext).pop(),
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

    usernameController.dispose();
    phoneController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  final isShort = availableHeight < 600;

                  // Determine branding scale
                  double brandingScale = 1.0;
                  if (isMobile) {
                    brandingScale = isShort ? 0.45 : 0.65;
                  } else if (isTablet) {
                    brandingScale = 0.9;
                  }

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: availableHeight),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 60 : (isTablet ? 40 : 20),
                          vertical: 20,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop
                                  ? 1100
                                  : (isTablet ? 500 : 400),
                            ),
                            child: isDesktop
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _buildBrandingSection(
                                          scale: 1.1,
                                          isMobile: false,
                                        ),
                                      ),
                                      const SizedBox(width: 80),
                                      Expanded(
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 450,
                                            ),
                                            child: _buildFormCard(
                                              isDesktop: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildBrandingSection(
                                        scale: brandingScale,
                                        isMobile: isMobile,
                                        isShort: isShort,
                                      ),
                                      SizedBox(height: isShort ? 16 : 24),
                                      _buildFormCard(isDesktop: false),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
        SizedBox(
              width: 250 * scale,
              height: 250 * scale,
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.contain,
              ),
            )
            .animate(target: 1)
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.8, 0.8), duration: 600.ms),
        if (!isShort) ...[
          SizedBox(height: 24 * scale),
          Text(
                'INVERTER LIKE NEW',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 28 * scale : 40 * scale,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              )
              .animate(target: 1)
              .fadeIn(duration: 600.ms, delay: 100.ms)
              .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 100.ms),
          SizedBox(height: 12 * scale),
          Text(
                'Internal Management System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 12 * scale : 16 * scale,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w500,
                ),
              )
              .animate(target: 1)
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 200.ms),
        ],
      ],
    );
  }

  Widget _buildFormCard({required bool isDesktop}) {
    return Container(
          padding: EdgeInsets.all(isDesktop ? 40 : 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLogin ? 'Đăng nhập' : 'Đăng ký tài khoản',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Nhập thông tin tài khoản để tiếp tục'
                    : 'Điền thông tin để đăng ký tài khoản mới',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[100]?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),

              if (!_isLogin) ...[
                _buildInputField(
                  label: 'Họ và tên',
                  hint: 'Nhập họ và tên...',
                  controller: _fullNameController,
                  icon: LucideIcons.user,
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  label: 'Số điện thoại',
                  hint: 'Nhập số điện thoại...',
                  controller: _phoneController,
                  icon: LucideIcons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
              ],

              _buildInputField(
                label: 'Tên đăng nhập',
                hint: 'Nhập username...',
                controller: _usernameController,
                icon: LucideIcons.user,
              ),
              const SizedBox(height: 20),

              _buildInputField(
                label: 'Mật khẩu',
                hint: 'Nhập mật khẩu...',
                controller: _passwordController,
                icon: LucideIcons.lock,
                isPassword: true,
              ),
              if (_isLogin) ...[
                const SizedBox(height: 8),
                _buildForgotPasswordButton(),
              ],
              const SizedBox(height: 24),

              // Error Message
              if (_error.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.circleAlert,
                        size: 18,
                        color: Color(0xFFFCA5A5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate(target: 1).fadeIn().shake(),
                const SizedBox(height: 24),
              ],

              _buildSubmitButton(),
              const SizedBox(height: 24),
              _buildToggleModeButton(),
            ],
          ),
        )
        .animate(target: 1)
        .fadeIn(duration: 600.ms, delay: 300.ms)
        .slideY(begin: 0.2, end: 0);
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.blue[100],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && (obscurePassword ?? !_showPassword),
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(
              icon,
              size: 20,
              color: Colors.blue[200]?.withValues(alpha: 0.5),
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      (obscurePassword ?? !_showPassword)
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                      size: 18,
                      color: Colors.blue[200]?.withValues(alpha: 0.5),
                    ),
                    onPressed:
                        onTogglePassword ??
                        () => setState(() => _showPassword = !_showPassword),
                  )
                : null,
            hintStyle: TextStyle(
              color: Colors.blue[200]?.withValues(alpha: 0.3),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
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
        icon: const Icon(LucideIcons.keyRound, size: 16),
        label: const Text('Quên mật khẩu?'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue[100],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading
            ? null
            : (_isLogin ? _handleLogin : _handleRegister),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isLogin ? 'Đăng nhập' : 'Đăng ký',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildToggleModeButton() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.1)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'hoặc',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[100]?.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _isLogin = !_isLogin;
                _error = '';
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _isLogin ? 'Đăng ký tài khoản mới' : 'Đã có tài khoản? Đăng nhập',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.1),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.2,
            left: -size.width * 0.1,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.indigo.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: size.height / 2 - 250,
            left: size.width / 2 - 250,
            child: Container(
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
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
        ],
      ),
    );
  }
}
