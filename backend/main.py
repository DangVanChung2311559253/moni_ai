from __future__ import annotations

import math
import json
import os
import asyncio
import hashlib
import re
import threading
import unicodedata
from collections import Counter
from contextlib import asynccontextmanager
from datetime import date as DateValue, timedelta
from pathlib import Path
from typing import Literal

import joblib
import httpx
import numpy as np
import pandas as pd
import torch
from fastapi import FastAPI, File, HTTPException, UploadFile
from prophet.serialize import model_from_json
from pydantic import BaseModel, Field, field_validator
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")
MODELS_DIR = BASE_DIR / "models"
PROPHET_PATH = MODELS_DIR / "expense_prophet_model.json"
ISOLATION_FOREST_PATH = MODELS_DIR / "expense_isolation_forest.joblib"
PHOBERT_PATH = MODELS_DIR / "expense_phobert_model"

VALID_CATEGORIES = {
    "Ăn uống",
    "Đi lại",
    "Nhà ở",
    "Học tập",
    "Mua sắm",
    "Giải trí",
    "Sức khỏe",
    "Hóa đơn",
    "Khác",
}

prophet_model = None
prophet_load_error: str | None = None
anomaly_model = None
anomaly_load_error: str | None = None
phobert_model = None
phobert_tokenizer = None
phobert_load_error: str | None = None
ocr_engine = None
ocr_load_error: str | None = None
ocr_lock = threading.Lock()


def load_models() -> None:
    global prophet_model, prophet_load_error
    global anomaly_model, anomaly_load_error

    try:
        if not PROPHET_PATH.exists():
            raise FileNotFoundError(f"Không tìm thấy {PROPHET_PATH.name}")
        prophet_model = model_from_json(PROPHET_PATH.read_text(encoding="utf-8"))
        prophet_load_error = None
    except Exception as exc:
        prophet_model = None
        prophet_load_error = str(exc)

    try:
        if not ISOLATION_FOREST_PATH.exists():
            raise FileNotFoundError(f"Không tìm thấy {ISOLATION_FOREST_PATH.name}")
        anomaly_model = joblib.load(ISOLATION_FOREST_PATH)
        anomaly_load_error = None
    except Exception as exc:
        anomaly_model = None
        anomaly_load_error = str(exc)


@asynccontextmanager
async def lifespan(_: FastAPI):
    load_models()
    # Warm both local Scan models once so the first mobile request does not
    # have to wait for model initialization.
    await asyncio.to_thread(_load_phobert)
    await asyncio.to_thread(_load_paddle_ocr)
    yield


app = FastAPI(
    title="Moni AI Backend",
    version="1.0.0",
    lifespan=lifespan,
)


class ForecastHistoryItem(BaseModel):
    date: DateValue
    amount: float = Field(gt=0)


class ForecastRequest(BaseModel):
    history: list[ForecastHistoryItem]
    forecast_days: Literal[7, 14, 30] = 30


class AnomalyTransaction(BaseModel):
    amount: float = Field(gt=0)
    category: str
    date: DateValue
    merchant: str = ""
    description: str = ""

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str) -> str:
        category = value.strip()
        if category not in VALID_CATEGORIES:
            raise ValueError("Danh mục không hợp lệ.")
        return category


class AnomalyHistoryItem(BaseModel):
    amount: float = Field(gt=0)
    category: str
    date: DateValue

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str) -> str:
        category = value.strip()
        if category not in VALID_CATEGORIES:
            raise ValueError("Danh mục không hợp lệ.")
        return category


class AnomalyRequest(BaseModel):
    transaction: AnomalyTransaction
    history: list[AnomalyHistoryItem]


class ChatWallet(BaseModel):
    id: str
    name: str
    balance: float


class AIChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=1000)
    current_date: DateValue
    wallets: list[ChatWallet] = Field(default_factory=list)
    finance_context: dict = Field(default_factory=dict)


class AIChatResponse(BaseModel):
    intent: Literal[
        "create_transaction",
        "get_daily_summary",
        "get_weekly_summary",
        "get_monthly_summary",
        "get_top_category",
        "compare_months",
        "get_budget_status",
        "get_wallet_balance",
        "get_saving_advice",
        "get_anomalies",
        "get_forecast",
        "unknown",
    ]
    transaction_type: Literal["expense", "income"] | None = None
    amount: float | None = None
    category: str | None = None
    merchant: str | None = None
    description: str | None = None
    wallet: str | None = None
    date: DateValue | None = None
    missing_fields: list[str] = Field(default_factory=list)
    requires_confirmation: bool = False
    message: str


