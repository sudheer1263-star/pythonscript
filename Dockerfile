FROM python:3.11-slim

WORKDIR /app

COPY honda.py .

CMD ["python", "honda.py"]
