FROM python:3.8.10

WORKDIR /app

# Intentionally vulnerable requirements
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]