class ScanResponse(BaseModel):
    merchant: str
    amount: float = Field(gt=0)
    date: DateValue
    category: str
    confidence: float = Field(ge=0, le=1)
    raw_text: str


scan_cache: dict[str, ScanResponse] = {}


@app.get("/")
def root():
    return {
        "app": "Moni AI Backend",
        "status": "running",
    }


@app.get("/health")
def health():
    chat_model = os.getenv("GEMINI_CHAT_MODEL", "gemini-3.5-flash-lite")
    return {
        "status": "ok",
        "models": {
            "prophet": "ready" if prophet_model is not None else "error",
            "isolation_forest": (
                "ready" if anomaly_model is not None else "error"
            ),
            "phobert": (
                "ready"
                if phobert_model is not None
                else ("error" if phobert_load_error else "lazy")
            ),
            "paddleocr": (
                "ready"
                if ocr_engine is not None
                else ("error" if ocr_load_error else "lazy")
            ),
            "gemini_chat": chat_model,
        },
    }


@app.post("/forecast")
def forecast(payload: ForecastRequest):
    if not payload.history:
        raise HTTPException(status_code=422, detail="Lịch sử chi tiêu đang rỗng.")
    if prophet_model is None:
        raise HTTPException(
            status_code=503,
            detail=f"Không thể tải model Prophet: {prophet_load_error}",
        )

    history_frame = pd.DataFrame(
        [{"ds": item.date, "y": item.amount} for item in payload.history]
    )
    history_frame["ds"] = pd.to_datetime(history_frame["ds"])
    history_frame = (
        history_frame.groupby("ds", as_index=False)["y"].sum().sort_values("ds")
    )

    all_days = pd.date_range(
        history_frame["ds"].min(), history_frame["ds"].max(), freq="D"
    )
    history_frame = (
        history_frame.set_index("ds")
        .reindex(all_days, fill_value=0)
        .rename_axis("ds")
        .reset_index()
    )

    available_days = len(history_frame)
    if available_days < 30:
        return {
            "success": False,
            "error_code": "insufficient_history",
            "available_days": available_days,
            "required_days": 30,
            "message": (
                f"Chưa đủ dữ liệu. Hiện có {available_days}/30 ngày lịch sử."
            ),
        }

    first_forecast_day = history_frame["ds"].max() + timedelta(days=1)
    future = pd.DataFrame(
        {
            "ds": pd.date_range(
                first_forecast_day, periods=payload.forecast_days, freq="D"
            )
        }
    )

    try:
        result = prophet_model.predict(future)
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"Lỗi chạy dự báo Prophet: {exc}"
        ) from exc

    predicted = np.maximum(result["yhat"].to_numpy(dtype=float), 0)
    lower = np.maximum(result["yhat_lower"].to_numpy(dtype=float), 0)
    upper = np.maximum(result["yhat_upper"].to_numpy(dtype=float), 0)

    predicted_total = float(predicted.sum())
    lower_total = float(lower.sum())
    upper_total = float(upper.sum())
    average_per_day = predicted_total / payload.forecast_days

    comparison_days = min(payload.forecast_days, len(history_frame))
    historical_average = float(history_frame["y"].tail(comparison_days).mean())
    trend_percent = (
        ((average_per_day - historical_average) / historical_average) * 100
        if historical_average > 0
        else 0
    )
    trend = (
        "increase"
        if trend_percent > 5
        else "decrease"
        if trend_percent < -5
        else "stable"
    )
    message = {
        "increase": "Chi tiêu sắp tới có xu hướng tăng.",
        "decrease": "Chi tiêu sắp tới có xu hướng giảm.",
        "stable": "Chi tiêu sắp tới tương đối ổn định.",
    }[trend]

    daily_forecast = [
        {
            "date": row.ds.date().isoformat(),
            "predicted_amount": round(float(yhat)),
            "lower_amount": round(float(yhat_lower)),
            "upper_amount": round(float(yhat_upper)),
        }
        for row, yhat, yhat_lower, yhat_upper in zip(
            result.itertuples(index=False), predicted, lower, upper
        )
    ]

    return {
        "success": True,
        "forecast_days": payload.forecast_days,
        "predicted_total": round(predicted_total),
        "average_per_day": round(average_per_day),
        "lower_total": round(lower_total),
        "upper_total": round(upper_total),
        "trend": trend,
        "trend_percent": round(trend_percent, 2),
        "message": message,
        "daily_forecast": daily_forecast,
    }


