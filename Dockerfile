FROM lacework/codesec:latest

USER root

# Set up Azure DevOps integration scripts
WORKDIR /app/azure-integration

# Install dependencies (better Docker layer caching)
COPY scripts/package.json scripts/package-lock.json ./
RUN npm install && npm install typescript

# Copy and compile TypeScript
COPY scripts/tsconfig.json scripts/index.ts scripts/azure-devops.ts scripts/util.ts ./
COPY scripts/sanitize-markdown.py ./
RUN npx tsc

# Copy scan orchestration script
COPY scan.sh /app/scan.sh
RUN chmod +x /app/scan.sh

# Stay as root for write access to Azure DevOps mounted workspace (git checkout).
# Set HOME=/app so the lacework CLI finds its pre-installed components.
ENV HOME=/app
WORKDIR /app

ENTRYPOINT ["/app/scan.sh"]
