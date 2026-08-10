# Thông Tin Deploy — Checkpoint 5

> `pytest tests/test_cp5.py` đọc file này để tìm địa chỉ service và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị token vào đây.**
> Repo này công khai — dán token vào là mất token.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Hoàng Công Thành |
| Mã học viên | 2A202601662 |
| Repo | https://github.com/stephhoang30/K4-DAY12-2A202601662-HoangCongThanh |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://chat-production-330f.up.railway.app |
| Platform | Railway |
| Ngày deploy | 2026-08-10 |

Kiến trúc trên cloud: hai service trong project `k4-day12-chat` — service `chat`
build từ `Dockerfile` trong repo, và service `Redis` do Railway cấp. Hai bên nói
chuyện qua mạng nội bộ `redis.railway.internal`, không đi ra Internet.

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Railway tự gán lúc chạy (thực tế nhận được 8080) |
| `API_TOKEN` | ✅ | đặt trong dashboard, sinh riêng cho bản production — khác token đang dùng ở máy |
| `REDIS_URL` | ✅ | tham chiếu `${{Redis.REDIS_URL}}` tới service Redis của Railway |
| `BUCKET_CAPACITY` | ✅ | 10 |
| `REFILL_PER_MINUTE` | ✅ | 10 |
| `DAILY_BUDGET_USD` | ✅ | 1.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/healthz

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/readyz

# 3. Không có token — mong đợi 401 kèm header WWW-Authenticate
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello"}'

# 4. Có token — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "X-Client-Id: sv-test" \
  -d '{"message":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/chat \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "X-Client-Id: sv-test" \
    -d '{"message":"test"}'
done; echo
```

## Kết Quả Chạy Thật

```
$ curl -s https://chat-production-330f.up.railway.app/healthz
{"status":"ok","service":"day12-chat-service","version":"1.0.0"}          [HTTP 200]

$ curl -s https://chat-production-330f.up.railway.app/readyz
{"status":"ready","redis":true}                                          [HTTP 200]

$ curl -i -X POST .../chat -d '{"message":"Hello"}'      # không token
HTTP/2 401
www-authenticate: Bearer

$ curl -X POST .../chat -H "Authorization: Bearer ***" -H "X-Client-Id: sv-cloud" \
       -d '{"message":"Deploy là gì?"}'
{"reply":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa
môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.",
 "client_id":"sv-cloud","turns_before":0,"usd_cost":2.145e-05,
 "usage":{"prompt":3,"completion":35}}                                   [HTTP 200]

$ # 15 request liên tiếp, xô 10 token nạp 10/phút
200 200 200 200 200 200 200 200 200 200 429 429 200 429 429

$ # lần bị chặn có kèm hướng dẫn chờ
HTTP/2 429
retry-after: 5
```

Mười request đầu tiêu hết xô, sau đó 429. Vài số 200 xen giữa các 429 là token
được nạp lại giữa chừng — 10 token/phút nghĩa là cứ 6 giây có thêm một token,
đúng hành vi của token bucket chứ không phải hạn mức cứng "10 request mỗi phút".

## Hai Lỗi Gặp Khi Deploy

Ghi lại vì cả hai đều không lộ ra khi chạy ở máy.

**1. `startCommand` trong `railway.toml` giết container.** File mẫu khai
`startCommand = "uvicorn ..."`, ghi đè `CMD` của Dockerfile. Khi thêm `exec` vào
đó cho giống Dockerfile thì container chết ngay, không kịp ghi một dòng log nào:
Railway không chạy `startCommand` qua shell, nên `exec` bị hiểu là tên chương
trình và không tồn tại. Cách sửa là bỏ hẳn `startCommand` — `CMD` trong
Dockerfile đã lo cả `$PORT` lẫn `exec`, và một nguồn sự thật thì không lệch nhau
được.

**2. Sai cổng giữa domain và app → 502.** Deploy thành công, healthcheck nội bộ
của Railway gọi `/healthz` trả 200, nhưng gọi từ ngoài vào lại 502. Log cho thấy
`Uvicorn running on http://0.0.0.0:8080`: Railway tiêm `PORT=8080` lúc chạy
(biến này không xuất hiện trong `railway variables` vì được gán động), trong khi
domain đang trỏ vào cổng 8000. Sửa target port của domain thành 8080 là xong.
Đây đúng là lý do app phải đọc `$PORT` thay vì cố định 8000.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên Railway
- `screenshots/healthz.png` — kết quả gọi `/healthz`
