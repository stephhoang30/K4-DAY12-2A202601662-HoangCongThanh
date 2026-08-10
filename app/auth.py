"""CP3 — Xác thực bằng Bearer token.

Public URL = ai cũng gọi được. Không có lớp này, hóa đơn LLM của bạn do
người lạ quyết định.

Chuẩn dùng ở đây là **RFC 6750** — token đi trong header ``Authorization``:

    Authorization: Bearer <token>

Đây là cách mọi API lớn (GitHub, Stripe, OpenAI) nhận token, nên client viết
bằng ngôn ngữ nào cũng có sẵn thư viện hiểu nó.
"""

from __future__ import annotations

import secrets

from fastapi import Header, HTTPException, status

from .config import get_settings

ANONYMOUS_CLIENT = "anonymous"
SCHEME = "Bearer"


def verify_bearer_token(
    authorization: str | None = Header(default=None),
    x_client_id: str | None = Header(default=None),
) -> str:
    """Kiểm tra header ``Authorization``; trả về client_id nếu hợp lệ.

    Token so sánh bằng ``secrets.compare_digest`` chứ không phải ``==``:
    ``==`` dừng ngay tại ký tự đầu tiên khác nhau, nên thời gian trả lời rò rỉ
    thông tin về token và cho phép dò từng ký tự (timing attack).
    ``compare_digest`` luôn chạy hết chuỗi.

    Mọi trường hợp hỏng đều trả về **cùng một** thông báo. Nói rõ "sai scheme"
    hay "token không đúng" là tặng thông tin miễn phí cho người đang dò.

    client_id trả về là đơn vị để rate limit và tính chi phí.
    """
    scheme, _, token = (authorization or "").partition(" ")

    hop_le = (
        scheme.lower() == SCHEME.lower()
        and bool(token)
        # encode() để token có ký tự ngoài ASCII cũng không làm compare_digest
        # ném TypeError — request hỏng phải thành 401, không phải 500.
        and secrets.compare_digest(token.encode("utf-8"),
                                   get_settings().api_token.encode("utf-8"))
    )
    if not hop_le:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid or missing bearer token",
            # Bắt buộc theo chuẩn HTTP cho 401: nói cho client biết phải xác
            # thực kiểu gì.
            headers={"WWW-Authenticate": SCHEME},
        )

    return x_client_id or ANONYMOUS_CLIENT
