# Smart E-WMS - Backend (Modular Monolith)

Hệ thống quản lý kho và sửa chữa bo mạch điện tử quy mô vừa và nhỏ, được xây dựng trên nền tảng Java Spring Boot với kiến trúc Modular Monolith hiện đại.

## Công nghệ sử dụng (Tech Stack)
* **Framework:** Spring Boot 3.x
* **Ngôn ngữ:** Java 17+
* **Database:** PostgreSQL (vận hành qua Docker)
* **Thư viện bổ trợ:**
    * **Lombok:** Giảm thiểu mã thừa (Getter/Setter)
    * **MapStruct:** Chuyển đổi dữ liệu Entity <-> DTO hiệu năng cao
    * **Spring Security & JWT:** Bảo mật và định danh
    * **Validation API:** Kiểm soát dữ liệu đầu vào

##  Kiến trúc hệ thống
Dự án tuân thủ mô hình **Modular Monolith**, phân chia theo các module nghiệp vụ độc lập:

### Cấu trúc thư mục tổng thể
* `common/`: Chứa các cấu hình Security, Swagger và xử lý lỗi hệ thống
* `modules/`: Chứa các nghiệp vụ lõi
    * `auth-module/`: Đăng nhập, nhận diện Face ID và bảo mật
    * `inventory-module/`: Quản lý linh kiện, bo mạch và in mã QR
    * `attendance-module/`: Hệ thống chấm công và ghi nhận lịch sử
* `app/`: Module khởi chạy chính của ứng dụng Spring Boot

### Kiến trúc 5 tầng trong mỗi Module
1. **Entity:** Ánh xạ dữ liệu trực tiếp với PostgreSQL
2. **Repository:** Giao tiếp dữ liệu qua Spring Data JPA
3. **Mapper:** Chuyển đổi dữ liệu an toàn giữa Entity và DTO bằng MapStruct
4. **Service:** Xử lý logic nghiệp vụ tập trung
5. **Controller:** Cung cấp API RESTful (v1) cho phía Mobile

## Luồng dữ liệu (Data Flow)
Mọi dữ liệu trao đổi với Client đều phải đi qua tầng Mapper để bảo vệ cấu trúc Database:
* **Request:** `Flutter -> Controller -> DTO -> Mapper -> Entity -> Repository -> DB`
* **Response:** `DB -> Repository -> Entity -> Mapper -> DTO -> Controller -> Flutter`

## Quy tắc phát triển (Development Rules)
* **Tính đóng gói:** Module A không gọi trực tiếp Repository/Entity của Module B. Giao tiếp qua Service Interface
* **Dữ liệu:** Tuyệt đối không trả Entity trực tiếp về Client. Bắt buộc dùng DTO
* **Đặt tên:** * Package: Chữ thường (ví dụ: `com.smartwms.modules.inventory`)
    * Class: PascalCase (ví dụ: `DeviceEntity`, `DeviceMapper`)
    * API: kebab-case (ví dụ: `/api/v1/inventory/device-list`)
* **API Response:** Luôn trả về cấu trúc chuẩn gồm `status`, `data`, và `message`
* **Audit Fields:** Mọi bảng chính phải có `created_at`, `updated_at`, `created_by`

## Hướng dẫn cài đặt (Sắp tới)
1. Cấu hình Docker cho PostgreSQL.
2. Cập nhật `application.yaml` để kết nối DB.
3. Chạy lệnh `mvn clean install` để MapStruct sinh mã chuyển đổi.