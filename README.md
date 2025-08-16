# 🐳 Docker Deployment Guide - Common Notepad

This guide covers how to deploy the Collaborative Text Editor using Docker containers.

## 🚀 Quick Start

### Prerequisites
- Docker installed
- Docker Compose installed (for production deployment)

### Files Required
Copy all these files from the artifacts:
```
common-notepad/
├── app.js                  # Updated Node.js server
├── public/
│   └── index.html         # Updated client code
├── package.json           # Dependencies
├── users.csv              # User credentials
├── Dockerfile             # Docker build instructions
├── docker-compose.yml     # Multi-container setup
├── nginx/
│   └── nginx.conf         # Nginx reverse proxy config
├── .dockerignore          # Docker build exclusions
└── docker-deploy.sh       # Automated deployment script
```

## 🎯 Deployment Options

### Option 1: Automated Script (Recommended)
```bash
chmod +x docker-deploy.sh
./docker-deploy.sh
```

Choose from:
1. **Quick start** - Node.js app only (port 3000)
2. **Production** - With Nginx reverse proxy (port 80)
3. **Custom** - Your own configuration
4. **Monitor** - View running containers
5. **Stop** - Stop all containers
6. **Clean** - Remove everything

### Option 2: Manual Docker Commands

#### Simple Deployment
```bash
# Build the image
docker build -t common-notepad:latest .

# Run the container
docker run -d \
  --name common-notepad-app \
  --restart unless-stopped \
  -p 3000:3000 \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/users.csv:/app/users.csv:ro \
  -e NODE_ENV=production \
  common-notepad:latest
```

#### Production with Nginx
```bash
# Start all services
docker-compose up -d --build

# Or build and run separately
docker-compose build
docker-compose up -d
```

## 🌐 Access URLs

### Development/Simple Deployment
- **Direct access**: `http://localhost:3000/Common_Notepad`
- **Network access**: `http://YOUR_SERVER_IP:3000/Common_Notepad`

### Production with Nginx
- **HTTP access**: `http://localhost/Common_Notepad`
- **Network access**: `http://YOUR_SERVER_IP/Common_Notepad`

## 👥 Default Users
```
Username: admin     | Password: admin123
Username: user1     | Password: password1
Username: user2     | Password: password2
Username: editor    | Password: editor123
```

## 📊 Container Management

### View Running Containers
```bash
docker ps --filter "name=common-notepad"
```

### View Logs
```bash
# App logs
docker logs -f common-notepad-app

# Nginx logs (if using production setup)
docker logs -f common-notepad-nginx

# All logs with docker-compose
docker-compose logs -f
```

### Container Control
```bash
# Stop containers
docker stop common-notepad-app
docker-compose down

# Restart containers  
docker restart common-notepad-app
docker-compose restart

# Remove containers
docker rm common-notepad-app
docker-compose down --volumes
```

### Shell Access
```bash
# Access the app container
docker exec -it common-notepad-app sh

# List files
docker exec common-notepad-app ls -la /app
```

## 📁 Data Persistence

### Volume Mounts
- `./data:/app/data` - Persistent data directory
- `./users.csv:/app/users.csv:ro` - User credentials (read-only)

### Update Users
1. Edit `users.csv` on the host
2. Restart the container: `docker restart common-notepad-app`

### Backup Data
```bash
# Create backup
docker run --rm \
  -v common-notepad_notepad-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/notepad-backup.tar.gz -C /data .

# Restore backup
docker run --rm \
  -v common-notepad_notepad-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/notepad-backup.tar.gz -C /data
```

## 🔧 Configuration

### Environment Variables
```bash
NODE_ENV=production    # Production mode
PORT=3000             # Internal port (don't change)
```

### Custom Configuration
```bash
# Custom port mapping
docker run -d \
  --name common-notepad-custom \
  -p 8080:3000 \
  -v $(pwd)/data:/app/data \
  common-notepad:latest
```

### SSL/HTTPS Setup
1. Place SSL certificates in `./ssl/` directory
2. Update `nginx/nginx.conf` with SSL configuration
3. Uncomment SSL volume mount in `docker-compose.yml`
4. Restart: `docker-compose up -d`

## 🔍 Troubleshooting

### Common Issues

#### 1. Container won't start
```bash
# Check logs
docker logs common-notepad-app

# Common fixes
docker system prune -f  # Clean up
docker-compose down --volumes && docker-compose up -d
```

#### 2. Can't connect from external IP
```bash
# Check if ports are exposed
docker port common-notepad-app

# Check firewall (Ubuntu)
sudo ufw allow 3000/tcp
sudo ufw allow 80/tcp
```

#### 3. WebSocket connection fails
- Ensure nginx configuration includes WebSocket support
- Check if `proxy_wstunnel` module is enabled in nginx image
- Verify port mapping: `docker ps` should show port bindings

#### 4. Users can't login
```bash
# Check users.csv format
docker exec common-notepad-app cat /app/users.csv

# Check file permissions
docker exec common-notepad-app ls -la /app/users.csv
```

### Health Checks
```bash
# Manual health check
curl http://localhost:3000/

# Container health status
docker inspect common-notepad-app | grep -A 10 Health
```

### Performance Monitoring
```bash
# Container stats
docker stats common-notepad-app

# Resource usage
docker exec common-notepad-app top
```
