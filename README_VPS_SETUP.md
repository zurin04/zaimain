# Zaihash Portfolio - Complete VPS Setup Guide

## One-Click Deployment

Your portfolio now includes a complete one-click VPS setup system with multiple deployment options.

## Quick Start

1. **Upload files to your VPS**
   ```bash
   # Upload all files to your VPS
   scp -r . user@your-vps-ip:/home/user/zaihash-portfolio
   ```

2. **Run the deployment script**
   ```bash
   cd zaihash-portfolio
   chmod +x deploy-vps.sh
   ./deploy-vps.sh
   ```

3. **Choose your deployment method**
   - **Docker** (Recommended): Containerized setup with full production features
   - **Traditional**: Native installation with PM2 and system services
   - **Quick**: Development setup for testing

## Deployment Options

### 🐳 Docker Deployment (Recommended)

**Best for**: Production environments, easy scaling, isolated containers

**Features**:
- Complete containerization with Docker Compose
- PostgreSQL database container
- Nginx reverse proxy with SSL support
- Automated backups and monitoring
- Easy scaling and updates

**Files Created**:
- `docker-compose.yml` - Service orchestration
- `Dockerfile` - Application container
- `nginx.conf` - Web server configuration
- `.env` - Environment variables
- Management scripts for easy operation

### ⚙️ Traditional Deployment

**Best for**: Direct system control, maximum performance

**Features**:
- Native Node.js installation with PM2
- System-level PostgreSQL database
- Nginx web server configuration
- SSL with Let's Encrypt
- System monitoring and log rotation

**Files Created**:
- PM2 ecosystem configuration
- Nginx site configuration
- Database setup scripts
- Backup and monitoring scripts
- System service files

### ⚡ Quick Development Setup

**Best for**: Testing, development, proof of concept

**Features**:
- Minimal Node.js setup
- Development server
- No SSL or production features
- Fast deployment

## Post-Installation Steps

### For Docker Deployment

1. **Configure Environment**
   ```bash
   cd /var/www/zaihash-portfolio
   nano .env  # Update database password and domain
   ```

2. **Start Services**
   ```bash
   ./quick-start.sh
   ```

3. **Setup SSL**
   ```bash
   ./setup-ssl-docker.sh your-domain.com
   ```

4. **Management Commands**
   ```bash
   ./docker-manage.sh start     # Start all services
   ./docker-manage.sh stop      # Stop all services
   ./docker-manage.sh logs      # View logs
   ./docker-manage.sh status    # Check status
   ./docker-manage.sh deploy    # Deploy updates
   ./docker-manage.sh backup    # Create backup
   ```

### For Traditional Deployment

1. **Start Application**
   ```bash
   cd /var/www/zaihash-portfolio
   ./start-app.sh
   ```

2. **Setup SSL**
   ```bash
   ./scripts/setup-ssl.sh
   ```

3. **Management Commands**
   ```bash
   ./commands.sh start      # Start application
   ./commands.sh stop       # Stop application
   ./commands.sh restart    # Restart application
   ./commands.sh logs       # View logs
   ./commands.sh status     # Check PM2 status
   ./commands.sh deploy     # Deploy updates
   ./commands.sh backup     # Create backup
   ./commands.sh monitor    # Run health check
   ```

## Features Included

### Security
- Firewall configuration (UFW)
- SSL/TLS encryption ready
- Rate limiting on API endpoints
- Security headers configuration
- Non-root container execution (Docker)

### Monitoring
- Health check endpoints (`/api/health`, `/api/status`)
- Application monitoring scripts
- Resource usage tracking
- Error log monitoring
- Automated alerts

### Backup & Recovery
- Automated daily database backups
- Application file backups
- Backup retention policies
- One-command restore procedures

### Performance
- Nginx reverse proxy
- Static file caching
- Gzip compression
- Process clustering (Traditional)
- Container scaling (Docker)

### Automation
- GitHub Actions workflow for CI/CD
- Automated SSL certificate renewal
- Log rotation
- System monitoring cron jobs

## Directory Structure

```
zaihash-portfolio/
├── 📁 client/                  # Frontend React application
├── 📁 server/                  # Backend Express server
├── 📁 shared/                  # Shared types and schemas
├── 📁 .github/workflows/       # CI/CD automation
├── 🐳 Docker files
│   ├── Dockerfile              # Application container
│   ├── docker-compose.yml      # Service orchestration
│   ├── nginx.conf             # Nginx configuration
│   └── docker-setup.sh        # Docker deployment script
├── ⚙️ Traditional setup files
│   ├── setup.sh               # Main setup script
│   └── ecosystem.config.js    # PM2 configuration
├── 🚀 Deployment tools
│   ├── deploy-vps.sh          # Main deployment chooser
│   └── .github/workflows/deploy.yml  # Auto-deployment
└── 📚 Documentation
    ├── README_VPS_SETUP.md    # This file
    ├── DOCKER_DEPLOYMENT.md   # Docker guide
    └── DEPLOYMENT_README.md   # Traditional guide
```

## Troubleshooting

### Common Issues

**Application won't start**
```bash
# Check logs
./docker-manage.sh logs  # Docker
./commands.sh logs       # Traditional

# Check system resources
df -h                    # Disk space
free -h                  # Memory usage
```

**Database connection issues**
```bash
# Docker
docker-compose exec db pg_isready -U zaihash_user

# Traditional
sudo -u postgres psql -l
```

**SSL certificate issues**
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates
sudo certbot renew
```

**Port conflicts**
```bash
# Check what's using port 80/443
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

### Performance Optimization

**For high traffic**:
- Scale Docker containers: `docker-compose up -d --scale app=3`
- Enable PM2 cluster mode in traditional setup
- Configure CDN for static assets
- Set up database connection pooling

**For low resources**:
- Reduce PM2 instances
- Lower Docker memory limits
- Disable unnecessary logging
- Use smaller Docker base images

## Security Checklist

- [ ] Update default passwords in `.env`
- [ ] Configure firewall rules
- [ ] Setup SSL certificates
- [ ] Enable fail2ban for SSH protection
- [ ] Regular security updates
- [ ] Monitor access logs
- [ ] Backup encryption
- [ ] Database access restrictions

## Monitoring & Maintenance

### Daily Tasks (Automated)
- Database backups
- Log rotation
- Health checks
- Resource monitoring

### Weekly Tasks
- Review error logs
- Check disk usage
- Update system packages
- Review security logs

### Monthly Tasks
- SSL certificate renewal check
- Performance optimization review
- Backup restore testing
- Security audit

## Support

Your VPS setup includes:

1. **Comprehensive Documentation**: Step-by-step guides for all scenarios
2. **Management Scripts**: Easy-to-use commands for all operations
3. **Monitoring Tools**: Built-in health checks and alerts
4. **Backup Systems**: Automated data protection
5. **Security Configuration**: Production-ready security settings

## Scaling Your Application

### Horizontal Scaling (Docker)
```bash
# Scale application containers
docker-compose up -d --scale app=5

# Load balancer configuration
# Update nginx upstream configuration
```

### Vertical Scaling
- Increase VPS resources (CPU, RAM)
- Optimize database queries
- Implement caching strategies
- CDN integration

### Database Scaling
- Read replicas for PostgreSQL
- Connection pooling
- Query optimization
- Database partitioning

Your Zaihash Portfolio is now equipped with enterprise-grade deployment capabilities. The one-click setup handles everything from basic development to production-ready deployments with monitoring, security, and scaling built-in.

Choose the deployment method that best fits your needs and let the automation handle the rest!