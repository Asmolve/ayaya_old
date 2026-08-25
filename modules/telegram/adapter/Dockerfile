FROM python:3.12-slim AS base

WORKDIR /adapter
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY adapter/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

FROM base AS production

RUN groupadd --system adapter && \
    useradd --system --gid adapter --no-create-home --shell /usr/sbin/nologin adapter

COPY --chown=adapter:adapter adapter/app ./app

USER adapter:adapter

EXPOSE 8080
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]

# Keep this final stage as the Dockerfile default so `docker build` followed by
# `docker run` executes the adapter contract suite without bind-mounted files.
FROM base AS test

ENV PYTHONPATH=/adapter

COPY adapter/requirements-test.txt ./
RUN pip install --no-cache-dir -r requirements-test.txt

COPY adapter/app ./app
COPY adapter/tests ./tests
COPY adapter/Dockerfile ./Dockerfile
COPY module.yml /module.yml
COPY compose.yml /compose.yml

CMD ["pytest", "-q"]
