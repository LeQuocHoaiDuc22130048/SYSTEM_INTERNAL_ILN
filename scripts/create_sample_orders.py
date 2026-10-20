import json
import urllib.request

BASE_URL = "http://localhost:8081/api/v1"

# 1. Login Admin
login_data = json.dumps({"username": "admin", "password": "Admin@123"}).encode("utf-8")
req = urllib.request.Request(
    f"{BASE_URL}/auth/login",
    data=login_data,
    headers={"Content-Type": "application/json"}
)
with urllib.request.urlopen(req) as resp:
    res = json.loads(resp.read().decode("utf-8"))
    admin_token = res["data"]["accessToken"]
    print("Admin login success. Token acquired.")

# Customer ID for 'khachhangtest'
CUSTOMER_ID = "c276927e-b54e-4f7b-acb4-22b5188a9fc2"
CUSTOMER_NAME = "Cong Ty Tnhh Tu Dong Hoa Bien Tany Tnhh Automation Tech"
CUSTOMER_PHONE = "0909123456"

# 2. Create Order 1: In Progress
order1_payload = {
    "customerId": CUSTOMER_ID,
    "customerName": CUSTOMER_NAME,
    "customerPhone": CUSTOMER_PHONE,
    "devices": [
        {
            "deviceName": "Biến tần Schneider ATV310 11kW",
            "deviceType": "Biến tần",
            "serialNumber": "SN-SCH-2026-8812",
            "underWarranty": True,
            "description": "Báo lỗi OC quá dòng khi tăng tốc, kiểm tra khối công suất IGBT"
        }
    ]
}

req1 = urllib.request.Request(
    f"{BASE_URL}/repair-orders",
    data=json.dumps(order1_payload).encode("utf-8"),
    headers={
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": f"Bearer {admin_token}"
    }
)
with urllib.request.urlopen(req1) as resp:
    res1 = json.loads(resp.read().decode("utf-8"))
    order1 = res1["data"]
    print(f"Order 1 created: {order1.get('orderCode')} (ID: {order1.get('id')})")

# 3. Create Order 2: Completed / In Testing
order2_payload = {
    "customerId": CUSTOMER_ID,
    "customerName": CUSTOMER_NAME,
    "customerPhone": CUSTOMER_PHONE,
    "devices": [
        {
            "deviceName": "Biến tần Mitsubishi FR-A840 15kW",
            "deviceType": "Biến tần công nghiệp",
            "serialNumber": "SN-MIT-55219",
            "underWarranty": False,
            "description": "Không lên nguồn màn hình điều khiển, mất áp 24VDC"
        },
        {
            "deviceName": "Màn hình cảm ứng HMI Proface 10 inch",
            "deviceType": "HMI",
            "serialNumber": "HMI-PF-99021",
            "underWarranty": True,
            "description": "Liệt cảm ứng góc phải bên dưới"
        }
    ]
}

req2 = urllib.request.Request(
    f"{BASE_URL}/repair-orders",
    data=json.dumps(order2_payload).encode("utf-8"),
    headers={
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": f"Bearer {admin_token}"
    }
)
with urllib.request.urlopen(req2) as resp:
    res2 = json.loads(resp.read().decode("utf-8"))
    order2 = res2["data"]
    print(f"Order 2 created: {order2.get('orderCode')} (ID: {order2.get('id')})")
