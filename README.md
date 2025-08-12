# Apache2 Deployment Guide for Common_Notepad

## 1. Server Setup Prerequisites

### Install Node.js and npm
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nodejs npm

# CentOS/RHEL
sudo yum install nodejs npm
```

### Install Apache2 and enable required modules
```bash
# Ubuntu/Debian
sudo apt install apache2
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_wstunnel
sudo a2enmod rewrite
sudo a2enmod headers

# CentOS/RHEL
sudo yum install httpd
# For CentOS, modules are usually compiled in
```

## 2. Deploy the Node.js Application

### Create application directory
```bash
sudo mkdir -p /opt/common-notepad
sudo chown $USER:$USER /opt/common-notepad
cd /opt/common-notepad
```

### Setup the application files
```bash
# Copy all the code files from the artifacts:
# - app.js (updated server code)
# - public/index.html (updated client code)  
# - package.json
# - users.csv

# Install dependencies
npm install

# Test the application
npm start
# Should show: "Collaborative editor server running on port 3000"
# Press Ctrl+C to stop for now
```

## 3. Configure Apache2

### Update the virtual host configuration
```bash
# Ubuntu/Debian
sudo nano /etc/apache2/sites-available/000-default.conf

# CentOS/RHEL
sudo nano /etc/httpd/conf/httpd.conf
```

**Copy the Apache configuration from the artifact above into your virtual host file.**

### Test Apache configuration
```bash
# Ubuntu/Debian
sudo apache2ctl configtest

# CentOS/RHEL
sudo httpd -t
```

### Restart Apache
```bash
# Ubuntu/Debian
sudo systemctl restart apache2

# CentOS/RHEL
sudo systemctl restart httpd
```

## 4. Setup Application as a System Service

### Create systemd service file
```bash
sudo nano /etc/systemd/system/common-notepad.service
```

**Add this content:**
```ini
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

# Logging
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=common-notepad

[Install]
WantedBy=multi-user.target
```

### Enable and start the service
```bash
# Set proper permissions
sudo chown -R www-data:www-data /opt/common-notepad

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable common-notepad.service
sudo systemctl start common-notepad.service

# Check status
sudo systemctl status common-notepad.service
```

## 5. Firewall Configuration

### Open required ports
```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 80/tcp
sudo ufw allow 22/tcp  # Keep SSH access
sudo ufw enable

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload

# Or using iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```

## 6. Testing the Deployment

### Check if services are running
```bash
# Check Node.js app
sudo systemctl status common-notepad.service
sudo journalctl -u common-notepad.service -f

# Check Apache
sudo systemctl status apache2  # or httpd on CentOS

# Check if port 3000 is listening (locally)
sudo netstat -tlnp | grep 3000

# Check if port 80 is listening
sudo netstat -tlnp | grep 80
```

### Test the application
1. **Open your browser** and go to: `http://YOUR_SERVER_IP/Common_Notepad`
2. **Login** with default credentials:
   - admin/admin123
   - user1/password1
   - etc.

### Test multiple users
1. **Open multiple tabs** or use different browsers
2. **Login with different users**
3. **Type in the editor** - you should see real-time collaboration!

## 7. Monitoring and Logs

### View application logs
```bash
# Real-time logs
sudo journalctl -u common-notepad.service -f

# Apache logs
sudo tail -f /var/log/apache2/access.log
sudo tail -f /var/log/apache2/error.log
```

## 8. Troubleshooting

### Common Issues:

**1. "502 Bad Gateway" error**
- Check if Node.js service is running: `sudo systemctl status common-notepad.service`
- Check if Node.js is listening on port 3000: `sudo netstat -tlnp | grep 3000`

**2. WebSocket connection failures**
- Ensure `proxy_wstunnel` module is enabled
- Check Apache error logs for WebSocket-related errors

**3. Login not working**
- Check if `/opt/common-notepad/users.csv` exists and is readable
- Check application logs for authentication errors

**4. Can't access from external IP**
- Check firewall rules
- Ensure Apache is bound to all interfaces (not just localhost)

### Restart services if needed
```bash
# Restart Node.js app
sudo systemctl restart common-notepad.service

# Restart Apache
sudo systemctl restart apache2  # or httpd
```

## 9. Security Considerations

### Basic security improvements
```bash
# Hide Apache version
echo "ServerTokens Prod" | sudo tee -a /etc/apache2/apache2.conf

# Set proper file permissions
sudo chmod 600 /opt/common-notepad/users.csv
sudo chown www-data:www-data /opt/common-notepad/users.csv
```

### Optional: Add HTTPS (SSL/TLS)
- Consider using Let's Encrypt for free SSL certificates
- Update Apache configuration for HTTPS

Your collaborative text editor should now be accessible at `http://YOUR_SERVER_IP/Common_Notepad`!