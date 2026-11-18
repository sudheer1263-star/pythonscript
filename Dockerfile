FROM python:3.11-slim

WORKDIR /honda

COPY honda.py .

CMD ["python", "honda.py"]
