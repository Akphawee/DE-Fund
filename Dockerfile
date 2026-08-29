FROM python:3.13.14-slim
WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["python" , "src/clean_order.py"]
