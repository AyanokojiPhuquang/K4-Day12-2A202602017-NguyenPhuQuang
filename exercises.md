# Phiếu Phản Ánh — K4 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Phú Quang  Mã học viên: 2A202602017

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `api_token` không có giá trị mặc định nên app chết ngay khi
khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc
"chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi deploy lên Railway mà quên set biến API_TOKEN trong dashboard, app sẽ crash ngay lập tức với ValidationError và log hiển thị rõ ràng trên dashboard. Mình nhìn thấy lỗi ngay lúc deploy, sửa được trong 1 phút. Nếu để mặc định "changeme", app sẽ khởi động bình thường, ai cũng có thể gọi API bằng token "changeme" — service chạy mà không ai biết nó đang mở toang, cho đến khi nhìn hóa đơn LLM cuối tháng.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log: `{"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T14:35:12+00:00", "client_id": "sv01", "prompt_tokens": 3, "completion_tokens": 37, "usd_cost": 0.0000226}`
>
> Hai việc làm được: (1) Lọc theo client_id để biết client nào tiêu nhiều tiền nhất trong ngày chỉ bằng một câu query trên Cloud Logging: `jsonPayload.client_id = "sv01"`. (2) Tạo alert tự động khi usd_cost vượt ngưỡng bất thường, ví dụ một request tốn hơn $0.01 — điều mà print() không có cấu trúc nào để máy phân tích.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t chat:single .
docker build -t chat:multi .
docker images | grep chat
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1.05 GB |
| Multi-stage | ~195 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần chênh lệch chủ yếu là bộ compiler (gcc, build-essential), các header file C dùng để biên dịch các thư viện Python có native extension, và toàn bộ pip cache. Trong bản 1 stage dùng image python:3.11 đầy đủ (chứa cả Debian với rất nhiều package hệ thống), tất cả những thứ đó đều còn lại trong image cuối. Với multi-stage, stage builder cài xong dependency rồi bị vứt, stage runtime chỉ dùng python:3.11-slim (Debian tối giản) và copy đúng kết quả pip install sang — không mang theo compiler hay cache.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Với Dockerfile hiện tại: COPY requirements.txt và RUN pip install được dùng lại từ cache (vì requirements.txt không đổi), chỉ layer COPY app và COPY utils phải chạy lại. Build lại chỉ mất vài giây. Nếu đặt COPY . . trước pip install: bất kỳ thay đổi nào trong source code cũng invalidate cache từ layer COPY trở đi, kéo theo pip install phải chạy lại toàn bộ (mất vài phút). Đây là lý do thứ tự COPY requirements trước, pip install, rồi mới COPY source là best practice.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: (1) Code Python có lỗ hổng injection cho phép thực thi lệnh tùy ý, (2) Kẻ tấn công gửi payload qua /chat để chạy shell command trong container, (3) Vì container chạy bằng root, process có toàn quyền trên filesystem của container, (4) Nếu có thêm một lỗ hổng kernel escape (container breakout), kẻ tấn công thoát ra host với quyền root. Lệnh USER appuser cắt đứt ở bước 3: dù kẻ tấn công thực thi được lệnh, nó chỉ có quyền của user thường — không đọc được /etc/shadow, không mount được filesystem, và nếu escape ra host thì cũng chỉ là user uid 10001 không có quyền gì.

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> Header WWW-Authenticate là bắt buộc theo chuẩn HTTP RFC 7235: khi server trả 401, nó phải cho client biết cần xác thực bằng cách nào (Bearer, Basic, Digest...) để client hoặc thư viện HTTP có thể tự động xử lý. Trả cùng một thông báo "invalid or missing bearer token" cho mọi trường hợp là để chống information leakage: nếu phân biệt "sai scheme" vs "sai token" vs "thiếu header", kẻ tấn công biết được mình đã đoán đúng scheme chưa, token có tồn tại không — từ đó thu hẹp không gian tìm kiếm và dò token dễ hơn.

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> Với min(capacity, ...): dù im lặng 10 phút, xô chỉ chứa tối đa capacity = 10 token. Gửi được đúng 10 request trước khi bị 429. Nếu bỏ min: sau 10 phút im lặng, token tích lũy = 10 (ban đầu đầy, tiêu 0) + 10 phút × 10 token/phút = nhưng thực tế ban đầu đã đầy 10, cộng thêm refill 10×10 = 100, tổng cộng 110 token. Client gửi được 110 request liên tiếp. Với 1 ngày im lặng: 10 + 1440×10 = 14.410 request bắn trong 1 giây — rate limit trở nên vô nghĩa.

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> Hạn mức $30/tháng: client gọi liên tục từ 2h sáng, có thể tiêu hết $30 trong vài giờ (tùy tốc độ request và giá mỗi request). Thiệt hại tối đa: $30. Service chỉ hồi phục đầu tháng sau — cả tháng còn lại bị chặn hoặc phải tăng hạn mức thủ công. Hạn mức $1/ngày: client gọi từ 2h sáng, tối đa chỉ mất $1 rồi bị chặn. Thiệt hại tối đa: $1. Service tự hồi phục vào 0h UTC ngày hôm sau (key Redis theo ngày tự reset) mà không cần ai can thiệp. Thiệt hại giảm 30 lần và recovery tự động.

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> (1) Redis mất kết nối 30 giây. (2) Cả 3 container gọi ping() đều timeout/fail. (3) Endpoint gộp trả 503 cho cả 3 container. (4) Orchestrator thấy liveness check fail → đánh dấu cả 3 container là unhealthy. (5) Orchestrator restart cả 3 container cùng lúc. (6) Trong khi 3 container đang restart, không có container nào phục vụ request → toàn bộ service down. (7) Redis quay lại sau 30 giây nhưng không còn container nào sống để nhận traffic. (8) Phải đợi container khởi động lại xong mới phục vụ được — biến sự cố Redis nhỏ 30 giây thành sự cố toàn hệ thống vài phút. Tách riêng thì /healthz vẫn trả 200 (process sống), chỉ /readyz trả 503 → LB ngừng gửi traffic nhưng không restart container → Redis quay lại là service tự phục hồi.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi gặp: Container start rồi tắt ngay với log "pydantic_core._pydantic_core.ValidationError: 1 validation error for Settings - api_token: Field required". Nguyên nhân: quên set biến API_TOKEN trong dashboard của Railway — chỉ set ở file .env local. Tìm ra bằng cách chạy `railway logs` và thấy dòng ValidationError. Sửa bằng cách vào dashboard Railway → service → Variables → thêm API_TOKEN với giá trị token đã sinh bằng secrets.token_urlsafe(32). Sau khi set xong, Railway tự redeploy và service chạy bình thường.
