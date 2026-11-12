FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Render (and most PaaS hosts) inject the port to listen on via $PORT.
# Fall back to 8000 for local `docker run` usage.
ENV PORT=8000

EXPOSE 8000

# Use shell form so $PORT is expanded at runtime.
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT}