@app.post("/detect-anomaly")
def detect_anomaly(payload: AnomalyRequest):
    if not payload.history:
        raise HTTPException(status_code=422, detail="Lịch sử giao dịch đang rỗng.")

    transaction = payload.transaction
    history_amounts = np.array(
        [item.amount for item in payload.history], dtype=float
    )
    category_amounts = np.array(
        [
            item.amount
            for item in payload.history
            if item.category == transaction.category
        ],
        dtype=float,
    )
    user_average = float(history_amounts.mean())
    category_average = (
        float(category_amounts.mean())
        if len(category_amounts)
        else user_average
    )
    ratio_to_category = (
        transaction.amount / category_average if category_average > 0 else 0
    )
    ratio_to_user = (
        transaction.amount / user_average if user_average > 0 else 0
    )

    category_counts = Counter(item.category for item in payload.history)
    is_rare_category = category_counts[transaction.category] <= 1
    enough_history = len(payload.history) >= 20
    detection_mode = (
        "isolation_forest" if enough_history else "rule_based"
    )
    prediction = 1
    anomaly_score = 0.0

    if enough_history:
        if anomaly_model is None:
            raise HTTPException(
                status_code=503,
                detail=(
                    "Không thể tải model Isolation Forest: "
                    f"{anomaly_load_error}"
                ),
            )
        feature_frame = pd.DataFrame(
            [
                {
                    "log_amount": math.log1p(transaction.amount),
                    "day_of_week": transaction.date.weekday(),
                    "day_of_month": transaction.date.day,
                    "month": transaction.date.month,
                    "category": transaction.category,
                }
            ]
        )
        try:
            prediction = int(anomaly_model.predict(feature_frame)[0])
            anomaly_score = float(
                anomaly_model.decision_function(feature_frame)[0]
            )
        except Exception as exc:
            raise HTTPException(
                status_code=500,
                detail=f"Lỗi chạy Isolation Forest: {exc}",
            ) from exc

    category_rule = ratio_to_category >= 3
    user_rule = ratio_to_user >= (3 if enough_history else 5)
    is_anomaly = prediction == -1 or category_rule or user_rule

    if ratio_to_category >= 3:
        reason = (
            f"Khoản chi cao gấp {ratio_to_category:.1f} lần mức trung bình "
            f"của danh mục {transaction.category}."
        )
    elif ratio_to_user >= (3 if enough_history else 5):
        reason = (
            f"Khoản chi cao gấp {ratio_to_user:.1f} lần mức trung bình "
            "của toàn bộ giao dịch."
        )
    elif prediction == -1:
        reason = "Mẫu giao dịch khác biệt rõ so với dữ liệu model đã học."
    elif is_rare_category:
        reason = "Danh mục này hiếm xuất hiện trong lịch sử của bạn."
    else:
        reason = "Giao dịch phù hợp với thói quen chi tiêu hiện tại."

    strongest_ratio = max(ratio_to_category, ratio_to_user)
    if is_anomaly and (strongest_ratio >= 3 or anomaly_score < -0.1):
        severity = "high"
    elif is_anomaly and (strongest_ratio >= 2 or anomaly_score < 0):
        severity = "medium"
    elif is_anomaly:
        severity = "low"
    else:
        severity = "none"

    return {
        "success": True,
        "is_anomaly": is_anomaly,
        "anomaly_score": round(anomaly_score, 4),
        "severity": severity,
        "reason": reason,
        "category_average": round(category_average),
        "user_average": round(user_average),
        "amount_ratio": round(ratio_to_category, 2),
        "requires_confirmation": is_anomaly,
        "detection_mode": detection_mode,
        "message": (
            "Giao dịch này có dấu hiệu bất thường. Bạn vẫn muốn lưu?"
            if is_anomaly
            else "Không phát hiện dấu hiệu bất thường."
        ),
    }


