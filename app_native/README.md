# Flutter Mobile & Kiosk Native Application

Ứng dụng di động và máy tính bảng chuyên dụng (Flutter) phục vụ quản lý kho linh kiện, sửa chữa đa thiết bị, chấm công khuôn mặt AI, nhắn tin real-time và cập nhật OTA.

## Tài liệu Giao diện Chi tiết
Chi tiết về toàn bộ các màn hình, luồng UX, bộ lọc, thành phần dùng chung và chế độ thích ứng Responsive/Kiosk được mô tả tại:
👉 **[Mô tả Giao diện Hệ thống Ứng dụng Di động](../docs/mobile-ui-description.md)**

## Cấu trúc Thư mục chính (`lib/`)

- `lib/app/`: Khởi tạo ứng dụng, theme (Light/Dark Mode), định tuyến (Routes).
- `lib/screens/`: Danh sách các màn hình giao diện:
  - `login_page.dart`: Đăng nhập & Đăng ký tài khoản (PENDING).
  - `main_screen.dart`: Khung ứng dụng chính & Navigation (Responsive Mobile/Tablet/Kiosk).
  - `dashboard_page.dart`: Tổng quan KPI, chỉ số & thao tác nhanh.
  - `repair_orders_page.dart`: Quản lý đơn sửa chữa, phân công KTV, timeline & xuất kho.
  - `warehouse_page.dart`: Quản lý kho PartDB, lô hàng, mượn/trả bo mạch & quét QR.
  - `attendance_screen.dart` & `face_attendance_page.dart`: Chấm công khuôn mặt Face AI (Mobile GPS & Kiosk mode).
  - `messages_page.dart`: Nhắn tin nội bộ Real-time (STOMP WebSocket).
  - `notifications_page.dart`: Trung tâm thông báo hệ thống & Deep Linking.
  - `employees_page.dart` & `account_approval_page.dart`: Quản lý nhân sự & Duyệt tài khoản PENDING.
  - `profile_page.dart`: Thông tin cá nhân, cập nhật dữ liệu Face AI & kiểm tra OTA update.
  - `scanner_page.dart`: Quét QR Code / Barcode chuyên dụng.
- `lib/widgets/`: Thành phần UI dùng chung (Status Badge, Stat Card, Media Preview Dialog, Offline Banner).
- `lib/navigation/`: Cấu hình thanh điều hướng theo quyền RBAC.
- `lib/services/`: Tương tác API Spring Boot Backend, STOMP WebSocket & Face AI Microservice.
