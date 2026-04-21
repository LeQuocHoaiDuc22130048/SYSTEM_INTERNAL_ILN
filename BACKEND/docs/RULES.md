

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
