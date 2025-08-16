# Use official Node.js runtime as base image
FROM node:18-alpine

# Set working directory in container
WORKDIR /app

# Create a non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# Copy package.json and package-lock.json first (for better caching)
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

# Create public directory if it doesn't exist
RUN mkdir -p public

# Set proper permissions
RUN chown -R nodeuser:nodejs /app && \
    chmod 755 /app

# Create volume for persistent data (users.csv and any logs)
VOLUME ["/app/data"]

# Copy users.csv to data volume location if it doesn't exist
RUN mkdir -p /app/data && \
    if [ ! -f /app/data/users.csv ]; then cp /app/users.csv /app/data/users.csv 2>/dev/null || true; fi

# Switch to non-root user
USER nodeuser

# Expose port 3000
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "const http = require('http'); \
    const options = { hostname: 'localhost', port: 3000, path: '/', method: 'GET' }; \
    const req = http.request(options, (res) => { \
        if (res.statusCode === 200) { process.exit(0); } else { process.exit(1); } \
    }); \
    req.on('error', () => process.exit(1)); \
    req.end();"

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Start the application
CMD ["node", "app.js"]