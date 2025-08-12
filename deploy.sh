#!/bin/bash

echo "🚀 Deploying Common Notepad to Apache2..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please don't run this script as root. Run as a regular user with sudo privileges.${NC}"
    exit 1
fi

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1 failed${NC}"
        exit 1
    fi
}

# Update system packages
echo -e "${YELLOW}📦 Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y
check_status "System update"

# Install Node.js and npm
echo -e "${YELLOW}📦 Installing Node.js and npm...${NC}"
sudo apt install -y nodejs npm
check_status "Node.js installation"

# Install Apache2 and required modules
echo -e "${YELLOW}🌐 Installing Apache2...${NC}"
sudo apt install -y apache2
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_wstunnel
sudo a2enmod rewrite
sudo a2enmod headers
check_status "Apache2 installation and modules"

# Create application directory
echo -e "${YELLOW}📁 Creating application directory...${NC}"
sudo mkdir -p /opt/common-notepad
sudo chown $USER:$USER /opt/common-notepad
check_status "Application directory creation"

# Copy files (user needs to do this manually)
echo -e "${YELLOW}📋 Please copy the following files to /opt/common-notepad/:${NC}"
echo "   - app.js (from the updated server artifact)"
echo "   - public/index.html (from the updated client artifact)"
echo "   - package.json"
echo "   - users.csv"
echo ""
echo "Press Enter when you have copied all files..."
read -r

# Check if files exist
cd /opt/common-notepad
if [ ! -f "app.js" ] || [ ! -f "package.json" ] || [ ! -f "users.csv" ] || [ ! -f "public/index.html" ]; then
    echo -e "${RED}❌ Required files missing. Please copy all files and run the script again.${NC}"
    exit 1
fi

# Install npm dependencies
echo -e "${YELLOW}📦 Installing npm dependencies...${NC}"
npm install
check_status "NPM dependencies installation"

# Create systemd service
echo -e "${YELLOW}⚙️ Creating systemd service...${NC}"
sudo tee /etc/systemd/system/common-notepad.service > /dev/null <<EOF
[Unit]
Description=Common Notepad Collaborative Editor
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/common-notepad
ExecStart=/usr/bin/node app.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=common-notepad

[Install]
WantedBy=multi-user.target
EOF
check_status "Systemd service creation"

# Set proper permissions
echo -e "${YELLOW}🔐 Setting permissions...${NC}"
sudo chown -R www-data:www-data /opt/common-notepad
sudo chmod 600 /opt/common-notepad/users.csv
check_status "Permissions setup"

# Configure Apache
echo -e "${YELLOW}🌐 Configuring Apache...${NC}"
sudo tee /etc/apache2/sites-available/common-notepad.conf > /dev/null <<'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    # Enable required modules
    # Make sure these are enabled: a2enmod proxy proxy_http proxy_wstunnel rewrite headers

    # Reverse proxy for the Common_Notepad application
    ProxyPreserveHost On
    
    # Handle WebSocket connections for Socket.IO
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/Common_Notepad/socket.io/(.*) ws://127.0.0.1:3000/socket.io/$1 [P,L]

    # Handle Socket.IO polling and regular HTTP requests
    ProxyPass /Common_Notepad/socket.io/ http://127.0.0.1:3000/socket.io/
    ProxyPassReverse /Common_Notepad/socket.io/ http://127.0.0.1:3000/socket.io/

    # Handle login API
    ProxyPass /Common_Notepad/login http://127.0.0.1:3000/login
    ProxyPassReverse /Common_Notepad/login http://127.0.0.1:3000/login

    # Handle main application
    ProxyPass /Common_Notepad/ http://127.0.0.1:3000/
    ProxyPassReverse /Common_Notepad/ http://127.0.0.1:3000/

    # Set headers for WebSocket support
    ProxyPass /Common_Notepad http://127.0.0.1:3000/Common_Notepad
    ProxyPassReverse /Common_Notepad http://127.0.0.1:3000/Common_Notepad

    # Optional: Add headers for better WebSocket support
    <Location "/Common_Notepad">
        ProxyPassReverse /
        ProxyPassReverseMap / /Common_Notepad/
        Header always set X-Forwarded-Proto "http"
        Header always set X-Forwarded-Port "80"
    </Location>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable the site and disable default if it conflicts
sudo a2ensite common-notepad.conf
check_status "Apache site configuration"

# Test Apache configuration
sudo apache2ctl configtest
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Apache configuration test failed${NC}"
    exit 1
fi

# Start services
echo -e "${YELLOW}🔄 Starting services...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable common-notepad.service
sudo systemctl start common-notepad.service
sudo systemctl restart apache2
check_status "Services startup"

# Configure firewall
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    sudo ufw allow 80/tcp
    sudo ufw allow 22/tcp
    echo "y" | sudo ufw enable
    check_status "UFW firewall configuration"
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Final status check
echo -e "${YELLOW}🔍 Checking service status...${NC}"
sleep 3

if systemctl is-active --quiet common-notepad.service; then
    echo -e "${GREEN}✅ Common Notepad service is running${NC}"
else
    echo -e "${RED}❌ Common Notepad service failed to start${NC}"
    echo "Check logs with: sudo journalctl -u common-notepad.service -f"
fi

if systemctl is-active --quiet apache2; then
    echo -e "${GREEN}✅ Apache2 service is running${NC}"
else
    echo -e "${RED}❌ Apache2 service failed to start${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Access Information:${NC}"
echo -e "   URL: ${GREEN}http://${SERVER_IP}/Common_Notepad${NC}"
echo -e "   Default users: ${GREEN}admin/admin123, user1/password1, user2/password2${NC}"
echo ""
echo -e "${YELLOW}📊 Useful Commands:${NC}"
echo "   Check app logs: sudo journalctl -u common-notepad.service -f"
echo "   Check Apache logs: sudo tail -f /var/log/apache2/error.log"
echo "   Restart app: sudo systemctl restart common-notepad.service"
echo "   Restart Apache: sudo systemctl restart apache2"
echo ""
echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
echo "   If you get 502 errors, check if Node.js is running on port 3000:"
echo "   sudo netstat -tlnp | grep 3000"
echo ""
echo -e "${GREEN}Happy collaborating! 🚀${NC}"
