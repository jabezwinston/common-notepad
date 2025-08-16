#!/bin/bash

# Docker deployment script for Common Notepad
# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 Common Notepad Docker Deployment${NC}"
echo "======================================"

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1 failed${NC}"
        exit 1
    fi
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Create necessary directories
echo -e "${YELLOW}�� Creating directories...${NC}"
mkdir -p data nginx/conf.d nginx/logs ssl
check_status "Directory creation"

# Check if required files exist
echo -e "${YELLOW}📋 Checking required files...${NC}"
required_files=("app.js" "public/index.html" "package.json" "users.csv" "Dockerfile" "docker-compose.yml")
missing_files=()

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing required files:${NC}"
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
    echo ""
    echo -e "${YELLOW}Please copy all files from the artifacts and run this script again.${NC}"
    exit 1
fi

# Copy users.csv to data directory if it doesn't exist
if [ ! -f "data/users.csv" ]; then
    cp users.csv data/users.csv
    echo -e "${GREEN}✅ Copied users.csv to data directory${NC}"
fi

# Build the Docker image
echo -e "${YELLOW}🔨 Building Docker image...${NC}"
docker build -t common-notepad:latest .
check_status "Docker image build"

# Display deployment options
echo ""
echo -e "${BLUE}Choose deployment option:${NC}"
echo "1. 🚀 Quick start (Node.js app only on port 3000)"
echo "2. 🌐 Production with Nginx reverse proxy (ports 80/443)"
echo "3. 🔧 Custom configuration"
echo "4. 📊 Show running containers"
echo "5. 🛑 Stop all containers"
echo "6. 🗑️  Remove all containers and images"

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo -e "${YELLOW}🚀 Starting quick deployment...${NC}"
        # Stop existing containers
        docker stop common-notepad-app 2>/dev/null || true
        docker rm common-notepad-app 2>/dev/null || true
        
        # Run the container
        docker run -d \
            --name common-notepad-app \
            --restart unless-stopped \
            -p 3000:3000 \
            -v "$(pwd)/data:/app/data" \
            -v "$(pwd)/users.csv:/app/users.csv:ro" \
            -e NODE_ENV=production \
            common-notepad:latest
        check_status "Container startup"
        
        echo -e "${GREEN}🎉 Deployment complete!${NC}"
        echo -e "${YELLOW}📋 Access Information:${NC}"
        echo -e "   URL: ${GREEN}http://localhost:3000/Common_Notepad${NC}"
        echo -e "   Or: ${GREEN}http://$(hostname -I | awk '{print $1}'):3000/Common_Notepad${NC}"
        ;;
        
    2)
        echo -e "${YELLOW}🌐 Starting production deployment with Nginx...${NC}"
        
        # Create nginx configuration if it doesn't exist
        if [ ! -f "nginx/nginx.conf" ]; then
            echo -e "${YELLOW}📝 Creating nginx configuration...${NC}"
            echo "Please copy the nginx.conf from the artifacts to nginx/nginx.conf"
            echo "Press Enter when done..."
            read -r
        fi
        
        # Start with docker-compose
        docker-compose down 2>/dev/null || true
        docker-compose up -d --build
        check_status "Docker Compose startup"
        
        echo -e "${GREEN}🎉 Production deployment complete!${NC}"
        echo -e "${YELLOW}📋 Access Information:${NC}"
        echo -e "   URL: ${GREEN}http://localhost/Common_Notepad${NC}"
        echo -e "   Or: ${GREEN}http://$(hostname -I | awk '{print $1}')/Common_Notepad${NC}"
        ;;
        
    3)
        echo -e "${YELLOW}🔧 Custom configuration${NC}"
        echo "Available environment variables:"
        echo "  NODE_ENV (default: production)"
        echo "  PORT (default: 3000)"
        echo ""
        read -p "Enter custom port (default 3000): " custom_port
        custom_port=${custom_port:-3000}
        
        read -p "Enter custom container name (default: common-notepad-custom): " custom_name
        custom_name=${custom_name:-common-notepad-custom}
        
        docker stop "$custom_name" 2>/dev/null || true
        docker rm "$custom_name" 2>/dev/null || true
        
        docker run -d \
            --name "$custom_name" \
            --restart unless-stopped \
            -p "$custom_port:3000" \
            -v "$(pwd)/data:/app/data" \
            -v "$(pwd)/users.csv:/app/users.csv:ro" \
            -e NODE_ENV=production \
            -e PORT=3000 \
            common-notepad:latest
        check_status "Custom container startup"
        
        echo -e "${GREEN}🎉 Custom deployment complete!${NC}"
        echo -e "${YELLOW}📋 Access Information:${NC}"
        echo -e "   URL: ${GREEN}http://localhost:$custom_port/Common_Notepad${NC}"
        ;;
        
    4)
        echo -e "${YELLOW}📊 Running containers:${NC}"
        echo ""
        docker ps --filter "name=common-notepad" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo -e "${YELLOW}📈 Container logs (last 20 lines):${NC}"
        docker logs --tail 20 common-notepad-app 2>/dev/null || echo "No logs available"
        ;;
        
    5)
        echo -e "${YELLOW}🛑 Stopping all containers...${NC}"
        docker stop common-notepad-app common-notepad-nginx 2>/dev/null || true
        docker-compose down 2>/dev/null || true
        check_status "Container shutdown"
        ;;
        
    6)
        echo -e "${YELLOW}🗑️  Removing all containers and images...${NC}"
        read -p "Are you sure? This will remove all data! (y/N): " confirm
        if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
            docker stop common-notepad-app common-notepad-nginx 2>/dev/null || true
            docker-compose down --volumes 2>/dev/null || true
            docker rm common-notepad-app common-notepad-nginx 2>/dev/null || true
            docker rmi common-notepad:latest 2>/dev/null || true
            docker system prune -f
            check_status "Complete cleanup"
        else
            echo "Cancelled."
        fi
        ;;
        
    *)
        echo -e "${RED}❌ Invalid option${NC}"
        exit 1
        ;;
esac

# Show useful commands
if [ "$choice" == "1" ] || [ "$choice" == "2" ] || [ "$choice" == "3" ]; then
    echo ""
    echo -e "${BLUE}�� Useful Commands:${NC}"
    echo "  View logs: docker logs -f common-notepad-app"
    echo "  Stop app: docker stop common-notepad-app"
    echo "  Restart app: docker restart common-notepad-app"
    echo "  Shell access: docker exec -it common-notepad-app sh"
    echo "  Update users: Edit data/users.csv and restart container"
    echo ""
    echo -e "${YELLOW}🔧 Default Users:${NC}"
    echo "  admin/admin123, user1/password1, user2/password2, editor/editor123"
fi

echo -e "${GREEN}🐳 Docker deployment script completed!${NC}"
