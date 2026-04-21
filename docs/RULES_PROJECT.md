# TÀI LIỆU KIẾN TRÚC HỆ THỐNG QUẢN LÝ CÔNG TY ĐIỆN TỬ (SMART E-WMS)

## 1. TỔNG QUAN DỰ ÁN
Hệ thống được thiết kế nhằm tối ưu hóa quy trình sửa chữa bảng mạch điện tử (PCB), kết hợp các công nghệ nhận diện hiện đại và cơ chế hoạt động ổn định trong môi trường công nghiệp.

### Mục tiêu chính:
* Quản lý vòng đời thiết bị sửa chữa bằng mã QR.
* Điểm danh nhân viên tự động qua nhận diện khuôn mặt (Face ID).
* Đảm bảo hệ thống hoạt động liên tục ngay cả khi mất kết nối mạng (Offline-First).

---

## 2. KIẾN TRÚC HỆ THỐNG (SYSTEM ARCHITECTURE)

Hệ thống vận hành theo mô hình **Hybrid Edge-Server** được đóng gói hoàn toàn trong Docker.

### A. Tầng Client (Tablet - Flutter App)
* **UI/UX:** Tối ưu cho máy tính bảng, tập trung vào thao tác chạm và quét.
* **Scanner:** Sử dụng Camera Native để quét mã QR sản phẩm cực nhanh.
* **Local Storage (SQLite):** Lưu trữ tạm thời các phiên làm việc khi mất Wi-Fi.
* **Print Module:** Kết nối máy in tem nhiệt qua Bluetooth/Wi-Fi.

### B. Tầng Backend (Java Spring Boot)
* **API Gateway:** Quản lý tập trung các RESTful API.
* **Security:** Xác thực nhân viên qua JWT (JSON Web Token).
* **Logic Engine:** Xử lý nghiệp vụ kho, tính toán thời gian sửa chữa và quản lý trạng thái thiết bị.
* **AI Integration:** Giao tiếp với engine nhận diện khuôn mặt.

### C. Tầng Hạ tầng (Infrastructure - Docker)
* **PostgreSQL:** Cơ sở dữ liệu quan hệ chính, đảm bảo tính toàn vẹn dữ liệu (ACID).
* **Docker Compose:** Đồng bộ môi trường chạy giữa máy Win 10 (công ty) và Win 11 (nhà).

---

## 3. CÁC TÍNH NĂNG NỔI BẬT

### 3.1. Điểm danh khuôn mặt (Face ID)
* **Cơ chế:** Flutter App chụp ảnh -> Trích xuất Face Vector -> Gửi về Java Backend so khớp.
* **Offline Mode:** Lưu log điểm danh vào SQLite kèm timestamp, đẩy lên server ngay khi có mạng.

### 3.2. Quản lý thiết bị qua mã QR
* **Tiếp nhận:** Hệ thống tự sinh mã QR duy nhất cho board mạch mới.
* **In ấn:** Lệnh in được gửi trực tiếp từ Tablet đến máy in tem dán lên thiết bị.
* **Truy vết:** Quét mã để biết: *Ai đang sửa? Sửa bao lâu? Tình trạng linh kiện thế nào?*

---

## 4. THIẾT KẾ DỮ LIỆU (DATABASE SCHEMA)

### Các bảng quan trọng:
1.  **Users:** `id, username, password_hash, role, face_vector`.
2.  **Devices:** `id, qr_code, model, current_status, reception_date`.
3.  **Inventory_Logs:** `id, device_id, user_id, action_type (IN/OUT), device_timestamp, sync_status`.
4.  **Attendance:** `id, user_id, check_in_time, photo_ref`.

---

## 5. CƠ CHẾ ĐỒNG BỘ DỮ LIỆU (SYNC LOGIC)

1.  **Ghi dữ liệu:** Mọi thao tác được ghi vào SQLite kèm một `UUID` duy nhất.
2.  **Theo dõi mạng:** App sử dụng `Connectivity Plus` để lắng nghe trạng thái internet.
3.  **Đẩy dữ liệu:** Khi có mạng, dữ liệu từ SQLite được đẩy lên Java Backend theo lô (Batch).
4.  **Idempotency:** Java Backend kiểm tra `UUID` để đảm bảo không lưu trùng nếu App gửi lại nhiều lần do mạng chập chờn.

---

## 6. CÔNG CỤ THỰC HIỆN (TECH STACK)

* **Backend:** Java 17, Spring Boot 3, Spring Data JPA.
* **Mobile:** Flutter, Room (SQLite), CameraX.
* **Database:** PostgreSQL, SQLite.
* **DevOps:** Docker Desktop, Git, Postman.

---
*Tài liệu được biên soạn bởi Senior Developer cho dự án Quản lý Điện tử nội bộ.*