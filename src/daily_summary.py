import csv

with open('data/staging/orders_clean.csv', newline='') as f:
    #เปิด data/staging/orders_clean.csv ด้วย csv.DictReader
    reader = csv.DictReader(f)
    print(type(reader))


    summary = {}
    for row in reader:
        #order_id,customer_id,amount,status,created_at,updated_at <- column
        order_id = row['order_id']
        customer_id = row['customer_id']
        amount = float(row['amount'])
        status = row['status']
        order_date = row['created_at'][:10]
        update_at = row['updated_at']
        
        print(amount)
        if order_date not in summary.keys():
            summary[order_date] = {'count':0,'amount':0}
            summary[order_date]['count'] += 1
            summary[order_date]['amount'] += amount
            
        else:
            summary[order_date]['count'] += 1
            summary[order_date]['amount'] += amount
    final_list= []
    
    for date,count_rvn in summary.items():
        final_dict= {}
        if date not in final_list:
            final_dict['order_date'] = date
            for key,value in count_rvn.items():
                if key not in final_dict.items():
                    final_dict[key] = summary[date][key]
                    
        final_list.append(final_dict)



    print(final_list)
    with open('data/serving/daily_orders_summary.csv', "w", newline="") as w:
        write =csv.DictWriter(w, fieldnames= ['order_date','count','amount'])
        write.writeheader()
        write.writerows(final_list)