SCAN_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "merchant": {"type": "string"},
        "amount": {"type": "number", "minimum": 0},
        "date": {"type": "string", "format": "date"},
        "category": {
            "type": "string",
            "enum": [
                "Ăn uống",
                "Đi lại",
                "Nhà ở",
                "Học tập",
                "Mua sắm",
                "Giải trí",
                "Sức khỏe",
                "Hóa đơn",
                "Khác",
            ],
        },
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        "raw_text": {"type": "string"},
    },
    "required": [
        "merchant",
        "amount",
        "date",
        "category",
        "confidence",
        "raw_text",
    ],
}


def _load_phobert() -> None:
    global phobert_model, phobert_tokenizer, phobert_load_error
    if phobert_model is not None or phobert_load_error is not None:
        return
    try:
        if not PHOBERT_PATH.exists():
            raise FileNotFoundError(f"Không tìm thấy {PHOBERT_PATH.name}")
        from transformers import AutoModelForSequenceClassification, AutoTokenizer

        phobert_tokenizer = AutoTokenizer.from_pretrained(
            PHOBERT_PATH,
            local_files_only=True,
        )
        phobert_model = AutoModelForSequenceClassification.from_pretrained(
            PHOBERT_PATH,
            local_files_only=True,
        )
        phobert_model.eval()
    except Exception as exc:
        phobert_model = None
        phobert_tokenizer = None
        phobert_load_error = str(exc)


def _load_paddle_ocr() -> None:
    global ocr_engine, ocr_load_error
    if ocr_engine is not None or ocr_load_error is not None:
        return
    try:
        # Torch must already be imported before Paddle on Windows. Loading
        # Paddle first can make torch/lib/shm.dll fail with WinError 127.
        os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
        from paddleocr import PaddleOCR

        ocr_engine = PaddleOCR(
            text_detection_model_name="PP-OCRv5_mobile_det",
            text_recognition_model_name="latin_PP-OCRv5_mobile_rec",
            use_doc_orientation_classify=False,
            use_doc_unwarping=False,
            use_textline_orientation=False,
            text_rec_score_thresh=0.35,
        )
        ocr_load_error = None
    except Exception as exc:
        ocr_engine = None
        ocr_load_error = str(exc)


def _normalize_scan_category(value: str) -> str:
    aliases = {
        "Di chuyển": "Đi lại",
        "Giáo dục": "Học tập",
        "Y tế": "Sức khỏe",
    }
    normalized = aliases.get(value.strip(), value.strip())
    valid = {
        "Ăn uống",
        "Đi lại",
        "Nhà ở",
        "Học tập",
        "Mua sắm",
        "Giải trí",
        "Sức khỏe",
        "Hóa đơn",
        "Khác",
    }
    return normalized if normalized in valid else "Khác"


def _detect_image_mime(data: bytes, filename: str | None) -> str | None:
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp"

    extension = Path(filename or "").suffix.lower()
    return {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".gif": "image/gif",
        ".webp": "image/webp",
    }.get(extension)


def _classify_scan_text(text: str) -> tuple[str | None, float]:
    _load_phobert()
    if phobert_model is None or phobert_tokenizer is None:
        return None, 0

    encoded = phobert_tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=256,
    )
    with torch.no_grad():
        probabilities = torch.softmax(phobert_model(**encoded).logits, dim=-1)[0]
    label_id = int(torch.argmax(probabilities).item())
    confidence = float(probabilities[label_id].item())
    label = phobert_model.config.id2label.get(label_id, "Khác")
    return _normalize_scan_category(str(label)), confidence


def _plain_text(value: str) -> str:
    normalized = unicodedata.normalize("NFD", value.lower())
    return "".join(
        char for char in normalized if unicodedata.category(char) != "Mn"
    ).replace("đ", "d")


