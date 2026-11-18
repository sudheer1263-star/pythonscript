FROM python:3.11-slim

WORKDIR

COPY honda.py .

CMD ["python", "honda.py"]
