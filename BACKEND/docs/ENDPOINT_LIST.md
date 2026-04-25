# 🚀 DANH SÁCH API ENDPOINTS - SMART E-WMS

Tài liệu này liệt kê toàn bộ các cổng giao tiếp (Endpoints) giữa Backend (Spring Boot) và Client (Flutter/Web).
**Base URL:** `http://localhost:8080/api/v1`

---

## 1. MODULE: AUTH (Xác thực & Nhân sự)
Quản lý quyền truy cập và thông tin tài khoản nhân viên.

| Method | Endpoint | Description | Auth |
| :--- | :--- | :--- | :--- |
| `POST` | `/auth/login` | Đăng nhập bằng Username/Password -> Nhận JWT | Public |
| `GET` | `/auth/me` | Lấy thông tin chi tiết tài khoản đang đăng nhập | Token |
| `GET` | `/auth/users` | Danh sách toàn bộ nhân viên kho | ADMIN |
| `POST` | `/auth/users` | Tạo tài khoản mới cho nhân viên | ADMIN |
| `PUT` | `/auth/users/{id}` | Cập nhật thông tin hoặc đổi mật khẩu | ADMIN/Owner |
| `DELETE` | `/auth/users/{id}` | Khóa tài khoản nhân viên | ADMIN |

---

## 2. MODULE: INVENTORY (Quản lý Kho & Bo mạch)
Module cốt lõi xử lý thiết bị, mã QR và đồng bộ dữ liệu.

| Method | Endpoint | Description | Ghi chú |
| :--- | :--- | :--- | :--- |
| `GET` | `/inventory/devices` | Lấy danh sách bo mạch trong kho | Phân trang & Lọc |
| `POST` | `/inventory/devices` | Đăng ký bo mạch mới & Sinh mã QR | Cần khi nhập kho |
| `GET` | `/inventory/devices/{id}` | Chi tiết bo mạch và lịch sử sửa chữa | Truy vết |
| `GET` | `/inventory/devices/qr/{code}` | Tìm thiết bị bằng chuỗi mã QR | Dùng cho Tablet |
| `POST` | `/inventory/sync` | **Đồng bộ Offline:** Đẩy dữ liệu quét từ SQLite lên | Chứa `request_id` |
| `GET` | `/inventory/stats` | Thống kê số lượng: Mới, Đang sửa, Đã xong | Cho Dashboard |

---

## 3. MODULE: ATTENDANCE (Chấm công)
Ghi nhận thời gian làm việc của nhân viên tại kho.

| Method | Endpoint | Description | Auth |
| :--- | :--- | :--- | :--- |
| `POST` | `/attendance/check-in` | Điểm danh vào ca làm việc | Token |
| `POST` | `/attendance/check-out` | Điểm danh kết thúc ca | Token |
| `GET` | `/attendance/my-history` | Xem lịch sử chấm công cá nhân | Token |
| `GET` | `/attendance/report` | Xuất báo cáo công cho toàn bộ nhân viên | ADMIN |

---

## ⚙️ QUY TẮC PHẢN HỒI CHUẨN (STANDARD RESPONSE)
Mọi API đều trả về cấu trúc JSON đồng nhất:

```json
{
  "status": "Thành công/Thất bại",
  "message": "Thông báo chi tiết",
  "data": { ... },
  "timestamp": "yyyy-MM-dd HH:mm:ss"
}