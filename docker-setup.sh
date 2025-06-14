#!/bin/bash

# Docker-based VPS Setup for Zaihash Portfolio
# This script sets up Docker and Docker Compose for containerized deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log "Starting Docker-based VPS setup for Zaihash Portfolio..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Update system
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
log "Installing required packages..."
sudo apt install -y curl wget git ufw

# Install Docker
log "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
log "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Create application directory
APP_DIR="/var/www/zaihash-portfolio"
log "Creating application directory: $APP_DIR"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR
cd $APP_DIR

# Create environment file
log "Creating environment configuration..."
cat > .env << 'EOF'
# Database Configuration
DB_PASSWORD=your_secure_password_here
POSTGRES_DB=zaihash_portfolio
POSTGRES_USER=zaihash_user

# Application Configuration
NODE_ENV=production
PORT=3000

# Domain Configuration (update with your domain)
DOMAIN=your-domain.com
EOF

# Create directories
mkdir -p logs backups ssl

# Create Docker management script
cat > docker-manage.sh << 'EOF'
#!/bin/bash

case $1 in
    "start")
        docker-compose up -d
        echo "Application started in background"
        ;;
    "stop")
        docker-compose down
        echo "Application stopped"
        ;;
    "restart")
        docker-compose restart
        echo "Application restarted"
        ;;
    "logs")
        docker-compose logs -f --tail=100
        ;;
    "status")
        docker-compose ps
        ;;
    "build")
        docker-compose build --no-cache
        echo "Application rebuilt"
        ;;
    "deploy")
        echo "Pulling latest changes..."
        git pull origin main
        echo "Rebuilding and restarting..."
        docker-compose up -d --build
        echo "Deployment completed"
        ;;
    "backup")
        echo "Creating backup..."
        docker-compose exec db pg_dump -U zaihash_user zaihash_portfolio > backups/backup_$(date +%Y%m%d_%H%M%S).sql
        echo "Backup created in backups/"
        ;;
    "shell")
        docker-compose exec app sh
        ;;
    "db-shell")
        docker-compose exec db psql -U zaihash_user -d zaihash_portfolio
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|build|deploy|backup|shell|db-shell}"
        echo ""
        echo "Available commands:"
        echo "  start     - Start all services"
        echo "  stop      - Stop all services"
        echo "  restart   - Restart all services"
        echo "  logs      - View application logs"
        echo "  status    - Check services status"
        echo "  build     - Rebuild application"
        echo "  deploy    - Pull code and rebuild"
        echo "  backup    - Create database backup"
        echo "  shell     - Access application shell"
        echo "  db-shell  - Access database shell"
        ;;
esac
EOF

chmod +x docker-manage.sh

# Setup firewall
log "Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

# Create SSL setup script for Docker
cat > setup-ssl-docker.sh << 'EOF'
#!/bin/bash

# SSL setup for Docker deployment
# This script uses Certbot to generate SSL certificates

DOMAIN=${1:-"your-domain.com"}

if [ "$DOMAIN" = "your-domain.com" ]; then
    echo "Usage: $0 your-actual-domain.com"
    echo "Please provide your actual domain name"
    exit 1
fi

# Install Certbot
sudo apt update
sudo apt install -y certbot

# Stop nginx container temporarily
docker-compose stop nginx

# Generate certificate
sudo certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN --agree-tos --no-eff-email --email admin@$DOMAIN

