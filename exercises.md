# Phiếu Phản Ánh — K4 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Hoàng Công Thành  Mã học viên: 2A202601662

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `api_token` không có giá trị mặc định nên app chết ngay khi
khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc
"chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống tôi suýt gặp hôm nay: deploy lên Railway, biến môi trường phải set
> lại trong dashboard chứ không lấy từ `.env` ở máy. Chỉ cần quên `API_TOKEN` là
> ra hai kịch bản hoàn toàn khác nhau.
>
> Có mặc định `"changeme"`: app khởi động bình thường, `/healthz` trả 200,
> Railway báo deploy thành công, domain hoạt động. Không có gì báo động cả. Mà
> `"changeme"` thì nằm ngay trong source code công khai trên GitHub, nên bất kỳ
> ai đọc repo đều gọi được `/chat`. Rate limit và cost guard tính theo
> `X-Client-Id` — header do client tự khai — nên kẻ gọi chỉ cần đổi client id là
> có một hạn mức mới tinh. Tôi sẽ chỉ phát hiện khi nhìn hóa đơn, tức là sau khi
> tiền đã mất.
>
> Không có mặc định: pydantic ném `ValidationError` ngay lúc khởi động, container
> chết, Railway báo deploy FAILED và **giữ nguyên bản cũ đang chạy**. Tôi biết
> trong vài giây, chưa ai kịp gọi vào, và bản đang phục vụ người dùng không hề
> hấn gì.
>
> Điểm mấu chốt không phải là "báo lỗi sớm hơn" mà là **kiểu lỗi**: thiếu mặc
> định biến một lỗ hổng bảo mật im lặng thành một sự cố deploy ồn ào. Sự cố
> deploy thì ai cũng sửa được trong 2 phút; lỗ hổng im lặng thì không ai biết mà
> sửa.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật lấy từ service khi gọi `/chat`:
>
> ```json
> {"event": "chat_completed", "severity": "INFO", "ts": "2026-08-10T08:04:56.597995+00:00", "client_id": "sv01", "prompt_tokens": 3, "completion_tokens": 37, "usd_cost": 2.265e-05}
> ```
>
> **Việc thứ nhất — cộng tiền theo client mà không cần sửa code.** Mỗi dòng có
> `client_id` và `usd_cost` ở dạng số, nên tôi hỏi được những câu như "24 giờ qua
> client nào tốn nhiều tiền nhất" hay "tổng chi phí giờ vừa rồi là bao nhiêu"
> bằng một truy vấn trên log, và dựng cảnh báo khi tổng vượt ngưỡng. Với
> `print("đã trả lời xong")` thì thông tin đó đơn giản là không tồn tại — có
> parse cũng không ra thứ không được ghi.
>
> **Việc thứ hai — lọc và đếm theo mức nghiêm trọng.** `severity` luôn viết hoa
> đúng bộ giá trị mà Cloud Logging hiểu, nên tôi lọc được `severity=ERROR`, đếm
> số lỗi mỗi phút, và gắn cảnh báo vào con số đó. `print` cho ra chuỗi tự do:
> muốn đếm lỗi thì phải viết regex đoán chữ, và regex đó vỡ ngay lần đầu có người
> đổi câu chữ trong thông báo.
>
> Điểm chung của cả hai: log JSON một dòng là **dữ liệu có cấu trúc**, còn `print`
> là văn xuôi cho người đọc. Máy truy vấn được dữ liệu, không truy vấn được văn
> xuôi. Chi tiết "một dòng" cũng quan trọng — cloud gom log theo dòng, nên chỉ
> cần `indent` là một event vỡ thành chục mẩu vô nghĩa.

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
| 1 stage (bản đầu) | 1200 MB (1.2GB) |
| Multi-stage | 245 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh lệch khoảng **955MB**, và gần như toàn bộ đến từ base image. Tôi đo riêng
> hai base: `python:3.11` là **1.12GB** còn `python:3.11-slim` chỉ **150MB** —
> riêng khoản này đã là ~970MB.
>
> Bản đầy đủ mang theo cả một bộ công cụ build: gcc/g++, make, header của thư
> viện C, git, và nhiều thư viện hệ thống chỉ cần lúc *biên dịch* package Python.
> Chúng cần khi cài đặt, nhưng lúc chạy thì không ai đụng tới. Bản slim bỏ hết,
> chỉ giữ Python và số ít thư viện hệ thống tối thiểu.
>
> Multi-stage là cách giữ được cả hai: stage `builder` vẫn có đủ đồ nghề để cài
> thư viện vào `/opt/venv`, rồi stage runtime chỉ `COPY --from=builder /opt/venv`.
> Compiler và cache pip nằm lại stage đầu và bị vứt đi cùng nó.
>
> Hai khoản nhỏ hơn cũng góp vào: bản 1 stage dùng `COPY . .` nên copy cả repo
> (tài liệu, tests, `.git` nếu không bị chặn) vào image, còn bản của tôi chỉ copy
> `app/` và `utils/`; và `pip install` không có `--no-cache-dir` sẽ để lại cache
> wheel trong image.
>
> Điều đáng nói là dung lượng không chỉ là chuyện ổ cứng: 955MB đó phải đẩy qua
> mạng mỗi lần deploy, và mỗi gói thừa trong image là một thứ nữa có thể dính CVE
> mà tôi phải vá dù chẳng bao giờ dùng.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Tôi sửa `app/main.py` rồi build lại, đây là kết quả thật:
>
> ```
> CACHED  [builder 2/4] WORKDIR /app
> CACHED  [builder 3/4] COPY requirements.txt .
> CACHED  [builder 4/4] RUN python -m venv /opt/venv && pip install -r requirements.txt
> CACHED  [runtime 2/7] RUN apt-get install curl
> CACHED  [runtime 3/7] RUN useradd --uid 10001 app
> CACHED  [runtime 5/7] COPY --from=builder /opt/venv /opt/venv
>         [runtime 6/7] COPY --chown=app:app app ./app      ← chạy lại
>         [runtime 7/7] COPY --chown=app:app utils ./utils  ← chạy lại
> ```
>
> Chỉ đúng hai layer cuối phải chạy lại, và cả hai đều là copy vài chục KB nên
> gần như tức thời. Layer `pip install` — thứ tốn 18 giây và phải tải mấy chục MB
> wheel — được dùng lại nguyên vẹn.
>
> Lý do là cache của Docker mang tính **dây chuyền**: một layer chỉ dùng lại được
> nếu layer trước nó và nội dung đầu vào của chính nó đều không đổi. Vì
> `requirements.txt` không đổi nên `COPY requirements.txt` giữ nguyên hash, và
> `RUN pip install` đứng ngay sau nó cũng vậy.
>
> Nếu đặt `COPY . .` trước `RUN pip install` thì mọi thứ đảo ngược. `COPY . .`
> nhận cả `app/` vào đầu vào, nên sửa một ký tự là layer đó đổi hash, và **tất cả
> layer phía sau bị vô hiệu theo** — kể cả `pip install`. Kết quả: mỗi lần sửa
> một dòng code là ngồi chờ cài lại toàn bộ thư viện. Đây là lý do quy tắc chung
> là xếp Dockerfile theo **tần suất thay đổi**: thứ ít đổi nhất (dependency) lên
> trước, thứ đổi liên tục (source code) xuống cuối.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện, từng bước một:
>
> 1. **Lỗ hổng trong code.** Ví dụ một chỗ deserialize dữ liệu người dùng gửi
>    lên, hoặc ghép chuỗi vào lệnh shell. Kẻ tấn công đạt được thực thi mã tùy ý
>    *bên trong tiến trình Python*.
> 2. **Bành trướng trong container.** Nếu tiến trình chạy bằng root, kẻ tấn công
>    ghi được vào mọi chỗ trong container: sửa code của app để cài cửa hậu lâu
>    dài, `pip install`/`apt-get` thêm công cụ dò quét, đọc mọi file cấu hình và
>    biến môi trường — trong đó có `API_TOKEN` và `REDIS_URL` kèm mật khẩu.
> 3. **Thoát ra host.** Từ vị trí root trong container, kẻ tấn công tìm đường
>    thoát: lỗ hổng kernel, docker socket bị mount vào, volume mount hớ hênh, hay
>    container chạy `--privileged`. Điểm cốt lõi là **container không phải máy ảo
>    — nó dùng chung kernel với host**, nên root trong container và root trên host
>    là cùng uid 0. Thoát ra được là thành root thật.
>
> `USER app` cắt chuỗi này ở **bước 2**, và cắt luôn cả bước 3 vì bước 3 dựa vào
> đặc quyền có được ở bước 2. Kẻ tấn công vẫn thực thi được mã (bước 1 là lỗi ở
> code, Docker không chữa được), nhưng chỉ với uid 10001:
>
> - Không ghi được vào `/app` — tôi đã thử: `touch /app/test-ghi` trả
>   `Permission denied`.
> - Không cài thêm được gói nào, không sửa được file hệ thống.
> - Nếu có thoát ra host thì cũng chỉ là một uid vô danh không đặc quyền, chứ
>   không phải root.
>
> Nói cách khác `USER` không ngăn được vụ xâm nhập, nó **giới hạn thiệt hại tối
> đa** của vụ đó. Đây là phòng thủ nhiều lớp: giả định lớp trước sẽ thủng, và lo
> sao cho lúc thủng thì mất ít nhất.

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> **Về `WWW-Authenticate`:** chuẩn HTTP (RFC 7235) quy định response 401 *bắt
> buộc* kèm header này. Ý nghĩa của nó là: 401 không chỉ nói "bạn bị từ chối" mà
> còn nói "và đây là cách để được chấp nhận". Nhờ vậy client không cần biết trước
> API này dùng kiểu xác thực gì — thư viện HTTP đọc header, thấy `Bearer`, và
> biết phải gắn token vào đâu. Thiếu header thì client chỉ nhận được một cánh cửa
> đóng không biển chỉ dẫn, và phải đoán bằng cách đọc tài liệu. Đây cũng chính là
> ranh giới giữa 401 và 403: 401 nghĩa là "chưa xác thực, thử lại đi", còn 403 là
> "đã biết bạn là ai rồi, và câu trả lời vẫn là không".
>
> **Về một thông báo chung:** đây là đánh đổi giữa tiện cho người dùng và an toàn,
> và với một endpoint công khai thì an toàn thắng. Nếu tôi trả lời khác nhau cho
> "sai scheme" và "sai token", tôi đã vô tình xác nhận cho kẻ dò rằng phần định
> dạng của họ đã đúng và giờ chỉ còn thiếu đúng giá trị token. Biến một phép đoán
> mù thành một cuộc tìm kiếm có định hướng chính là món quà lớn nhất tôi có thể
> tặng họ.
>
> Người dùng hợp lệ gần như không mất gì: họ có tài liệu, có ví dụ curl, và lỗi
> của họ thường là quên header — thứ mà `WWW-Authenticate: Bearer` đã trả lời sẵn.
> Cùng logic đó, tôi so token bằng `secrets.compare_digest` chứ không phải `==`:
> `==` dừng ở ký tự đầu tiên khác nhau nên thời gian trả lời cũng là một dạng
> thông báo rò rỉ, chỉ là rò qua đồng hồ thay vì qua chữ.

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> Tôi chạy thử đúng kịch bản này bằng `fakeredis`, cho client tiêu cạn xô ở thời
> điểm t=0 rồi bắn liên tiếp ở t=600 giây:
>
> ```
> CÓ chặn trần min(capacity, ...):  10 request rồi 429
> BỎ chặn trần:                    100 request rồi 429
> ```
>
> **Vì sao 10:** trong 600 giây, tốc độ nạp 10 token/phút sinh ra đúng 100 token.
> Nhưng `min(float(self.capacity), tokens)` vứt bỏ mọi thứ vượt quá sức chứa, nên
> xô đầy ở mức 10 và dừng ở đó — im lặng thêm một ngày cũng vẫn là 10.
>
> **Vì sao 100:** bỏ chặn trần thì token cộng dồn không giới hạn. Im lặng 10 phút
> thành 100 token, im lặng một ngày thành 14.400 token, và toàn bộ số đó bắn ra
> được trong một giây.
>
> Đây chính là chỗ `capacity` và `refill_per_minute` chia nhau hai vai trò khác
> nhau, và tôi nghĩ đó là ý hay nhất của thuật toán này. `refill_per_minute` quy
> định **tốc độ trung bình dài hạn**, còn `capacity` quy định **mức bùng tối đa
> trong một khoảnh khắc**. Tách được hai thứ đó nên token bucket vừa chiều được
> người dùng thật — im lặng một lúc rồi bấm liên tiếp mấy cái — vừa chặn được kẻ
> gọi không nghỉ. Bỏ chặn trần là mất vế thứ hai: đúng cái loại client nguy hiểm
> nhất (nằm im tích lũy rồi dội một phát) lại là loại được thưởng.

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> Hai hạn mức nhìn thì tương đương — $1/ngày × 30 ngày = $30/tháng — nhưng hành
> vi lúc có sự cố thì khác hẳn.
>
> **Hạn mức $30/tháng.** Sự cố bắt đầu 2h sáng, không có cái gì chặn ở mức ngày
> nên nó cứ chạy. Thiệt hại tối đa là **trọn $30**, tức toàn bộ ngân sách tháng,
> và tiêu hết trong một đêm nếu tốc độ gọi đủ cao. Tệ hơn là chuyện xảy ra sau
> đó: quota đã cạn nên **mọi** request hợp lệ của client đó đều bị 402 cho tới
> ngày 1 tháng sau. Nếu sự cố rơi vào ngày 3, service của client đó chết 28 ngày.
> Không có cơ chế tự hồi phục nào — phải có người tỉnh dậy, phát hiện, rồi nâng
> quota bằng tay.
>
> **Hạn mức $1/ngày.** Cũng sự cố đó, cũng 2h sáng, nhưng chặn lại ở **$1**.
> Đến 00:00 UTC khóa Redis đổi sang ngày mới — trong code là
> `spend:<client>:<ngày>`, mỗi ngày một khóa khác nhau — nên hạn mức tự làm mới,
> service tự sống lại sau vài giờ mà không cần ai can thiệp. Khóa cũ có TTL 3
> ngày nên cũng tự dọn, vẫn đủ thời gian để đối soát xem đêm qua chuyện gì đã xảy
> ra.
>
> Rút gọn thành một câu: hạn mức tháng giới hạn *tổng* chi tiêu, hạn mức ngày
> giới hạn *thiệt hại của một sự cố*, và cái thứ hai mới là thứ cứu bạn lúc 2h
> sáng. Nó ép mức tệ nhất xuống còn 1/30 và biến "gọi người dậy xử lý" thành "sáng
> mai đọc log".

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Diễn biến nếu gộp làm một và cho nó ping Redis:
>
> 1. **t=0s** — Redis mất kết nối. Cả 3 container vẫn khỏe: tiến trình sống, RAM
>    bình thường, code không lỗi.
> 2. **t=0s** — endpoint gộp gọi `store.ping()`, thất bại, trả 503. Vì cả 3
>    container cùng nói chuyện với một Redis nên **cả 3 cùng trả 503 một lúc**.
> 3. **t≈0–15s** — orchestrator đọc 503 ở liveness probe, đếm đủ số lần thất bại
>    liên tiếp.
> 4. **t≈15s** — orchestrator kết luận cả 3 container đều hỏng và **giết cả 3**.
>    Mọi request đang xử lý dở bị cắt ngang giữa chừng.
> 5. **t≈15–40s** — 3 container khởi động lại từ đầu. Trong lúc này năng lực phục
>    vụ bằng **không**, kể cả với những request chẳng cần Redis.
> 6. **t=30s** — Redis trở lại. Nhưng container vẫn đang khởi động, chưa kịp phục
>    vụ.
> 7. **t≈40–60s** — container lên xong, bắt đầu nhận traffic trở lại.
>
> Một sự cố Redis dài 30 giây bị khuếch đại thành gián đoạn dịch vụ khoảng 45–60
> giây, và toàn bộ phần khuếch đại đó do chính health check tự gây ra. Nếu Redis
> chập chờn — mất rồi có, có rồi mất — cụm rơi vào vòng lặp restart và không bao
> giờ ổn định lại được.
>
> **Tách đôi thì diễn biến khác hẳn:** `/healthz` vẫn trả 200 vì tiến trình thật
> sự còn sống, nên không container nào bị giết. `/readyz` trả 503, load balancer
> ngừng đẩy request mới vào — nhưng container vẫn đứng đó, giữ nguyên kết nối,
> không mất thời gian khởi động lại. Đúng 30 giây sau Redis về, `/readyz` trả 200
> trở lại và traffic chảy tiếp gần như tức thì.
>
> Nguyên tắc tôi rút ra: hai probe trả lời hai câu hỏi khác nhau và hậu quả của
> việc trả lời sai cũng khác nhau. `/readyz` sai thì traffic đi vòng sang chỗ
> khác — nhẹ, đảo ngược được. `/healthz` sai thì container bị giết — nặng, không
> đảo ngược. Vì vậy `/healthz` phải là câu hỏi dễ nhất có thể trả lời: "tiến trình
> này còn sống không?", và tuyệt đối không phụ thuộc thứ gì bên ngoài.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi: deploy báo SUCCESS nhưng gọi vào toàn 502.**
>
> Thông báo nhận được khi curl vào URL công khai:
>
> ```json
> {"status":"error","code":502,"message":"Application failed to respond","request_id":"VmSOeY6SSyaRxZKLLPU1MQ"}
> ```
>
> Chỗ khó chịu là mọi thứ khác đều báo bình thường: Railway ghi deployment
> SUCCESS, và healthcheck nội bộ của Railway gọi `/healthz` trả 200 OK. Nghĩa là
> app sống và phục vụ được — chỉ có đường từ ngoài vào là đứt.
>
> **Cách tìm ra nguyên nhân.** Tôi chạy `railway logs --service chat --deployment`
> và đọc được dòng quyết định:
>
> ```
> INFO:     Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
> INFO:     100.64.0.2:56873 - "GET /healthz HTTP/1.1" 200 OK
> ```
>
> App đang nghe cổng **8080**. Trong khi `railway domain list` cho thấy domain
> trỏ vào cổng **8000**. Railway tiêm biến `PORT=8080` lúc chạy, và điều làm tôi
> mất thời gian nhất là **biến này không hề xuất hiện trong `railway variables`**
> — nó được gán động lúc khởi động chứ không nằm trong danh sách biến của service,
> nên nhìn vào cấu hình thì không thấy gì sai cả.
>
> **Cách sửa:** cho domain trỏ đúng cổng app đang nghe.
>
> ```bash
> railway domain update chat-production-330f.up.railway.app --port 8080 --service chat
> ```
>
> Sau đó `/healthz` trả 200, `/readyz` trả `{"status":"ready","redis":true}`,
> `/chat` không token trả 401 và có token trả 200.
>
> **Điều tôi học được.** Đây đúng là lý do bài lab bắt app đọc `$PORT` thay vì cố
> định 8000: platform tự quyết định cổng, và app phải nghe theo chứ không được áp
> đặt. App của tôi làm đúng phần đó — nó đọc `$PORT` và nghe 8080 như được bảo.
> Sai sót nằm ở chỗ tôi tạo domain với `--port 8000` theo thói quen từ máy mình,
> tức là tôi đã hardcode ở *tầng hạ tầng* đúng cái mà tôi cẩn thận không hardcode
> ở tầng code.
>
> Bài học thứ hai là về cách đọc lỗi: "SUCCESS nhưng 502" tưởng mâu thuẫn, thật
> ra là một manh mối rất cụ thể — nó nói rằng vấn đề không nằm ở app mà nằm ở
> đường đi tới app. Healthcheck nội bộ chạy được còn đường ngoài thì không, nghĩa
> là khác biệt phải nằm ở lớp định tuyến. Log runtime trả lời trong 30 giây, còn
> đọc lại code thì có đọc cả ngày cũng không ra, vì code không sai.
