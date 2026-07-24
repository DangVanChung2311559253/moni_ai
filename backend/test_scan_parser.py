import unittest
from datetime import date

from main import (
    CHAT_RESPONSE_SCHEMA,
    _fallback_scan_category,
    _parse_scan_amount,
    _parse_scan_date,
    _parse_scan_merchant,
    _scan_transaction_date,
)


class ScanParserTest(unittest.TestCase):
    def test_receipt_total_beats_transaction_number_and_cash_change(self):
        lines = [
            "PHUC LONG",
            "Trans#: 74,358 Serv: Tan Buu",
            "Peach Black Tea Ice (L)",
            "55,000",
            "Total:",
            "55,000",
            "CASH",
            "Change",
            "100,000",
            "45,000",
        ]

        amount, confidence = _parse_scan_amount(lines)

        self.assertEqual(amount, 55_000)
        self.assertGreaterEqual(confidence, 0.9)

    def test_momo_ocr_variants_parse_amount_merchant_and_category(self):
        lines = [
            "Chi Tit Giao Dch",
            "THANH TOAN CHO CONG TY TNHH",
            "MAXIDI VIET NAM - 02028-01",
            "Ma giao dch",
            "131871702720",
            "Ngui nhn",
            "CONG TY TNHH MAXIDI VIET NAM - 02028-01",
            "S tin",
            "24.200d",
            "Danh mc",
            "Ch, sieu th",
        ]

        amount, _ = _parse_scan_amount(lines)

        self.assertEqual(amount, 24_200)
        self.assertEqual(
            _parse_scan_merchant(lines),
            "CONG TY TNHH MAXIDI VIET NAM - 02028-01",
        )
        self.assertEqual(_fallback_scan_category(" ".join(lines)), "Mua sắm")

    def test_text_without_money_remains_unresolved(self):
        amount, confidence = _parse_scan_amount(
            ["Thanh toán thành công", "Cảm ơn quý khách"]
        )

        self.assertIsNone(amount)
        self.assertEqual(confidence, 0)

    def test_circle_k_total_beats_receipt_and_transaction_ids(self):
        lines = [
            "CIRCLE K VIETN",
            "69 Ho Tung Mau. Dist 1.",
            "eipt No: 012 02 20190304 0652",
            "C.on",
            "15,000",
            "CK M.Noodle Egg*1POR",
            "9,000",
            "2,000",
            "Item(s)",
            "(VAT included)",
            "26,000",
            "ePayment",
            "26,000",
            "frans. ID: 2450337193",
        ]

        amount, confidence = _parse_scan_amount(lines)

        self.assertEqual(amount, 26_000)
        self.assertGreaterEqual(confidence, 0.9)
        self.assertEqual(_parse_scan_merchant(lines), "CIRCLE K")

    def test_gs25_total_beats_counter_and_product_codes(self):
        lines = [
            "Liên bán hàng",
            "14/04/2021",
            "Quây : VN001102-89",
            "Thành Tin",
            "Đon Giá",
            "S.Luong",
            "27,000",
            "Hotdog 25 Signature",
            "27,000",
            "2010805000363",
            "27,000",
            "Tng",
            "Chit kháu hóa đơn",
            "27,000",
            "Tng tiên",
            "27,000",
            "Loąi TT : Vi ZaloPay",
            "Android: https://gs25.com.vn/bill",
        ]

        amount, confidence = _parse_scan_amount(lines)

        self.assertEqual(amount, 27_000)
        self.assertGreaterEqual(confidence, 0.9)
        self.assertEqual(_parse_scan_merchant(lines), "GS25")

    def test_receipt_date_parser_remains_available_for_raw_ocr_review(self):
        self.assertEqual(
            _parse_scan_date(["Ngày hóa đơn: 14/04/2021"]),
            date(2021, 4, 14),
        )

    def test_scanned_transaction_uses_recording_day(self):
        self.assertEqual(_scan_transaction_date(), date.today())

    def test_chat_schema_supports_modern_financial_queries(self):
        intents = CHAT_RESPONSE_SCHEMA["properties"]["intent"]["enum"]

        self.assertIn("get_weekly_summary", intents)
        self.assertIn("get_top_category", intents)
        self.assertIn("get_forecast", intents)


if __name__ == "__main__":
    unittest.main()