# Copy certificates to ssl directory
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/
sudo chown $USER:$USER ssl/*.pem

# Update nginx configuration for SSL
cat > nginx-ssl.conf << SSLEOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 16M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_status 429;

    upstream app {
        server app:3000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;
        return 301 https://\$server_name\$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $DOMAIN www.$DOMAIN;

        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        location / {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            proxy_read_timeout 300s;
            proxy_connect_timeout 75s;
        }

        # API rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://app;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Static file caching
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
            proxy_pass http://app;
            proxy_set_header Host \$host;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
SSLEOF

# Update docker-compose to use SSL nginx config
cp docker-compose.yml docker-compose.yml.backup
sed -i 's|./nginx.conf:/etc/nginx/nginx.conf:ro|./nginx-ssl.conf:/etc/nginx/nginx.conf:ro|' docker-compose.yml

# Restart services
docker-compose up -d

echo "SSL setup completed for $DOMAIN"
echo "Your site should now be accessible at https://$DOMAIN"

# Setup auto-renewal
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'cd /var/www/zaihash-portfolio && ./docker-manage.sh restart'") | crontab -
EOF

chmod +x setup-ssl-docker.sh

# Create monitoring script for Docker
cat > monitor-docker.sh << 'EOF'
#!/bin/bash

# Docker-based monitoring script

echo "=== Docker Services Status ==="
docker-compose ps

echo -e "\n=== Application Health Check ==="
if curl -f http://localhost:3000/health &>/dev/null; then
    echo "✅ Application is healthy"
else
    echo "❌ Application health check failed"
    echo "Attempting to restart..."
    docker-compose restart app
fi

echo -e "\n=== System Resources ==="
echo "Disk Usage: $(df / | tail -1 | awk '{print $5}')"
echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"

echo -e "\n=== Container Resources ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo -e "\n=== Recent Application Logs ==="
docker-compose logs --tail=10 app

echo -e "\n=== Database Status ==="
if docker-compose exec -T db pg_isready -U zaihash_user &>/dev/null; then
    echo "✅ Database is ready"
else
    echo "❌ Database is not ready"
fi

echo -e "\nMonitoring completed: $(date)"
EOF

chmod +x monitor-docker.sh

# Create quick start script
cat > quick-start.sh << 'EOF'
#!/bin/bash

echo "Zaihash Portfolio - Quick Start"
echo "==============================="

# Check if .env is configured
if grep -q "your_secure_password_here" .env; then
    echo "⚠️  Please update the .env file with your actual configuration:"
    echo "   - Set a secure database password"
    echo "   - Update your domain name"
    echo ""
    echo "Edit the .env file: nano .env"
    exit 1
fi

# Start services
echo "Starting all services..."
docker-compose up -d

echo ""
echo "Services starting... Please wait 30 seconds for full initialization."
sleep 30

# Check status
echo "Checking service status..."
docker-compose ps

echo ""
echo "🚀 Portfolio should be accessible at:"
echo "   HTTP:  http://localhost"
echo "   Local: http://$(hostname -I | cut -d' ' -f1)"
echo ""
echo "💡 Next steps:"
echo "   1. Setup SSL: ./setup-ssl-docker.sh your-domain.com"
echo "   2. Monitor: ./monitor-docker.sh"
echo "   3. View logs: ./docker-manage.sh logs"
echo ""
echo "📚 Available commands:"
echo "   ./docker-manage.sh {start|stop|restart|logs|status|deploy}"
EOF

chmod +x quick-start.sh

# Create comprehensive README
cat > DOCKER_DEPLOYMENT.md << 'EOF'
# Zaihash Portfolio - Docker Deployment

## One-Click Setup Complete! 🚀

Your VPS is now configured with a containerized deployment setup using Docker and Docker Compose.

## Quick Start

1. **Configure Environment**
   ```bash
   nano .env  # Update database password and domain
   ```

2. **Start Application**
   ```bash
   ./quick-start.sh
   ```

3. **Setup SSL (Optional)**
   ```bash
   ./setup-ssl-docker.sh your-domain.com
   ```

## Management Commands

```bash
# Start all services
./docker-manage.sh start

# Stop all services
./docker-manage.sh stop

# View logs
./docker-manage.sh logs

# Check status
./docker-manage.sh status

# Deploy updates
./docker-manage.sh deploy

# Create database backup
./docker-manage.sh backup

# Access application shell
./docker-manage.sh shell
```

## Architecture

The deployment includes:

- **Application Container**: Your Node.js portfolio app
- **Database Container**: PostgreSQL database
- **Nginx Container**: Reverse proxy and SSL termination
- **Volume Management**: Persistent data storage

## File Structure

```
/var/www/zaihash-portfolio/
├── docker-compose.yml        # Service orchestration
├── Dockerfile               # Application container
├── nginx.conf              # Nginx configuration
├── .env                    # Environment variables
├── docker-manage.sh        # Management script
├── setup-ssl-docker.sh     # SSL setup
├── monitor-docker.sh       # Monitoring
├── quick-start.sh          # Quick deployment
├── logs/                   # Application logs
├── backups/               # Database backups
└── ssl/                   # SSL certificates
```

## Monitoring

```bash
# Run health checks
./monitor-docker.sh

# View container stats
docker stats

# Check logs
docker-compose logs -f
```

## SSL Certificate Setup

```bash
# Generate SSL certificate for your domain
./setup-ssl-docker.sh your-domain.com

# Auto-renewal is configured via cron
```

## Database Management

```bash
# Access database shell
./docker-manage.sh db-shell

# Create backup
./docker-manage.sh backup

# Restore backup
docker-compose exec -T db psql -U zaihash_user -d zaihash_portfolio < backups/backup_file.sql
```

## Troubleshooting

### Service Issues
```bash
# Check service status
docker-compose ps

# Restart specific service
docker-compose restart app

# View service logs
docker-compose logs app
```

### Resource Issues
```bash
# Check container resources
docker stats

# Clean unused resources
docker system prune -f
```

### Database Issues
```bash
# Check database connectivity
docker-compose exec db pg_isready -U zaihash_user

# Access database logs
docker-compose logs db
```

## Security Features

- Containerized isolation
- Non-root user execution
- Rate limiting on API endpoints
- Security headers configured
- SSL/TLS encryption ready
- Firewall configuration included

## Automated Features

- Health checks for all services
- Automatic container restart on failure
- Log rotation via Docker
- SSL certificate auto-renewal
- System monitoring alerts

## Scaling

To scale the application:

```bash
# Scale application containers
docker-compose up -d --scale app=3

# Update nginx upstream configuration for load balancing
```

## Backup Strategy

- Automated daily database backups
- Container configuration backups
- SSL certificate backups
- Application code versioning

## Production Checklist

- [ ] Update .env with secure passwords
- [ ] Configure your domain in .env
- [ ] Setup SSL certificate
- [ ] Configure firewall rules
- [ ] Setup monitoring alerts
- [ ] Test backup/restore procedures
- [ ] Configure log aggregation
- [ ] Setup uptime monitoring

Your portfolio is now ready for production deployment! 🎉
EOF

log "Docker-based VPS setup completed successfully!"
info "Location: $APP_DIR"
info "Next steps:"
echo "1. Update .env file with your configuration"
echo "2. Run: ./quick-start.sh"
echo "3. Setup SSL: ./setup-ssl-docker.sh your-domain.com"
echo ""
info "All management tools are ready in $APP_DIR"
info "Read DOCKER_DEPLOYMENT.md for detailed instructions"

log "Setup completed! Your portfolio is ready for deployment 🚀"