FROM python:3.12-slim AS runtime

WORKDIR /app

# System deps for opencv-python-headless / pillow
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
  && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY . /app/preset_service

EXPOSE 8000

CMD ["uvicorn", "preset_service.app:app", "--host", "0.0.0.0", "--port", "8000"]

