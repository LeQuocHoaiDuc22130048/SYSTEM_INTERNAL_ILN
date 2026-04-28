# QUY TẮC PHÁT TRIỂN BACKEND (BACKEND RULES)

## 1. NGUYÊN TẮC PHÂN CHIA MODULE (MODULARITY)
* **Tính đóng gói:** Mỗi module (Auth, Inventory, Attendance) phải hoàn toàn độc lập về logic.

* **Giao tiếp:** Module A KHÔNG ĐƯỢC gọi trực tiếp vào Repository hoặc Entity của Module B.

* **Service-to-Service:** Mọi sự tương tác giữa các module phải thông qua Service Interface.

* **Common:** Các tiện ích dùng chung (JWT, mã hóa, định dạng ngày tháng) phải đặt trong gói common/.

## 2. QUY TẮC TẦNG DỮ LIỆU & MAPPER (DATA LAYER)
* Tuyệt đối: Không bao giờ trả trực tiếp Entity (ánh xạ database) về phía Client (Flutter).

* Mapper (MapStruct): * Bắt buộc dùng Mapper để chuyển đổi Entity <-> DTO.

* Mỗi module phải có gói mapper/ riêng.

* **DTO (Data Transfer Object):**

  * **RequestDTO:** Dùng để nhận dữ liệu từ Flutter gửi lên (có Validation).

  * **ResponseDTO:** Dùng để định dạng dữ liệu trả về (ẩn các thông tin nhạy cảm).

## 3. CẤU TRÚC THƯ MỤC TỔNG THỂ (BACKEND)
```text
/
smart-wms-root/
├── .docker/                  <-- Chứa Dockerfile, docker-compose.yml
├── common/                   <-- Các tiện ích dùng chung (Utils, Exceptions, Shared DTOs)
├── modules/                  <-- Nơi chứa các Module nghiệp vụ chính
│   ├── auth-module/          <-- Xử lý đăng nhập, Face ID, JWT
│   ├── inventory-module/     <-- Quản lý kho, Bo mạch, Mã QR
│   ├── attendance-module/    <-- Ghi nhận công, lịch sử điểm danh
│   └── notification-module/  <-- (Mở rộng) Gửi thông báo cho nhân viên
├── app/                      <-- Module khởi chạy (Chứa class @SpringBootApplication)
└── pom.xml (hoặc build.gradle)
```

## 4. CẤU TRÚC CHI TIẾT TỪNG MODULE (VÍ DỤ: IVENTORY-MODULE)
```text
/
smart-wms-root/
├── .docker/                  <-- Chứa Dockerfile, docker-compose.yml
├── common/                   <-- Các tiện ích dùng chung (Utils, Exceptions, Shared DTOs)
├── modules/                  <-- Nơi chứa các Module nghiệp vụ chính
│   ├── auth-module/          <-- Xử lý đăng nhập, Face ID, JWT
│   ├── inventory-module/     <-- Quản lý kho, Bo mạch, Mã QR
│   ├── attendance-module/    <-- Ghi nhận công, lịch sử điểm danh
│   └── notification-module/  <-- (Mở rộng) Gửi thông báo cho nhân viên
├── app/                      <-- Module khởi chạy (Chứa class @SpringBootApplication)
└── pom.xml (hoặc build.gradle)
```

## 5. QUY TẮC ĐẶT TÊN (NAMING CONVENTIONS)
* **Package:** Luôn dùng chữ thường, không dấu (VD: com.smartwms.modules.inventory).

* **Class:** PascalCase kèm hậu tố vai trò:

  * DeviceEntity, DeviceRepository, DeviceService, DeviceController, DeviceMapper.

* **API Endpoint:** Dùng chữ thường, phân cách bằng dấu gạch ngang (kebab-case):

  * `GET /api/v1/inventory/device-list`

  * `POST /api/v1/auth/login`

## 6. QUY TẮC XỬ LÝ API (API DESIGN)
* **Phiên bản:** Luôn bắt đầu bằng `/api/v1/....`

* **Phản hồi chuẩn (Standard Response):** Mọi API phải trả về một cấu trúc đồng nhất:
```json
{
  "status": "Thành công",
  "data": { },
  "message": "Mô tả ngắn gọn về kết quả"
}
```
* **HTTP Status Code:** Sử dụng đúng ý nghĩa (`200: OK`, `201: Created`, `400: Bad Request`, `401: Unauthorized`, `500: Server Error`).

## 7.QUY TẮC DATABASE & LOGGING
* **Audit Fields:** Mọi bảng (Entity) quan trọng phải có các trường: `created_at`, `updated_at`, `created_by`.

* **Transaction:** Sử dụng` @Transactional` cho các nghiệp vụ có nhiều bước ghi dữ liệu (ví dụ: Xuất kho đồng thời cập nhật nhật ký).

* **Logging:** Sử dụng @Slf4j của Lombok. Không dùng System.out.println. Chỉ log các thông tin quan trọng hoặc lỗi.

## 8. QUY TẮC BẢO MẬT (SECURITY)
* **JWT:** Sử dụng JWT để xác thực và phân quyền người dùng. Mỗi token phải chứa thông tin về vai trò (role) của người dùng.
* **Mật khẩu:** Luôn mã hóa mật khẩu bằng BCrypt trước khi lưu vào database.
* **XSS & SQL Injection:** Sử dụng Prepared Statements hoặc ORM (Hibernate) để tránh SQL Injection. Kiểm tra và làm sạch dữ liệu đầu vào để ngăn chặn XSS.

## 9. QUY TẮC HIỆN THỰC SERVICE 
* Mỗi Service phải chỉ chứa logic nghiệp vụ, không chứa logic liên quan đến database (đó là nhiệm vụ của Repository).
* Service phải gọi Repository để thực hiện các thao tác với database, sau đó sử dụng Mapper để chuyển đổi Entity sang DTO trước khi trả về Controller.
* Phải có interface cho mỗi Service để đảm bảo tính linh hoạt và dễ dàng mở rộng trong tương lai.
* Ví dụ: InventoryService sẽ có các phương thức như `getDeviceList()`, `addDevice(DeviceRequestDTO deviceRequest)`, `updateDevice(Long id, DeviceRequestDTO deviceRequest)`, `deleteDevice(Long id)`, và tất cả các phương thức này sẽ gọi Repository để thực hiện thao tác với database, sau đó sử dụng Mapper để chuyển đổi Entity sang DTO trước khi trả về Controller.
* Service cũng phải xử lý các tình huống ngoại lệ (Exception) và trả về thông tin lỗi một cách rõ ràng cho Controller, để Controller có thể trả về phản hồi phù hợp cho Client (Flutter).
