#!/bin/bash

# Zaihash Portfolio - One-Click VPS Setup Script
# This script sets up the complete environment for your portfolio website

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    error "sudo is required but not installed. Please install sudo first."
fi

log "Starting Zaihash Portfolio VPS Setup..."

# Update system
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
log "Installing essential packages..."
sudo apt install -y curl wget git build-essential software-properties-common apt-transport-https ca-certificates gnupg lsb-release ufw nginx

# Install Node.js (using NodeSource repository for latest LTS)
log "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
node_version=$(node -v)
npm_version=$(npm -v)
log "Node.js installed: $node_version"
log "NPM installed: $npm_version"

# Install PM2 for process management
log "Installing PM2 process manager..."
sudo npm install -g pm2

# Install PostgreSQL
log "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create application directory
APP_DIR="/var/www/zaihash-portfolio"
log "Creating application directory: $APP_DIR"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Clone or prepare for code deployment
log "Setting up application structure..."
cd $APP_DIR

# Create necessary directories
mkdir -p logs backups scripts

# Create database setup script
cat > scripts/setup-database.sh << 'EOF'
#!/bin/bash
# Database setup script

DB_NAME="zaihash_portfolio"
DB_USER="zaihash_user"
DB_PASSWORD=$(openssl rand -base64 32)

# Create database and user
sudo -u postgres psql << EOSQL
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOSQL

# Save database credentials
cat > /var/www/zaihash-portfolio/.env << ENVEOF
DATABASE_URL="postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME"
NODE_ENV=production
PORT=3000
ENVEOF

echo "Database setup complete!"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Password saved to .env file"
EOF

chmod +x scripts/setup-database.sh

# Create PM2 ecosystem file
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'zaihash-portfolio',
    script: 'dist/index.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 5000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
EOF

# Create Nginx configuration
log "Setting up Nginx..."
sudo tee /etc/nginx/sites-available/zaihash-portfolio << 'EOF'
server {
    listen 80;
    server_name zaihash.xyz www.zaihash.xyz;  # Main domain
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_status 429;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        
        # Handle WebSocket connections
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # API rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static file caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
    }
    
    # Security
    location ~ /\. {
        deny all;
    }
    
    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}