def _run_local_ocr(image_bytes: bytes) -> tuple[list[str], list[float]]:
    _load_paddle_ocr()
    if ocr_engine is None:
        raise RuntimeError(ocr_load_error or "PaddleOCR chưa sẵn sàng.")

    import cv2

    encoded = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(encoded, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Không thể giải mã ảnh tải lên.")

    # Paddle predictors are not thread-safe. Serializing only the prediction
    # keeps parallel request parsing outside the critical section.
    with ocr_lock:
        predictions = list(ocr_engine.predict(image))

    texts: list[str] = []
    scores: list[float] = []
    for prediction in predictions:
        payload = prediction.json.get("res", {})
        page_texts = payload.get("rec_texts", [])
        page_scores = payload.get("rec_scores", [])
        for index, value in enumerate(page_texts):
            text = str(value).strip()
            if not text:
                continue
            texts.append(text)
            score = page_scores[index] if index < len(page_scores) else 0
            scores.append(min(1.0, max(0.0, float(score))))
    return texts, scores


_DATE_PATTERNS = (
    re.compile(r"\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b"),
    re.compile(r"\b(\d{1,2})[-/.](\d{1,2})[-/.](20\d{2})\b"),
)


def _parse_scan_date(lines: list[str]) -> DateValue:
    for line in lines:
        first = _DATE_PATTERNS[0].search(line)
        if first:
            try:
                return DateValue(
                    int(first.group(1)),
                    int(first.group(2)),
                    int(first.group(3)),
                )
            except ValueError:
                pass
        second = _DATE_PATTERNS[1].search(line)
        if second:
            try:
                return DateValue(
                    int(second.group(3)),
                    int(second.group(2)),
                    int(second.group(1)),
                )
            except ValueError:
                pass
    return DateValue.today()


def _scan_transaction_date() -> DateValue:
    """Use the recording day; the printed date is kept only in raw OCR text."""
    return DateValue.today()


_AMOUNT_PATTERN = re.compile(
    r"(?<!\d)(\d{1,3}(?:[.,\s]\d{3})+|\d{4,12}|\d+(?:[.,]\d+)?)"
    r"\s*(triệu|tr|nghìn|ngàn|k|vnd|vnđ|đ|d|dong)?\b",
    re.IGNORECASE,
)


def _money_value(number: str, suffix: str) -> float | None:
    compact = number.replace(" ", "")
    plain_suffix = _plain_text(suffix)
    multiplier = 1.0
    if plain_suffix in {"k", "nghin", "ngan"}:
        multiplier = 1_000.0
    elif plain_suffix in {"tr", "trieu"}:
        multiplier = 1_000_000.0

    if multiplier > 1:
        try:
            value = float(compact.replace(",", "."))
        except ValueError:
            return None
        return value * multiplier

    if re.fullmatch(r"\d{1,3}(?:[.,]\d{3})+", compact):
        compact = re.sub(r"[.,]", "", compact)
    else:
        compact = re.sub(r"[.,]", "", compact)
    try:
        value = float(compact)
    except ValueError:
        return None
    return value if value >= 1_000 else None


def _parse_scan_amount(lines: list[str]) -> tuple[float | None, float]:
    positive_words = (
        "tong thanh toan",
        "tong cong",
        "thanh tien",
        "so tien giao dich",
        "so tien",
        "s tien",
        "s tin",
        "da thanh toan",
        "thanh toan",
        "payment amount",
        "payment",
        "epayment",
        "vat included",
        "total",
        "amount",
        "thanh tin",
        "tng",
        "tng tien",
    )
    negative_words = (
        "so du",
        "balance",
        "phi giao dich",
        "fee",
        "ma giao dich",
        "ma giao dch",
        "transaction id",
        "tai khoan",
        "tai khon",
        "so th",
        "account",
        "trans#",
        "trans:",
        "transaction",
        "change",
        "tien thua",
        "current points",
        "receipt no",
        "eipt no",
        "invoice no",
        "bill no",
        "quay",
        "counter",
        "frans. id",
        "rans. id",
        "ma gd",
    )
    candidates: list[tuple[int, float, float]] = []
    for line_index, line in enumerate(lines):
        comparable = _plain_text(line)
        previous = _plain_text(lines[line_index - 1]) if line_index > 0 else ""
        context = f"{previous} {comparable}".strip()
        date_scrubbed = line
        for pattern in _DATE_PATTERNS:
            date_scrubbed = pattern.sub(" ", date_scrubbed)
        positive = next(
            (word for word in positive_words if word in context),
            None,
        )
        negative = any(word in context for word in negative_words)
        for match in _AMOUNT_PATTERN.finditer(date_scrubbed):
            value = _money_value(match.group(1), match.group(2) or "")
            if value is None or value > 10_000_000_000:
                continue
            score = 120 if positive else 30
            if match.group(2):
                score += 20
            digit_count = len(re.sub(r"\D", "", match.group(1)))
            if not match.group(2) and digit_count >= 9:
                score -= 80
            if negative:
                score -= 140
            parser_confidence = 0.96 if positive else (0.82 if match.group(2) else 0.68)
            candidates.append((score, value, parser_confidence))
    if not candidates:
        return None, 0
    value_counts = Counter(round(item[1], 2) for item in candidates)
    _, value, confidence = max(
        candidates,
        key=lambda item: (
            item[0] + min(value_counts[round(item[1], 2)] - 1, 3) * 12,
            item[2],
            item[1],
        ),
    )
    return value, confidence


def _parse_scan_merchant(lines: list[str]) -> str:
    joined = _plain_text(" ".join(lines))
    known_brands = (
        ("GS25", ("gs25", "gs25.com.vn")),
        ("CIRCLE K", ("circle k", "circlek")),
        ("PHUC LONG", ("phuc long",)),
        ("HIGHLANDS COFFEE", ("highlands",)),
    )
    for brand, markers in known_brands:
        if any(marker in joined for marker in markers):
            return brand

    labels = (
        "nguoi nhan",
        "ngui nhan",
        "ngui nhn",
        "ten nguoi nhan",
        "don vi chap nhan",
        "cua hang",
        "merchant",
        "payee",
    )
    for index, line in enumerate(lines):
        comparable = _plain_text(line)
        if any(label in comparable for label in labels):
            value = re.split(r"[:：-]", line, maxsplit=1)
            if len(value) == 2 and value[1].strip():
                return value[1].strip()[:120]
            for candidate in lines[index + 1 : index + 3]:
                candidate = candidate.strip()
                if candidate and len(_plain_text(candidate)) >= 3:
                    return candidate[:120]

    ignored = (
        "hoa don",
        "receipt",
        "thanh toan thanh cong",
        "giao dich thanh cong",
        "chi tiet giao dich",
        "chi tit giao dch",
        "cam on",
        "ngay",
        "date",
        "tong",
        "so tien",
        "momo",
        "zalopay",
        "vnpay",
        "vietqr",
    )
    for line in lines[:12]:
        comparable = _plain_text(line)
        if len(comparable) < 3 or any(word in comparable for word in ignored):
            continue
        if _AMOUNT_PATTERN.search(line) or any(
            pattern.search(line) for pattern in _DATE_PATTERNS
        ):
            continue
        return line.strip()[:120]
    return ""


def _fallback_scan_category(text: str) -> str:
    comparable = _plain_text(text)
    rules = {
        "Ăn uống": ("coffee", "cafe", "com", "pho", "tra sua", "an sang"),
        "Mua sắm": ("sieu thi", "sieu th", "di cho", "quan ao", "shopping"),
        "Đi lại": ("xang", "grab", "taxi", "bus", "ve xe"),
        "Hóa đơn": ("dien", "nuoc", "internet", "hoa don"),
        "Sức khỏe": ("thuoc", "benh vien", "kham"),
        "Học tập": ("hoc phi", "sach", "khoa hoc"),
        "Giải trí": ("phim", "game", "du lich"),
    }
    for category, words in rules.items():
        if any(word in comparable for word in words):
            return category
    return "Khác"


@app.post("/scan", response_model=ScanResponse)
async def scan_transaction(file: UploadFile = File(...)) -> ScanResponse:
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=422, detail="Ảnh tải lên đang trống.")
    if len(image_bytes) > 12 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Ảnh không được vượt quá 12 MB.")
    cache_key = hashlib.sha256(image_bytes).hexdigest()
    cached = scan_cache.get(cache_key)
    if cached is not None:
        return cached
    image_mime = (
        file.content_type
        if file.content_type and file.content_type.startswith("image/")
        else _detect_image_mime(image_bytes, file.filename)
    )
    if image_mime is None:
        raise HTTPException(
            status_code=415,
            detail="Tệp tải lên phải là ảnh JPG, PNG, GIF hoặc WEBP.",
        )

    try:
        lines, ocr_scores = await asyncio.to_thread(_run_local_ocr, image_bytes)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=f"PaddleOCR chưa thể đọc ảnh: {exc}",
        ) from exc

    if not lines:
        raise HTTPException(
            status_code=422,
            detail="Không đọc được chữ trong ảnh. Hãy chọn ảnh rõ và đủ sáng hơn.",
        )

    raw_text = "\n".join(lines)[:1200]
    amount, parser_confidence = _parse_scan_amount(lines)
    if amount is None or amount <= 0:
        raise HTTPException(
            status_code=422,
            detail=(
                "Đã đọc được chữ nhưng không xác định được số tiền chính. "
                "Hãy chụp rõ phần Tổng thanh toán hoặc chỉ chọn một giao dịch."
            ),
        )

    phobert_category, phobert_confidence = await asyncio.to_thread(
        _classify_scan_text,
        raw_text,
    )
    fallback_category = _fallback_scan_category(raw_text)
    category = (
        fallback_category
        if phobert_category in {None, "Khác"} and fallback_category != "Khác"
        else (phobert_category or fallback_category)
    )
    ocr_confidence = (
        sum(ocr_scores) / len(ocr_scores) if ocr_scores else 0.5
    )
    confidence = (
        ocr_confidence * 0.45
        + parser_confidence * 0.3
        + (phobert_confidence if phobert_category else 0.5) * 0.25
    )
    result = ScanResponse(
        merchant=_parse_scan_merchant(lines),
        amount=amount,
        # A scanned receipt becomes a transaction for the day it is recorded.
        # The printed receipt date remains available in raw_text and users can
        # still edit the date on Flutter's confirmation screen.
        date=_scan_transaction_date(),
        category=category,
        confidence=round(min(1.0, max(0.0, confidence)), 4),
        raw_text=raw_text,
    )
    if len(scan_cache) >= 50:
        scan_cache.pop(next(iter(scan_cache)))
    scan_cache[cache_key] = result
    return result


