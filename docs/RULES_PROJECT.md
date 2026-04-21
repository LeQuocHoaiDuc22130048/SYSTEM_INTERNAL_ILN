# QUY TẮC DỰ ÁN (PROJECT RULES - SMART E-WMS)

## 1. NGUYÊN TẮC KIẾN TRÚC (ARCHITECTURE)
* **Modular Monolith (Backend Java):** Dự án được chia thành các module nghiệp vụ riêng biệt (Auth, Inventory, Attendance).
    * *Quy tắc:* Module này không được truy cập trực tiếp vào Repository của module khác. Mọi giao tiếp phải thông qua Service Interface để đảm bảo tính đóng gói.
* **Offline-First (Mobile Flutter):** Mọi hành động (Quét QR, Điểm danh) phải được lưu vào **SQLite** trên máy bảng trước tiên.
    * Hệ thống chỉ coi là "Thành công" khi dữ liệu đã nằm an toàn trong SQLite. Việc đồng bộ lên Server là nhiệm vụ của tiến trình chạy ngầm khi có mạng.

## 2. QUY TẮC ĐẶT TÊN (NAMING CONVENTIONS)
* **Java (Backend):**
    * Class: `PascalCase` (VD: `AttendanceService`).
    * Method/Variable: `camelCase` (VD: `validateFaceImage()`).
* **Flutter (Mobile):**
    * File & Folder: `snake_case` (VD: `qr_scanner_provider.dart`).
    * Class: `PascalCase`.
* **Database (SQL):**
    * Table/Column: `snake_case` (VD: `inventory_logs`).
    * Primary Key: Luôn sử dụng `id` (UUID cho Mobile, Long cho Backend).