# Admin subdomain configuration
server {
    listen 80;
    server_name admin.zaihash.xyz;  # Admin subdomain
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Rate limiting for admin panel
    limit_req_zone $binary_remote_addr zone=admin:10m rate=5r/s;
    limit_req_status 429;
    
    location / {
        limit_req zone=admin burst=10 nodelay;
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        
        # Additional security for admin
        proxy_set_header X-Admin-Domain "true";
    }
    
    # API endpoints with stricter rate limiting
    location /api/ {
        limit_req zone=admin burst=5 nodelay;
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Admin-Domain "true";
    }
    
    # Block direct access to admin endpoints from main domain
    location /admin {
        deny all;
    }
    
    # Security
    location ~ /\. {
        deny all;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/zaihash-portfolio /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Create SSL setup script
cat > scripts/setup-ssl.sh << 'EOF'
#!/bin/bash
# SSL setup script using Let's Encrypt

# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate (you'll need to replace with your actual domain)
echo "To setup SSL, run:"
echo "sudo certbot --nginx -d your-domain.com -d www.your-domain.com"
echo ""
echo "After SSL is setup, certbot will automatically renew certificates"
echo "You can test the renewal with: sudo certbot renew --dry-run"
EOF

chmod +x scripts/setup-ssl.sh

# Create backup script
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Backup script for application and database

BACKUP_DIR="/var/www/zaihash-portfolio/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="zaihash_portfolio"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
pg_dump $DB_NAME > $BACKUP_DIR/db_backup_$DATE.sql

# Backup application files (excluding node_modules)
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz --exclude=node_modules --exclude=.git --exclude=backups .

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $(date)"
EOF

chmod +x scripts/backup.sh

# Create deployment script
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
# Deployment script

set -e

APP_DIR="/var/www/zaihash-portfolio"
cd $APP_DIR

echo "Starting deployment..."

# Pull latest code (if using git)
if [ -d ".git" ]; then
    git pull origin main
fi

# Install dependencies
npm ci --production

# Build application
npm run build

# Run database migrations if needed
if [ -f "scripts/migrate.sh" ]; then
    ./scripts/migrate.sh
fi

# Restart application
pm2 restart zaihash-portfolio

# Reload Nginx
sudo systemctl reload nginx

echo "Deployment completed successfully!"
EOF

chmod +x scripts/deploy.sh

# Create monitoring script
cat > scripts/monitor.sh << 'EOF'
#!/bin/bash
# Simple monitoring script

APP_NAME="zaihash-portfolio"

# Check if app is running
if pm2 list | grep -q "$APP_NAME.*online"; then
    echo "✅ Application is running"
else
    echo "❌ Application is not running"
    echo "Attempting to restart..."
    pm2 restart $APP_NAME
fi

# Check disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "⚠️  High disk usage: ${DISK_USAGE}%"
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.2f", $3/$2 * 100.0)}')
echo "Memory usage: ${MEMORY_USAGE}%"

# Check application logs for errors
ERROR_COUNT=$(tail -n 100 logs/err.log | wc -l)
if [ $ERROR_COUNT -gt 0 ]; then
    echo "⚠️  Found $ERROR_COUNT recent errors in logs"
fi

echo "Monitoring check completed: $(date)"
EOF

chmod +x scripts/monitor.sh

# Setup firewall
log "Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Create systemd service for automatic startup
sudo tee /etc/systemd/system/zaihash-portfolio.service << 'EOF'
[Unit]
Description=Zaihash Portfolio Application
After=network.target

[Service]
Type=forking
User=www-data
WorkingDirectory=/var/www/zaihash-portfolio
Environment=NODE_ENV=production
ExecStart=/usr/bin/pm2 start ecosystem.config.js --no-daemon
ExecReload=/usr/bin/pm2 restart zaihash-portfolio
ExecStop=/usr/bin/pm2 stop zaihash-portfolio
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create log rotation
sudo tee /etc/logrotate.d/zaihash-portfolio << 'EOF'
/var/www/zaihash-portfolio/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

# Setup cron jobs
log "Setting up automated tasks..."
(crontab -l 2>/dev/null; echo "0 2 * * * /var/www/zaihash-portfolio/scripts/backup.sh >> /var/www/zaihash-portfolio/logs/backup.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /var/www/zaihash-portfolio/scripts/monitor.sh >> /var/www/zaihash-portfolio/logs/monitor.log 2>&1") | crontab -

# Create startup script
cat > start-app.sh << 'EOF'
#!/bin/bash
# Application startup script

cd /var/www/zaihash-portfolio

# Setup database if .env doesn't exist
if [ ! -f .env ]; then
    echo "Setting up database..."
    ./scripts/setup-database.sh
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d node_modules ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build application if dist doesn't exist
if [ ! -d dist ]; then
    echo "Building application..."
    npm run build
fi

# Start application with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 startup
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME

echo "Application started successfully!"
EOF

chmod +x start-app.sh

# Create quick commands script
cat > commands.sh << 'EOF'
#!/bin/bash
# Quick commands for managing the application

case $1 in
    "start")
        pm2 start ecosystem.config.js
        ;;
    "stop")
        pm2 stop zaihash-portfolio
        ;;
    "restart")
        pm2 restart zaihash-portfolio
        ;;
    "logs")
        pm2 logs zaihash-portfolio
        ;;
    "status")
        pm2 status
        ;;
    "deploy")
        ./scripts/deploy.sh
        ;;
    "backup")
        ./scripts/backup.sh
        ;;
    "monitor")
        ./scripts/monitor.sh
        ;;
    "ssl")
        ./scripts/setup-ssl.sh
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|deploy|backup|monitor|ssl}"
        echo ""
        echo "Available commands:"
        echo "  start     - Start the application"
        echo "  stop      - Stop the application"
        echo "  restart   - Restart the application"
        echo "  logs      - View application logs"
        echo "  status    - Check application status"
        echo "  deploy    - Deploy latest code"
        echo "  backup    - Create backup"
        echo "  monitor   - Run monitoring check"
        echo "  ssl       - Setup SSL certificate"
        ;;