CHAT_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "intent": {
            "type": "string",
            "enum": [
                "create_transaction",
                "get_daily_summary",
                "get_weekly_summary",
                "get_monthly_summary",
                "get_top_category",
                "compare_months",
                "get_budget_status",
                "get_wallet_balance",
                "get_saving_advice",
                "get_anomalies",
                "get_forecast",
                "unknown",
            ],
        },
        "transaction_type": {
            "type": "string",
            "enum": ["expense", "income"],
            "nullable": True,
        },
        "amount": {"type": "number", "minimum": 0, "nullable": True},
        "category": {
            "type": "string",
            "enum": [
                "Ăn uống",
                "Đi lại",
                "Nhà ở",
                "Học tập",
                "Mua sắm",
                "Giải trí",
                "Sức khỏe",
                "Hóa đơn",
                "Khác",
                "Thu nhập",
            ],
            "nullable": True,
        },
        "merchant": {"type": "string", "nullable": True},
        "description": {"type": "string", "nullable": True},
        "wallet": {"type": "string", "nullable": True},
        "date": {"type": "string", "format": "date", "nullable": True},
        "missing_fields": {
            "type": "array",
            "items": {"type": "string"},
        },
        "requires_confirmation": {"type": "boolean"},
        "message": {"type": "string"},
    },
    "required": [
        "intent",
        "transaction_type",
        "amount",
        "category",
        "merchant",
        "description",
        "wallet",
        "date",
        "missing_fields",
        "requires_confirmation",
        "message",
    ],
}


