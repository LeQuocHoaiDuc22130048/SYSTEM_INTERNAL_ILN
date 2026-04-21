# KIẾN TRÚC CHI TIẾT BACKEND (MODULAR MONOLITHIC)

## 1. CẤU TRÚC TỔNG THỂ 
Dự án được tổ chức theo các Module nghiệp vụ độc lập. Mỗi module tự quản lý logic, database và cách hiển thị dữ liệu của riêng nó
```text
com.smartwms.backend
├── AppApplication.java             # Entry point (Main class)
├── common/                         # Tiện ích dùng chung cho toàn hệ thống
│   ├── configs/                    # Security, MapStruct, Swagger
│   ├── dto/                        # BaseResponse, ErrorResponse
│   └── exceptions/                 # GlobalExceptionHandler
└── modules/                        # Các Module nghiệp vụ chính
    ├── auth/                       # Chức năng Login, Face ID, Security
    ├── inventory/                  # Quản lý bo mạch, In mã QR
    └── attendance/                 # Chấm công tự động
```

## 2. KIẾN TRÚC 5 TẦNG TRONG MỖI MODULE
* **1** Entity (Domain Layer): Ánh xạ trực tiếp với bảng trong PostgreSQL (Dùng Hibernate).
* **2:** Repository (Data Access): Giao tiếp với Database (Dùng Spring Data JPA).
* **3** Mapper (Mapping Layer): Chuyển đổi qua lại giữa Entity và DTO (Dùng MapStruct).
* **4** Service (Business Logic): Nơi xử lý mọi tính toán, logic in QR, so khớp Face ID.
* **5** Controller (Web Layer): Cung cấp API RESTful cho Mobile (Flutter).

---

## 3. QUY TRÌNH XỬ LÝ DỮ LIỆU (DATA FLOW)

Luồng dữ liệu bắt buộc phải đi qua tầng Mapper để đảm bảo an toàn:

* **Chiều Nhận (Request):** Flutter -> Controller -> DTO -> Mapper -> Entity -> Repository -> PostgreSQL
* **Chiều Trả (Response):** PostgreSQL -> Repository -> Entity -> Mapper -> DTO -> Controller -> Flutter

## 4. QUY TẮC GIAO TIẾP GIỮA CÁC MODULE
* **Interface-based:** Module A chỉ được gọi Module B thông qua Service Interface.

* **DTO Only:** Khi truyền dữ liệu giữa các module, chỉ được truyền DTO, không được truyền Entity để tránh làm lộ cấu trúc bảng.

## 5. CÔNG NGHỆ CHỦ CHỐT (TECH STACK)
* **Lombok:** Giảm thiểu mã thừa (Getter, Setter, Constructor).

* **MapStruct:** Tự động sinh mã chuyển đổi DTO-Entity lúc compile (Hiệu năng cực cao).

* **Spring Security & JWT:** Bảo mật hệ thống và định danh nhân viên.

* **Validation API:** Kiểm tra dữ liệu đầu vào (ví dụ: mã QR không được để trống).

---

## 6. QUY TẮC ĐẶT TÊN TRONG MODULE

* **Entity:** [Name]Entity.java (VD: DeviceEntity.java)

* **DTO:** [Name]Request.java hoặc [Name]Response.java

* **Mapper:** [Name]Mapper.java (Interface)

* **Repository:** [Name]Repository.java

---
