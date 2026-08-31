import csv
import logging
from datetime import datetime
import os

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    filename='logs/pipeline.log',
    filemode='a',
)
logger = logging.getLogger(__name__)

WATERMARK_FILE = 'data/staging/_watermark.txt'
RAW_FILE = 'data/raw/orders_raw.csv'
CLEAN_FILE = 'data/staging/orders_clean.csv'

def read_watermark():
    if os.path.exists(WATERMARK_FILE):
        with open(WATERMARK_FILE) as wf:
            watermark = wf.read().strip()
    else:
        watermark = '1900-01-01 00:00:00'

    logger.info(f'watermark เดิม: {watermark}')
    return watermark

def write_watermark(new_watermark):
    with open(WATERMARK_FILE, 'w') as wf:
        wf.write(new_watermark)
        logger.info(f'watermark ใหม่: {new_watermark}')

def extract(path):
    with open(path,newline='') as f:
        reader = csv.DictReader(f)
        return list(reader)

def deduplicate(rows, watermark):
    dupe_id_check = {}
    for row in rows:
            order_id = row['order_id']
            
            updated_at = row['updated_at']
    
            if updated_at <= watermark:
                continue 
                
            is_dirty = False
    
           # check dupe 
           
            if order_id not in dupe_id_check:
                dupe_id_check[order_id] = row
            else:
                if updated_at > dupe_id_check[order_id]['updated_at']:
                    dupe_id_check[order_id] = row

    return dict(dupe_id_check)

def validate_row(row):
    order_id = row['order_id']
    customer_id = row['customer_id']
    amount = row['amount']
    status = row['status']
    created_at = row['created_at']
    updated_at = row['updated_at']
    is_dirty = False
    for col,value in row.items():
        if value == '' or value == 'N/A':
            is_dirty = True
            
    
                # make sure amount was number
    
        try:
            if amount:
    
                del_comma = amount.replace(',','')
                to_flt = float(del_comma)
                row['amount'] = del_comma
                if to_flt < 0:
                    is_dirty = True
                    
    
                else:
                    logger.info(f'{row!r} -> แปลงสำเร็จ: {row}')
        except ValueError:
            logger.error(f'{row!r} -> แปลงไม่ได้ (ValueError) แต่โปรแกรมไม่ crash!')
            
            is_dirty = True
    
            #datetime 2026-06-01 09:12:0
        try:
                datetime.strptime(created_at, "%Y-%m-%d %H:%M:%S")
                datetime.strptime(updated_at, "%Y-%m-%d %H:%M:%S")
        except ValueError:
                
                is_dirty = True
    
    return is_dirty, row

def load(rows, path):
    if not rows:
        logger.info('ไม่มี row ใหม่ให้เขียน (rows ว่าง) ข้าม load')
        return

    file_exists = os.path.exists(path)
        
    with open(path,'a', newline='') as out:
            write = csv.DictWriter(out, fieldnames=rows[0].keys())
            if not file_exists:
                write.writeheader()
            write.writerows(rows)

def main():
    watermark = read_watermark()
    raw_rows = extract(RAW_FILE)
    deduped = deduplicate(raw_rows, watermark)

    clean_rows = []
    dirty_rows = []
    for row in deduped.values():
        is_dirty, row = validate_row(row)
        (dirty_rows if is_dirty else clean_rows).append(row)

    if deduped:
        write_watermark(max(r['updated_at'] for r in deduped.values()))

    load(clean_rows, CLEAN_FILE)

if __name__ == '__main__':
    main()
