FROM python:3.11-slim

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

RUN apt-get update && apt-get install -y \
    apache2-utils \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY make-data.py .
COPY generate-votes.sh .

RUN chmod +x generate-votes.sh && \
    chown -R appuser:appuser /app

USER appuser

CMD ["./generate-votes.sh"]

