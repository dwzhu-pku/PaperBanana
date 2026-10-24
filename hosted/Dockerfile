FROM python:3.12-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    MPLCONFIGDIR=/tmp/matplotlib \
    PIP_DISABLE_PIP_VERSION_CHECK=1

COPY requirements.txt /tmp/requirements.txt
COPY hosted/requirements.txt /tmp/hosted-requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt -r /tmp/hosted-requirements.txt

COPY . /app
RUN mkdir -p /var/paperbanana/local /var/paperbanana/bucket \
    && useradd --create-home --uid 1000 user \
    && chown -R user:user /app /var/paperbanana

USER user
EXPOSE 7860
CMD ["python", "-m", "uvicorn", "hosted.app:app", "--host", "0.0.0.0", "--port", "7860", "--workers", "1"]
