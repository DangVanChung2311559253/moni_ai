# Moni AI Backend

Backend FastAPI cho các chức năng AI của Moni AI:

- `POST /scan`: đọc ảnh hóa đơn/giao dịch bằng Gemini và phân loại danh mục
  bằng PhoBERT cục bộ.
- `POST /forecast`: dự báo chi tiêu 7, 14 hoặc 30 ngày bằng Prophet.
- `POST /detect-anomaly`: phát hiện giao dịch bất thường bằng Isolation Forest.
- `POST /ai/chat`: phân tích câu tiếng Việt và trả JSON giao dịch hoặc câu trả lời
  tài chính bằng Gemini.
- `GET /health`: kiểm tra server và trạng thái nạp model.
- `GET /docs`: Swagger UI.

## Model

```text
models/
├── expense_phobert_model/
│   └── model.safetensors
├── expense_prophet_model.json
└── expense_isolation_forest.joblib
```

Isolation Forest được lưu bằng scikit-learn 1.6.1 nên phiên bản này đã được
ghim trong `requirements.txt`.

## Chạy backend

```powershell
cd C:\Users\ACER\AndroidStudioProjects\moni_ai\backend
.\venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Flutter Android Emulator mặc định gọi `http://10.0.2.2:8000`. Scan AI,
AI Chat, dự báo và phát hiện bất thường đều dùng chung URL này. Có thể đổi URL:

```powershell
flutter run --dart-define=AI_API_BASE_URL=https://example.ngrok-free.app
```

Gemini key chỉ được đặt trong `backend/.env`:

```text
GEMINI_API_KEY=...
GEMINI_MODEL=gemini-3.6-flash
```

Ứng dụng dùng Firebase Firestore tại `users/{uid}/...` cho ví, giao dịch,
ngân sách, cảnh báo bất thường và thông báo. Gemini không tự lưu giao dịch;
Flutter chỉ ghi Firestore sau khi người dùng chọn ví và xác nhận.
