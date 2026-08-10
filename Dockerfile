# ═══════════════════════════════════════════════════════════════════
# Image production cho chat service — multi-stage.
#
# Ý tưởng: mọi thứ cần để CÀI thư viện (compiler, header, cache pip) chỉ
# tồn tại ở stage `builder` và bị vứt đi. Stage runtime chỉ nhận đúng cái
# virtualenv đã cài xong, nên image nhỏ và bề mặt tấn công hẹp.
#
# Build thử: docker build -t day12-chat:prod .
#            docker images day12-chat:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ─── Stage 1: builder ──────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /app

# Cài dependency TRƯỚC khi copy source. Docker cache theo layer: sửa một
# dòng trong app/ không đụng tới layer này, nên build lại chỉ mất vài giây
# thay vì cài lại toàn bộ thư viện.
COPY requirements.txt .
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ─── Stage 2: runtime ──────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# PYTHONUNBUFFERED: log phải ra stdout ngay, không nằm chờ trong buffer —
# nếu không, cloud chỉ thấy log khi container đã chết.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000

# curl chỉ để phục vụ HEALTHCHECK bên dưới; xoá apt list ngay trong cùng
# layer để phần cache đó không nằm lại trong image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Chạy bằng user thường: ai thoát được khỏi app cũng chỉ là `app`, không
# phải root. Container chạy root + một lỗ hổng escape = root trên host.
RUN useradd --create-home --uid 10001 app

WORKDIR /app

# Chỉ mang sang virtualenv đã cài xong — không compiler, không cache pip
COPY --from=builder /opt/venv /opt/venv
COPY --chown=app:app app ./app
COPY --chown=app:app utils ./utils

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/healthz" || exit 1

# Cổng đọc từ biến môi trường: Railway/Render tự gán PORT lúc chạy, hardcode
# 8000 là container nghe nhầm cổng và bị platform coi như chết.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
