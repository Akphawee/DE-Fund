import csv
from datetime import datetime


with open('data/raw/orders_raw.csv', newline='') as f:
    reader = csv.DictReader(f) 
    print(reader) # i just want to see what the full one looks like it return this <csv.DictReader object at 0x0000023AD9199010> from what i remember its like i need to add another method to read this 


    '''
    1. check null (every row)
    2. check duplicate (order_id)
    3. make sure number column is float 
    4. make sure date time column is right (created at, updated at)
    '''
    '''
    actual step(row-based so only one loop needed)
    1.check null in every column
    2.if row = <col> THEN -> step
        2.1 
    '''
    '''for row in reader:
        order_id = row['order_id']
        customer_id = row['customer_id']
        amount = row['amount']
        status = row['status']
        created_at = row['created_at']
        updated_at = row['updated_at']
    '''
    # 1.
    dupe_id_check = {}
    null_row = []
    wrong_num_type = []
    wrong_date_time = []
    dirty_rows = []
    clean_rows = []

    for row in reader:
        order_id = row['order_id']
        customer_id = row['customer_id']
        amount = row['amount']
        status = row['status']
        created_at = row['created_at']
        updated_at = row['updated_at']

        is_dirty = False

       # check dupe 
        '''
        review : shorter idiom is using .get() -> return deault if no key yet
        for example   dupe_id_check[order_id] = dupe_id_check.get(order_id,0) + 1

        magic sum: so get() method is retrieving both exist or non existing key form dict
                    syntax = get(key, default)

                    OR

                    use Counter() <- it could count everything fr
        '''
        if order_id not in dupe_id_check:
            dupe_id_check[order_id] = 0
        else:
            dupe_id_check[order_id] += 1
            is_dirty = True


        # check null
        '''
        review : use list comprehension -> if any(value='' for value in row.values()):

        my sum: so use list com can reduce line of code and time to loop(just check it all at once) 
        '''
        
        for col,value in row.items():
            if value == '' or value == 'N/A':
                is_dirty = True
                null_row.append(row)

            # make sure amount was number
          
            
        try:
            if amount:
                
                del_comma = amount.replace(',','')
                to_flt = float(del_comma)
                if to_flt < 0:
                    is_dirty = True                    
                    wrong_num_type.append(row)

                else:
                    print(f'{row!r} -> แปลงสำเร็จ: {row}')
        except ValueError:
            print(f'{row!r} -> แปลงไม่ได้ (ValueError) แต่โปรแกรมไม่ crash!')
            wrong_num_type.append(row)
            is_dirty = True





   
    
        #datetime 2026-06-01 09:12:0
        try:
            datetime.strptime(created_at, "%Y-%m-%d %H:%M:%S")
            datetime.strptime(updated_at, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            wrong_date_time.append(row)
            is_dirty = True

        
        
        if is_dirty:
            dirty_rows.append(row)
        else:
            clean_rows.append(row)
            
        
    print(dupe_id_check)
 
    print(null_row)

    print(wrong_num_type)

    print(null_row) 

    print(wrong_date_time)

    with open('data/staging/orders_clean.csv','w', newline='') as out:
        write = csv.DictWriter(out, fieldnames=reader.fieldnames)
        write.writeheader()
        write.writerows(clean_rows)
    


             




        