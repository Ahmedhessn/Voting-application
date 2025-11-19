FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    apache2-utils \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY make-data.py .
COPY generate-votes.sh .

RUN chmod +x generate-votes.sh

CMD ["./generate-votes.sh"]