def _chat_prompt(payload: AIChatRequest) -> str:
    wallet_data = [wallet.model_dump() for wallet in payload.wallets]
    return f"""
Bạn là Trợ lý tài chính Moni AI. Phân tích yêu cầu tiếng Việt và trả đúng JSON
theo schema, không thêm markdown hay văn bản ngoài JSON.

Ngày hiện tại: {payload.current_date.isoformat()}
Danh sách ví: {json.dumps(wallet_data, ensure_ascii=False)}
Ngữ cảnh tài chính đã tổng hợp, không chứa dữ liệu đăng nhập:
{json.dumps(payload.finance_context, ensure_ascii=False)}

Yêu cầu người dùng: {payload.message}

Quy tắc số tiền:
- Trong ngữ cảnh ghi chi/thu, số trần như "250" thường là 250000 VND.
- "35 nghìn", "35k" = 35000; "2 triệu", "2tr" = 2000000.
- Nếu có nhiều số tiền hoặc không xác định được, amount=null và thêm "amount"
  vào missing_fields. Không tự chọn một số.

Phân loại:
- cà phê, ăn sáng, cơm, trà sữa: Ăn uống
- đi chợ, siêu thị, quần áo: Mua sắm
- xăng, Grab, taxi: Đi lại
- điện, nước, Internet: Hóa đơn
- thuốc, khám bệnh: Sức khỏe
- học phí, sách, khóa học: Học tập
- phim, game, du lịch: Giải trí
- nhận lương, thưởng: category="Thu nhập", transaction_type="income"

Nếu intent=create_transaction:
- expense hoặc income, amount, category, description và date.
- Chỉ gán wallet bằng id ví nếu người dùng nói rõ và khớp duy nhất.
- Thiếu ví thì wallet=null, thêm "wallet" vào missing_fields.
- requires_confirmation=true chỉ khi amount hợp lệ; tuyệt đối không tự lưu.

Intent truy vấn hỗ trợ:
- get_daily_summary: hôm nay đã chi bao nhiêu
- get_weekly_summary: tuần này đã chi bao nhiêu
- get_monthly_summary: tổng quan tháng này
- get_top_category: danh mục chi nhiều nhất
- get_budget_status: trạng thái ngân sách
- get_wallet_balance: số dư ví
- compare_months: so sánh tháng này với tháng trước
- get_anomalies: khoản chi bất thường
- get_forecast: dự báo chi tiêu
- get_saving_advice: gợi ý tiết kiệm

Với intent truy vấn, dùng finance_context để trả lời ngắn gọn bằng tiếng Việt.
Nếu dữ liệu chưa đủ, nói rõ trong message. Nếu không hiểu, intent="unknown",
requires_confirmation=false và hướng dẫn ví dụ "Đi chợ 250 nghìn".
""".strip()


