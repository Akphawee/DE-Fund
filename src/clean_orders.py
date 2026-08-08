"""
Clean Orders Pipeline (WORK IN PROGRESS -- Day 4)

สถานะ: ยังไม่เสร็จ
- [x] อ่าน CSV
- [x] เช็ค duplicate order_id
- [x] เช็ค null (มี bug ที่รู้แล้วแต่ยังไม่แก้ -- ดู note ด้านล่าง)
- [ ] แปลง amount เป็น float (มี comma, N/A, ค่าติดลบ ต้อง handle)
- [ ] แปลง created_at/updated_at เป็น datetime
- [ ] รวม logic ทั้งหมดเป็น filter เดียว -> เขียน clean output
- [ ] logging

KNOWN BUG (ยังไม่แก้): null-check loop ปัจจุบัน append row ซ้ำถ้ามีมากกว่า 1
column ว่างในแถวเดียวกัน เพราะ loop เจอค่าว่างกี่ครั้งก็ append กี่ครั้ง
ข้อมูลชุดทดสอบตอนนี้ไม่มีแถวไหนว่าง 2 column พร้อมกันเลยไม่ trigger
ให้เห็น แต่เป็นความเสี่ยงจริงกับข้อมูลจริง แก้โดยเช็คแค่ครั้งเดียวต่อแถว
(any(value == '' for value in row.values()))
"""
import csv

with open('data/raw/orders_raw.csv', newline='') as f:
    reader = csv.DictReader(f)

    dupe_id_check = {}
    null_row = []
    wrong_num_type = []
    wrong_date_time = []

    for row in reader:
        order_id = row['order_id']
        customer_id = row['customer_id']
        amount = row['amount']
        status = row['status']
        created_at = row['created_at']
        updated_at = row['updated_at']

        # check dupe
        if order_id not in dupe_id_check:
            dupe_id_check[order_id] = 0
        else:
            dupe_id_check[order_id] += 1

        # check null
        for col, value in row.items():
            if value == '':
                null_row.append(row)

        # TODO: make sure amount is a valid number (float, handle comma/N-A/negative)
        # TODO: make sure created_at / updated_at parse as valid datetime

    print(dupe_id_check)
    print(null_row)
