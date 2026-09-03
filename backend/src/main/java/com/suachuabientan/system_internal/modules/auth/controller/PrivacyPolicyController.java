package com.suachuabientan.system_internal.modules.auth.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping
@Tag(name = "Privacy Policy", description = "Chinh sach bao mat ung dung")
public class PrivacyPolicyController {

    @GetMapping(value = {"/privacy-policy", "/api/v1/privacy-policy"}, produces = MediaType.TEXT_HTML_VALUE + ";charset=UTF-8")
    @Operation(summary = "Xem chinh sach bao mat cua ung dung System Internal")
    public ResponseEntity<String> getPrivacyPolicy() {
        String html = """
            <!DOCTYPE html>
            <html lang="vi">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Chính sách bảo mật - System Internal</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                        line-height: 1.7;
                        background-color: #f8fafc;
                        color: #1e293b;
                        margin: 0;
                        padding: 24px 16px;
                    }
                    .container {
                        max-width: 800px;
                        margin: 0 auto;
                        background: #ffffff;
                        padding: 40px;
                        border-radius: 16px;
                        box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
                        border: 1px solid #e2e8f0;
                    }
                    h1 { color: #2563eb; font-size: 28px; margin-bottom: 8px; }
                    .updated { color: #64748b; font-size: 14px; margin-bottom: 32px; }
                    h2 { font-size: 20px; margin-top: 28px; border-bottom: 2px solid #eff6ff; padding-bottom: 8px; color: #0f172a; }
                    ul { padding-left: 20px; }
                    li { margin-bottom: 8px; }
                    .badge {
                        display: inline-block;
                        background: #eff6ff;
                        color: #2563eb;
                        padding: 4px 12px;
                        border-radius: 9999px;
                        font-weight: 600;
                        font-size: 13px;
                        margin-bottom: 16px;
                    }
                    .highlight-box {
                        background: #f1f5f9;
                        border-left: 4px solid #2563eb;
                        padding: 16px;
                        border-radius: 0 8px 8px 0;
                        margin: 20px 0;
                    }
                    footer {
                        margin-top: 40px;
                        padding-top: 20px;
                        border-top: 1px solid #e2e8f0;
                        font-size: 14px;
                        color: #64748b;
                        text-align: center;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <span class="badge">Quy định quyền riêng tư & Bảo mật dữ liệu</span>
                    <h1>Chính Sách Bảo Mật (Privacy Policy)</h1>
                    <div class="updated">Ứng dụng: <strong>System Internal</strong> (Hệ thống quản lý nội bộ) • Cập nhật lần cuối: 03/09/2026</div>

                    <p>Chào mừng bạn đến với <strong>System Internal</strong>. Chúng tôi cam kết bảo vệ tuyệt đối thông tin cá nhân và dữ liệu riêng tư của cán bộ, công nhân viên và đối tác kỹ thuật khi sử dụng ứng dụng.</p>

                    <h2>1. Thu thập dữ liệu và Mục đích sử dụng</h2>
                    <p>Ứng dụng chỉ thu thập các dữ liệu cần thiết phục vụ vận hành công việc nội bộ:</p>
                    <ul>
                        <li><strong>Thông tin định danh:</strong> Họ tên, tên tài khoản, số điện thoại, bộ phận công tác phục vụ xác thực phân quyền nhân viên.</li>
                        <li><strong>Dữ liệu sinh trắc học khuôn mặt (Biometric Data):</strong> Vector đặc trưng nhận diện khuôn mặt được tạo cục bộ nhằm phục vụ duy nhất tính năng <em>chấm công điểm danh nội bộ</em>. Dữ liệu này chỉ được đối chiếu với mã nhân viên trong hệ thống và tuyệt đối không bao giờ được chia sẻ hay thương mại hóa.</li>
                        <li><strong>Máy ảnh (Camera) & Thư viện ảnh (Photo Library):</strong> Được sử dụng khi bạn quét mã QR thiết bị, chụp ảnh biên bản nghiệm thu, ảnh lỗi biến tần sửa chữa hoặc gửi ảnh trong tin nhắn trao đổi công việc.</li>
                        <li><strong>Mã thiết bị & Thông báo đẩy (Push Notification Token):</strong> Dùng để gửi thông báo tức thời về lịch phân công, cập nhật trạng thái đơn hàng và tin nhắn nội bộ.</li>
                    </ul>

                    <h2>2. Cam kết không chia sẻ dữ liệu cho bên thứ ba</h2>
                    <div class="highlight-box">
                        <strong>Cam kết bảo mật:</strong> Chúng tôi <strong>KHÔNG</strong> bán, chia sẻ, cho thuê hay tiết lộ bất kỳ thông tin cá nhân, hình ảnh hoặc dữ liệu sinh trắc học nào của người dùng cho bất kỳ bên thứ ba hay mạng quảng cáo nào. Ứng dụng không chứa mã theo dõi quảng cáo (No Ad Tracking).
                    </div>

                    <h2>3. Bảo mật truyền tải và Lưu trữ dữ liệu</h2>
                    <ul>
                        <li>Mọi dữ liệu truyền giữa ứng dụng di động và máy chủ đều được mã hóa bằng giao thức bảo mật <strong>HTTPS / TLS 1.2+</strong> chuẩn công nghiệp.</li>
                        <li>Máy chủ được thiết lập tường lửa bảo vệ, dữ liệu mật khẩu và mã khóa xác thực đều được mã hóa một chiều (Hashing) an toàn.</li>
                    </ul>

                    <h2>4. Quyền xóa tài khoản và Xóa dữ liệu (Account & Data Deletion)</h2>
                    <p>Tuân thủ nghiêm ngặt theo Hướng dẫn kiểm duyệt của Apple (App Store Review Guideline 5.1.1(v)), người dùng có toàn quyền xóa tài khoản và dữ liệu cá nhân của mình:</p>
                    <ul>
                        <li>Bạn có thể thực hiện xóa tài khoản trực tiếp trong ứng dụng bất kỳ lúc nào tại: <strong>Cá nhân ➔ Cài đặt tài khoản ➔ Xóa tài khoản</strong>.</li>
                        <li>Khi xác nhận xóa tài khoản bằng mật khẩu, toàn bộ dữ liệu sinh trắc học khuôn mặt, phiên đăng nhập và thông tin tài khoản của bạn sẽ bị hủy kích hoạt và xóa bỏ khỏi hệ thống.</li>
                    </ul>

                    <h2>5. Quyền của người dùng đối với dữ liệu</h2>
                    <ul>
                        <li>Quyền xem, kiểm tra và yêu cầu chỉnh sửa thông tin cá nhân.</li>
                        <li>Quyền thu hồi quyền truy cập Camera, Thư viện ảnh hoặc Thông báo bất cứ lúc nào trong mục Cài đặt (Settings) của thiết bị.</li>
                    </ul>

                    <h2>6. Thông tin liên hệ & Hỗ trợ</h2>
                    <p>Nếu bạn có bất kỳ câu hỏi nào liên quan đến Chính sách bảo mật này hoặc cần hỗ trợ về dữ liệu cá nhân, vui lòng liên hệ:</p>
                    <ul>
                        <li><strong>Đơn vị phát triển:</strong> Bộ phận Kỹ thuật & Quản trị Hệ thống - Sửa Chữa Biến Tần</li>
                        <li><strong>Email hỗ trợ:</strong> support@suachuabientan.com</li>
                        <li><strong>Hotline:</strong> 0903 000 000</li>
                    </ul>

                    <footer>
                        &copy; 2026 System Internal - Sửa Chữa Biến Tần. All rights reserved.
                    </footer>
                </div>
            </body>
            </html>
            """;
        return ResponseEntity.ok(html);
    }
}
