# SQL Mistake Log

บันทึกข้อผิดพลาดระหว่างฝึก เพื่อกันพลาดซ้ำ

## Week 1 Day 1

### 1. พิมพ์ชื่อตารางผิด (`customer` แทน `customers`) — เกิดซ้ำ 3 ครั้ง (ข้อ 2, 5, 10)

**สาเหตุ:** เดาชื่อตารางจากความคุ้นชิน (เอกพจน์) แทนที่จะเช็ค schema จริงก่อนพิมพ์
**บทเรียน:** เช็ค schema ก่อนเขียนทุกครั้ง โดยเฉพาะตอนเพิ่งเริ่มคุ้นกับ database ใหม่ — และถ้าพลาดจุดเดิมซ้ำ ให้สงสัยว่ามี pattern อะไรที่ยังไม่เช็คให้ครบ (ในเคสนี้แก้ query แรกแล้วไม่ได้ไล่เช็คชื่อตารางในข้อถัดไปที่เหลือด้วย)

### 2. สับสนระหว่าง DISTINCT กับ GROUP BY — พลาดคนละทิศทางในข้อ 5 และข้อ 8

- **ข้อ 5** (หา province ไม่ซ้ำ ไม่มีการคำนวณ): ใช้ `GROUP BY` ทั้งที่ไม่จำเป็น ควรใช้ `DISTINCT`
- **ข้อ 8** (หา category ที่ราคาเฉลี่ยสูงสุด ต้องคำนวณ AVG ต่อกลุ่ม): ใช้ `DISTINCT` ทั้งที่ต้องคำนวณ ทำให้ SQLite error `misuse of aggregate: AVG()`

**บทเรียน:** `DISTINCT` = ตัดค่าซ้ำเฉย ๆ ไม่มีการคำนวณ ส่วน `GROUP BY` = แบ่งกลุ่มเพื่อคำนวณอะไรสักอย่างต่อกลุ่ม (COUNT/SUM/AVG/MAX/MIN) — ก่อนเขียนต้องถามตัวเองก่อนว่า "ข้อนี้ต้องคำนวณอะไรไหม" ถ้าไม่ต้องคำนวณ = DISTINCT ถ้าต้องคำนวณต่อกลุ่ม = GROUP BY

### 3. ลืมใส่ column ที่ GROUP BY ไว้ใน SELECT (ข้อ 6)

`SELECT COUNT(*) FROM orders GROUP BY status` รันผ่านได้ผลลัพธ์ (10, 39, 11) แต่ไม่รู้ว่าตัวไหนคือ status ไหน เพราะไม่ได้ SELECT `status` มาด้วย
**บทเรียน:** เวลา GROUP BY คอลัมน์ไหน ควร SELECT คอลัมน์นั้นออกมาด้วยเสมอ ไม่งั้นผลลัพธ์อ่านไม่ออกว่าตัวเลขไหนคือกลุ่มไหน

## Week 1 Day 2

### 4. ลืมกรอง WHERE ก่อน aggregate — เกิดซ้ำใน Q10

ทำ CTE aggregate ยอดขายถูกแล้ว แต่ลืม `WHERE status = 'paid'` ใน step แรก ทำให้นับรวม order ที่ cancelled/pending เข้าไปด้วย ยอดขาย daily_total เพี้ยนสูงเกินจริง (2580 แทนที่จะเป็น 1150 ที่วันแรก)
**บทเรียน:** ก่อนเขียน aggregate ทุกครั้ง เช็คว่ามี business filter (เช่น "เฉพาะที่จ่ายสำเร็จ") ที่ต้องใส่ก่อนหรือเปล่า อย่าลืมแค่เพราะเปลี่ยนจาก SUM ธรรมดาไปเป็น CTE

### 5. ลืม DESC ใน ORDER BY ของ window function — เกิดซ้ำ 2 ครั้ง (province ranking, Q8 top products)

ORDER BY default เรียงจากน้อยไปมาก (ascending) พอไม่ใส่ DESC จะได้ "bottom N" แทน "top N" กลับด้านกับที่ต้องการ
**บทเรียน:** ทุกครั้งที่ทำ "top N" ต้องเช็คว่ามี DESC หรือยัง เป็น checklist ที่ต้องนึกถึงอัตโนมัติ เพราะพลาดจุดนี้ซ้ำแล้วซ้ำอีก

### 6. ใช้ WHERE กรอง window function alias ในระดับเดียวกัน — เกิดซ้ำ 2 ครั้ง (CTE lesson, Q4)

`SELECT ..., ROW_NUMBER() OVER (...) AS rn FROM ... WHERE rn = 1` error `misuse of aliased window function rn` เพราะ WHERE รันก่อน window function จะคำนวณเสร็จ
**บทเรียน:** window function ต้องคำนวณเสร็จในอีก step หนึ่งก่อน (CTE/subquery) แล้วค่อย filter จาก SELECT ชั้นนอก — จำ pattern "compute step → filter step" ให้ขึ้นใจ เพราะเป็นกฎที่ใช้ซ้ำบ่อยที่สุดในบรรดา window function ทั้งหมด

### 7. GROUP BY + column ที่ไม่ได้ aggregate → SQLite เงียบ ๆ หยิบค่ามาแบบสุ่ม — เกิดซ้ำ 2 ครั้ง (Q4, Q8, Q10)

`GROUP BY` แล้ว SELECT column อื่นที่ไม่ได้ห่อ aggregate function จะได้ค่า**สุ่ม**จากกลุ่มนั้นมา ไม่ error แต่ผิดแบบเงียบ ๆ (เช่น Q8 ได้ total_price=250 ทั้งที่ยอดจริงคือ 5500 ต่างกันเกือบ 22 เท่า!)
**บทเรียน:** นี่คือบั๊กที่อันตรายที่สุดในบรรดาที่เจอมา เพราะไม่มี error แจ้ง ต้อง**เช็คให้เป็นนิสัย**ว่าทุก column ใน SELECT ที่ไม่ได้อยู่ใน GROUP BY ต้องห่อด้วย SUM/COUNT/AVG/MAX/MIN เสมอ ไม่มีข้อยกเว้น

## Concept ที่เข้าใจผิดตอนแรก (แก้แล้ว)

**Grain ของ `order_items`:** ตอนแรกตอบว่า grain = "order" ซึ่งผิด — ตรวจสอบด้วยข้อมูลจริงแล้วพบว่า order เดียว (O002) มีได้หลาย row ใน `order_items` (3 แถว เพราะซื้อ 3 item) แปลว่า grain ที่ถูกต้องคือ **1 row = 1 item ที่ถูกซื้อ** ไม่ใช่ 1 order — เป็นเหตุผลว่าทำไม `COUNT(*)` บนตารางนี้ถึงนับ order ผิด (ได้ 144 ทั้งที่ order จริงมีแค่ 60) ต้องใช้ `COUNT(DISTINCT order_id)` แทน
