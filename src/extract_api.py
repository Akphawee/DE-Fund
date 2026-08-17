import requests
import json
from dotenv import load_dotenv
import os

load_dotenv()

url = os.environ.get('API_URL')
response = requests.get(url, timeout=5)
print(response.status_code)

if response.status_code == 200:
    data = []
    json_res = response.json()
    for obj in json_res:
        data.append(json.dumps(obj) + '\n')
        
    with open('data/raw/posts_raw.jsonl', 'w', newline= '\n') as out:
        out.writelines(data)
    print(len(json_res))
else:
    print(response.text)
            

