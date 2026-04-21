# THIẾT KẾ CƠ SỞ DỮ LIỆU (DATABASE DESIGN) - SMART E-WMS

## 1. TỔNG QUAN
Hệ thống sử dụng cơ sở dữ liệu **PostgreSQL** để lưu trữ tập trung tại Backend và **SQLite** để lưu trữ đệm tại Mobile (Tablet). Thiết kế tuân thủ mô hình **Modular Monolith**, phân tách rõ ràng giữa các module nghiệp vụ.

## 2. QUY TẮC CHUNG (GLOBAL RULES)
* **Naming Convention:** Sử dụng `snake_case` cho tên bảng và tên cột.
* **Audit Fields:** Mọi bảng chính đều phải bao gồm: `created_at`, `updated_at`, `created_by`.
* **Idempotency:** Sử dụng `request_id` (UUID) trong các bảng nhật ký (log) để tránh trùng lặp dữ liệu khi đồng bộ.

## 3. CHI TIẾT CÁC BẢNG (TABLES)

### A. Module Auth (Xác thực & Người dùng)
Quản lý thông tin nhân viên và dữ liệu khuôn mặt phục vụ Face ID.

| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `id` | BIGSERIAL | PRIMARY KEY | ID tự tăng |
| `username` | VARCHAR(50) | UNIQUE, NOT NULL | Tên đăng nhập |
| `password_hash` | VARCHAR(255) | NOT NULL | Mật khẩu đã băm (BCrypt) |
| `full_name` | VARCHAR(100) | | Họ và tên nhân viên |
| `role` | VARCHAR(20) | | Vai trò (ADMIN, STAFF) |
| `face_vector` | TEXT | | Dữ liệu đặc trưng khuôn mặt (mã hóa) |
| `is_active` | BOOLEAN | DEFAULT TRUE | Trạng thái tài khoản |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Thời gian tạo |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | Thời gian cập nhật |

### B. Module Inventory (Quản lý Kho & Thiết bị)
Quản lý thông tin bo mạch và lịch sử xuất/nhập kho.

#### Bảng `devices` (Danh sách bo mạch)
| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `id` | BIGSERIAL | PRIMARY KEY | ID thiết bị |
| `qr_code` | VARCHAR(100) | UNIQUE, NOT NULL | Mã định danh QR dán trên bo mạch |
| `model_name` | VARCHAR(100) | NOT NULL | Tên model bo mạch |
| `status` | VARCHAR(50) | | NEW, REPAIRING, FIXED, RETURNED |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Thời gian khởi tạo |
| `updated_at` | TIMESTAMP | DEFAULT NOW() | Cập nhật cuối |

#### Bảng `inventory_logs` (Nhật ký xuất nhập)
Bảng này cực kỳ quan trọng cho việc đồng bộ **Offline-First**.
* `id`: BIGSERIAL (PK)
* `device_id`: BIGINT (FK -> devices)
* `user_id`: BIGINT (FK -> users)
* `action_type`: VARCHAR(20) (IN/OUT)
* `request_id`: UUID (NOT NULL) - Mã định danh duy nhất cho mỗi thao tác quét để tránh trùng lặp.
* `device_timestamp`: TIMESTAMP - Thời điểm thực tế nhân viên quét mã tại kho (lấy từ Tablet).
* `created_at`: TIMESTAMP (Thời gian ghi nhận tại Server).

### C. Module Attendance (Chấm công)
Ghi nhận lịch sử làm việc của nhân viên.
* `id`: BIGSERIAL (PK)
* `user_id`: BIGINT (FK -> users)
* `check_in_time`: TIMESTAMP (Thời gian điểm danh)
* `status`: VARCHAR(20) (SUCCESS/FAILED)
* `created_at`: TIMESTAMP

## 4. MỐI QUAN HỆ (RELATIONSHIPS)
1. Một **User** có thể có nhiều **Inventory Logs** và nhiều bản ghi **Attendance**.
2. Một **Device** có thể có nhiều **Inventory Logs** (theo dõi vòng đời từ lúc nhập đến lúc trả).

## 5. CHIẾN LƯỢC LƯU TRỮ MÃ QR
* **Backend:** Lưu chuỗi ký tự QR trong cột `qr_code` của bảng `devices`.
* **Mobile:** Đồng bộ cột `qr_code` về SQLite để phục vụ việc đối soát và hiển thị thông tin ngay cả khi mất mạng.