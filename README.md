# 📱 Bank Notification Listener (Flutter + Android Native)

Module độc lập lắng nghe thông báo biến động số dư từ các ngân hàng và ví điện tử tại Việt Nam, tự động bóc tách thành dữ liệu giao dịch thu/chi (`credit`/`debit`) chuẩn hóa để tích hợp vào ứng dụng Quản Lý Chi Tiêu Cá Nhân ([`App_Quan_ly_chi_tieu_ca_nhan`](/home/chinhan/Applications/App_Quan_ly_chi_tieu_ca_nhan)).

---

## 🌟 Tính Năng Nổi Bật

1. **Lắng nghe thông báo thời gian thực:**
   - Sử dụng Android Native `NotificationListenerService` bắt mọi thông báo trên máy mà không làm chậm ứng dụng.
   - Hỗ trợ hầu hết ngân hàng & ví điện tử tại Việt Nam: **Vietcombank, MBBank, Techcombank, VPBank, ACB, TPBank, BIDV, MoMo, ZaloPay, VietinBank, Timo...** và bộ fallback đa năng cho các app khác.
2. **Bộ bóc tách thông minh (Bank Notification Parser):**
   - Tự động nhận diện số tiền (hỗ trợ các dạng số: `50.000đ`, `50,000 VND`, `50k`, `+2.500.000VND`...).
   - Tự động phân loại luồng tiền: `credit` (thu nhập/tiền vào) hoặc `debit` (chi tiêu/tiền ra) khớp 100% với schema Firestore của app chính.
   - Bóc tách số tài khoản, số dư sau giao dịch, nội dung giao dịch.
   - Tự động gán danh mục gợi ý: *Ăn uống, Mua sắm, Chuyển tiền, Lương, Hóa đơn & Tiện ích, Di chuyển...*
3. **Giao diện Giám sát (Monitor UI):**
   - Banner cảnh báo & nút 1-chạm mở cài đặt cấp quyền thông báo hệ thống.
   - Thẻ hiển thị trực quan (Badge Xanh cho Thu Nhập, Badge Đỏ Cam cho Chi Tiêu).
   - Dialog xem chi tiết JSON và 1-click **"Sao chép Parsed JSON"** để dán kiểm tra.
4. **Bộ Test Giả Lập (Simulation Sheet):**
   - Không cần phải chuyển tiền thật! Bấm nút "Test Giả Lập" để bắn thử hơn 12 mẫu thông báo thực tế của VCB, MB, Techcombank, VPBank, MoMo... ngay trên app.

---

## 🚀 Cài Đặt & Chạy Thử Nghiệm

### 1. Cài đặt file APK đã build sẵn
File APK debug đã được biên dịch sẵn tại:
```bash
/home/chinhan/bank_notification_listener/build/app/outputs/flutter-apk/app-debug.apk
```
Để cài vào điện thoại hoặc máy ảo Android qua lệnh ADB:
```bash
adb install -r /home/chinhan/bank_notification_listener/build/app/outputs/flutter-apk/app-debug.apk
```

### 2. Chạy trực tiếp từ mã nguồn
```bash
cd /home/chinhan/bank_notification_listener
flutter run
```

### 3. Chạy toàn bộ Test Suite (51 tests)
```bash
flutter test
```

---

## 📂 Cấu Trúc Thư Mục

```text
lib/
├── main.dart                             # Khởi động ứng dụng & Theme Material 3
├── models/
│   ├── raw_notification.dart            # Model dữ liệu thô từ hệ thống Android
│   └── parsed_transaction.dart          # Schema giao dịch tương thích Firestore app chính
├── services/
│   ├── bank_notification_parser.dart    # Engine Regex bóc tách các ngân hàng VN
│   ├── mock_bank_samples.dart           # Danh sách 12+ mẫu tin nhắn ngân hàng test
│   └── notification_bridge.dart         # Cầu nối EventChannel / MethodChannel giữa Native & Flutter
├── screens/
│   └── monitor_screen.dart              # Màn hình giám sát realtime & bộ lọc
└── widgets/
    ├── transaction_card.dart            # Thẻ giao dịch phân biệt Thu/Chi & Dialog JSON
    └── simulation_sheet.dart            # BottomSheet chọn mẫu giả lập để test
android/
└── app/src/main/
    ├── AndroidManifest.xml              # Đăng ký BIND_NOTIFICATION_LISTENER_SERVICE
    └── kotlin/vn/finance/bank_notification_listener/
        ├── MainActivity.kt              # Xử lý EventChannel & MethodChannel
        └── BankNotificationListenerService.kt # Dịch vụ Android lắng nghe thông báo
```

---

## 🔄 Hướng Dẫn Tích Hợp Vào App Chính Sau Này

Khi bạn muốn ghép module này vào [`App_Quan_ly_chi_tieu_ca_nhan`](/home/chinhan/Applications/App_Quan_ly_chi_tieu_ca_nhan):

1. **Phần Android:**
   - Copy file `BankNotificationListenerService.kt` vào thư mục `android/app/src/main/kotlin/...` của app chính.
   - Thêm khai báo `<service>` trong `AndroidManifest.xml` của app chính.
   - Cấu hình MethodChannel & EventChannel vào `MainActivity.kt` của app chính.
2. **Phần Flutter (Dart):**
   - Copy thư mục `models/` và `services/bank_notification_parser.dart`, `notification_bridge.dart` sang app chính.
   - Lắng nghe stream `NotificationBridge.instance.notificationStream`:
     ```dart
     NotificationBridge.instance.notificationStream.listen((rawNotif) {
       final parsed = BankNotificationParser.parse(rawNotif);
       if (parsed != null) {
         // Tự động thêm vào Firestore hoặc hiển thị Dialog hỏi người dùng xác nhận:
         // Db().addTransaction(...)
       }
     });
     ```
