FROM python:3.12-slim

WORKDIR /transport
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/transport

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

RUN groupadd --system transport && \
    useradd --system --gid transport --no-create-home --shell /usr/sbin/nologin transport
USER transport:transport

EXPOSE 8081
CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8081"]