@app.post("/ai/chat", response_model=AIChatResponse)
async def ai_chat(payload: AIChatRequest) -> AIChatResponse:
    api_key = os.getenv("GEMINI_API_KEY", "").strip()
    model = os.getenv("GEMINI_CHAT_MODEL", "gemini-3.5-flash-lite").strip()
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail="Backend chưa được cấu hình GEMINI_API_KEY.",
        )

    request_body = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": _chat_prompt(payload)}],
            }
        ],
        "generationConfig": {
            "maxOutputTokens": 1200,
            "responseMimeType": "application/json",
            "responseSchema": CHAT_RESPONSE_SCHEMA,
        },
    }
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent"
    )

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                url,
                headers={
                    "Content-Type": "application/json",
                    "x-goog-api-key": api_key,
                },
                json=request_body,
            )
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=504, detail="Gemini phản hồi quá thời gian."
        ) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502, detail="Không thể kết nối Gemini."
        ) from exc

    if response.status_code < 200 or response.status_code >= 300:
        try:
            error_detail = response.json().get("error", {}).get("message")
        except ValueError:
            error_detail = None
        raise HTTPException(
            status_code=502,
            detail=error_detail or f"Gemini trả lỗi {response.status_code}.",
        )

    try:
        response_data = response.json()
        raw_text = response_data["candidates"][0]["content"]["parts"][0]["text"]
        parsed = json.loads(raw_text)
        for field_name in (
            "transaction_type",
            "amount",
            "category",
            "merchant",
            "description",
            "wallet",
            "date",
        ):
            if parsed.get(field_name) in ("", "null"):
                parsed[field_name] = None
        parsed.setdefault("missing_fields", [])
        parsed.setdefault("requires_confirmation", False)
        parsed.setdefault("message", "Mình chưa hiểu yêu cầu.")
        result = AIChatResponse.model_validate(parsed)
    except (KeyError, IndexError, TypeError, ValueError):
        return AIChatResponse(
            intent="unknown",
            requires_confirmation=False,
            message=(
                "Mình chưa hiểu rõ số tiền. Bạn chỉ nên nhập một khoản, "
                "ví dụ: Đi chợ 250 nghìn."
            ),
        )

    if result.intent == "create_transaction":
        missing = set(result.missing_fields)
        if result.amount is None or result.amount <= 0:
            missing.add("amount")
            result.requires_confirmation = False
        if not result.wallet:
            missing.add("wallet")
        if result.date is None:
            result.date = payload.current_date
        result.missing_fields = sorted(missing)
    else:
        result.requires_confirmation = False
    return result