esac
EOF

chmod +x commands.sh

# Create README for the deployment
cat > DEPLOYMENT_README.md << 'EOF'
# Zaihash Portfolio - VPS Deployment Guide

## Quick Start

After running the setup script, your VPS is configured with:

- ✅ Node.js and NPM
- ✅ PostgreSQL database
- ✅ Nginx web server
- ✅ PM2 process manager
- ✅ Firewall configuration
- ✅ SSL ready (run setup-ssl.sh)
- ✅ Automated backups
- ✅ Log rotation
- ✅ Monitoring

## Next Steps

1. **Upload your code** to `/var/www/zaihash-portfolio/`
2. **Configure domain** in `/etc/nginx/sites-available/zaihash-portfolio`
3. **Setup SSL** by running `./scripts/setup-ssl.sh`
4. **Start the application** by running `./start-app.sh`

## Quick Commands

```bash
# Start application
./commands.sh start

# Check status
./commands.sh status

# View logs
./commands.sh logs

# Restart application
./commands.sh restart

# Deploy updates
./commands.sh deploy

# Create backup
./commands.sh backup

# Setup SSL
./commands.sh ssl
```

## File Structure

```
/var/www/zaihash-portfolio/
├── scripts/
│   ├── setup-database.sh    # Database setup
│   ├── deploy.sh           # Deployment script
│   ├── backup.sh           # Backup script
│   ├── monitor.sh          # Monitoring script
│   └── setup-ssl.sh        # SSL setup
├── logs/                   # Application logs
├── backups/               # Database and file backups
├── ecosystem.config.js    # PM2 configuration
├── start-app.sh          # Application startup
├── commands.sh           # Quick commands
└── .env                  # Environment variables
```

## Important Notes

1. **Database credentials** are automatically generated and saved in `.env`
2. **Backups** run daily at 2 AM
3. **Monitoring** runs every 5 minutes
4. **Logs** are rotated daily and kept for 14 days
5. **Firewall** is configured to allow only SSH and HTTP/HTTPS

## Troubleshooting

- Check application status: `pm2 status`
- View error logs: `tail -f logs/err.log`
- Check Nginx status: `sudo systemctl status nginx`
- Test Nginx config: `sudo nginx -t`
- Check database: `sudo -u postgres psql -l`

## Security

- Firewall is enabled with only necessary ports open
- SSL certificate setup available
- Rate limiting configured for API endpoints
- Security headers configured in Nginx

## Monitoring

The monitoring script checks:
- Application health
- Disk usage
- Memory usage
- Recent error logs

Access monitoring logs: `tail -f logs/monitor.log`
EOF

log "VPS setup completed successfully!"
info "Application directory: $APP_DIR"
info "Next steps:"
echo "1. Upload your portfolio code to $APP_DIR"
echo "2. Update domain name in /etc/nginx/sites-available/zaihash-portfolio"
echo "3. Run: cd $APP_DIR && ./start-app.sh"
echo "4. Setup SSL: ./scripts/setup-ssl.sh"
echo ""
info "Quick commands available in $APP_DIR/commands.sh"
info "Read DEPLOYMENT_README.md for detailed instructions"

# Restart Nginx
sudo systemctl restart nginx

warn "Don't forget to:"
echo "- Update your domain name in Nginx configuration"
echo "- Setup SSL certificate for HTTPS"
echo "- Upload your application code"
echo "- Configure any environment variables needed"

log "Setup script completed! 🚀"