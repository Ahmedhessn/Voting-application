FROM node:18-slim

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 4000

ENV PORT=4000

CMD ["node", "server.js"]

