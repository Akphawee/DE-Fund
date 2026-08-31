import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from clean_order import validate_row


def test_negative_amount_is_dirty():
    row = {
        'order_id': 'O001',
        'customer_id': 'C01',
        'amount': '-50.00',
        'status': 'paid',
        'created_at': '2026-06-01 09:12:00',
        'updated_at': '2026-06-01 09:12:00',
    }
    is_dirty, result = validate_row(row)
    assert is_dirty is True


def test_null_field_is_dirty():
    row = {
        'order_id': 'O002',
        'customer_id': '',
        'amount': '100.00',
        'status': 'paid',
        'created_at': '2026-06-01 09:12:00',
        'updated_at': '2026-06-01 09:12:00',
    }
    is_dirty, result = validate_row(row)
    assert is_dirty is True


def test_clean_row_is_not_dirty():
    row = {
        'order_id': 'O003',
        'customer_id': 'C03',
        'amount': '100.00',
        'status': 'paid',
        'created_at': '2026-06-01 09:12:00',
        'updated_at': '2026-06-01 09:12:00',
    }
    is_dirty, result = validate_row(row)
    assert is_dirty is False
