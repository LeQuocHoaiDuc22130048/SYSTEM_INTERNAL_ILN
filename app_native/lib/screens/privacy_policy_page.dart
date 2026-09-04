import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../utils/api_client.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  Future<void> _openWebPolicy(BuildContext context) async {
    final baseUrl = ApiClient.baseUrl;
    final uri = Uri.parse('$baseUrl/privacy-policy');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở liên kết trình duyệt')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi khi mở trình duyệt')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chính sách bảo mật'),
        actions: [
          IconButton(
            tooltip: 'Mở trên trình duyệt',
            icon: const Icon(LucideIcons.externalLink),
            onPressed: () => _openWebPolicy(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 24),
              _buildSectionCard(
                isDark: isDark,
                icon: LucideIcons.shieldCheck,
                title: '1. Thu thập dữ liệu và Mục đích',
                content:
                    'Ứng dụng System Internal chỉ thu thập các dữ liệu cần thiết phục vụ quản lý và vận hành nội bộ doanh nghiệp:\n\n'
                    '• Thông tin định danh: Họ tên, tên tài khoản, số điện thoại, bộ phận công tác phục vụ xác thực người dùng.\n'
                    '• Dữ liệu sinh trắc học khuôn mặt: Vector đặc trưng khuôn mặt được dùng duy nhất cho tính năng điểm danh / chấm công nội bộ. Dữ liệu không được chia sẻ hay thương mại hóa.\n'
                    '• Quyền máy ảnh & Thư viện ảnh: Được sử dụng khi quét mã QR thiết bị, chụp ảnh biên bản kỹ thuật, linh kiện sửa chữa biến tần hoặc gửi tệp trong tin nhắn.\n'
                    '• Thông báo đẩy (Push Notification): Dùng để cập nhật tiến độ công việc, đơn hàng và phân công nhiệm vụ.',
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                isDark: isDark,
                icon: LucideIcons.lock,
                title: '2. Cam kết không chia sẻ dữ liệu',
                content:
                    'Chúng tôi cam kết tuyệt đối không bán, chia sẻ, cho thuê hay tiết lộ thông tin cá nhân, hình ảnh hoặc dữ liệu sinh trắc học của người dùng cho bất kỳ bên thứ ba hay mạng quảng cáo nào.\n\n'
                    'Ứng dụng không chứa bất kỳ mã theo dõi quảng cáo (Tracking) nào của bên thứ ba.',
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                isDark: isDark,
                icon: LucideIcons.server,
                title: '3. Bảo mật truyền tải & Lưu trữ',
                content:
                    '• Toàn bộ dữ liệu truyền giữa điện thoại và máy chủ được mã hóa bằng chuẩn HTTPS / TLS 1.2+ an toàn tuyệt đối theo tiêu chuẩn của Apple.\n'
                    '• Mật khẩu và token đăng nhập được mã hóa an toàn và lưu trữ trong Keychain / Encrypted Storage của thiết bị.',
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                isDark: isDark,
                icon: LucideIcons.userX,
                title: '4. Quyền xóa tài khoản & Dữ liệu',
                content:
                    'Tuân thủ theo điều khoản kiểm duyệt của Apple (App Store Review Guideline 5.1.1(v)), người dùng có quyền tự xóa tài khoản bất kỳ lúc nào:\n\n'
                    '• Bạn có thể vào mục "Cá nhân" ➔ "Cài đặt tài khoản" ➔ chọn "Xóa tài khoản" và xác nhận bằng mật khẩu.\n'
                    '• Khi tài khoản bị xóa, toàn bộ dữ liệu nhận diện khuôn mặt và phiên đăng nhập sẽ bị xóa hoàn toàn khỏi hệ thống.',
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                isDark: isDark,
                icon: LucideIcons.phoneCall,
                title: '5. Thông tin liên hệ & Hỗ trợ',
                content:
                    'Nếu bạn có bất kỳ câu hỏi nào về quyền riêng tư hoặc cần hỗ trợ dữ liệu cá nhân, vui lòng liên hệ:\n\n'
                    '• Đơn vị: Bộ phận Kỹ thuật - Sửa Chữa Biến Tần\n'
                    '• Email: support@suachuabientan.com\n'
                    '• Hotline: 0964 266 771',
              ),
              const SizedBox(height: 32),
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.globe, size: 18),
                  label: const Text('Xem bản Web trực tuyến'),
                  onPressed: () => _openWebPolicy(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.shield,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Quy định bảo vệ dữ liệu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hệ thống System Internal cam kết bảo mật toàn diện thông tin cá nhân và dữ liệu sinh trắc học của bạn.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
