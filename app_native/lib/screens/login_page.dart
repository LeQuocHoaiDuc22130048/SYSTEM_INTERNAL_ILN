import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

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

    setState(() {
      _loading = true;
    });

    await Future.delayed(const Duration(milliseconds: 1400));

    setState(() {
      _loading = false;
      _isLogin = true;
      _error = '';
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đăng ký thành công! Vui lòng đăng nhập.')),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _error = '';
    });

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = 'Vui lòng điền đầy đủ thông tin.';
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _error = 'Mật khẩu phải ít nhất 6 ký tự.';
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    await Future.delayed(const Duration(milliseconds: 1400));

    setState(() {
      _loading = false;
    });

    if (!mounted) return;

    // Navigate to app
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
            // Dynamic Background effects
            Positioned(
              top: -MediaQuery.of(context).size.height * 0.2,
              right: -MediaQuery.of(context).size.width * 0.1,
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
              bottom: -MediaQuery.of(context).size.height * 0.2,
              left: -MediaQuery.of(context).size.width * 0.1,
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
              top: MediaQuery.of(context).size.height / 2 - 250,
              left: MediaQuery.of(context).size.width / 2 - 250,
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

            // Grid pattern
            Positioned.fill(child: CustomPaint(painter: GridPainter())),

            // Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  final isDesktop = width >= 1024;
                  final isTablet = width >= 640 && width < 1024;
                  final isMobile = width < 640;
                  final isShort = height < 600;
                  final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

                  // Determine branding scale
                  double brandingScale = 1.0;
                  if (isMobile) {
                    brandingScale = isShort || isKeyboardOpen ? 0.5 : 0.8;
                  } else if (isTablet) {
                    brandingScale = 0.9;
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 60 : (isTablet ? 40 : 20),
                          vertical: 20,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop ? 1100 : (isTablet ? 500 : 400),
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
                                            child: _buildFormCard(isDesktop: true),
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
                                      ),
                                      SizedBox(
                                        height: (isShort || isKeyboardOpen) ? 16 : 40,
                                      ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingSection({required double scale, required bool isMobile}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 250 * scale,
          height: 250 * scale,
          child: Image.asset(
            'assets/images/app_logo.png',
            fit: BoxFit.contain,
          ),
        ).animate().fadeIn(duration: 600.ms).scale(
              begin: const Offset(0.8, 0.8),
              duration: 600.ms,
            ),
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
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(
              begin: 0.3,
              end: 0,
              duration: 600.ms,
              delay: 100.ms,
            ),
        SizedBox(height: 12 * scale),
        Text(
          'Internal Management System',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 12 * scale : 16 * scale,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 0.2,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(
              begin: 0.3,
              end: 0,
              duration: 600.ms,
              delay: 200.ms,
            ),
      ],
    );
  }

  Widget _buildFormCard({required bool isDesktop}) {
    return Container(
          padding: EdgeInsets.all(isDesktop ? 40 : 32),
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
                ).animate().fadeIn().shake(),
                const SizedBox(height: 24),
              ],

              _buildSubmitButton(),
              const SizedBox(height: 24),
              _buildToggleModeButton(),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 300.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
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
          obscureText: isPassword && !_showPassword,
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
                      _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 18,
                      color: Colors.blue[200]?.withValues(alpha: 0.5),
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
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
