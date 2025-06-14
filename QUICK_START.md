# Zaihash Portfolio - One-Click VPS Setup

## Complete VPS Deployment System

Your portfolio now includes a comprehensive one-click VPS setup with three deployment options:

### 🚀 Quick Deployment

```bash
# 1. Upload to your VPS
scp -r . user@your-vps:/home/user/portfolio

# 2. Run one-click setup
cd portfolio
chmod +x deploy-vps.sh
./deploy-vps.sh
```

## Deployment Options

**1. Docker Deployment (Recommended)**
- Complete containerization
- PostgreSQL database
- Nginx reverse proxy
- SSL support
- Automated monitoring

**2. Traditional Deployment**
- Native Node.js with PM2
- System PostgreSQL
- Nginx configuration
- Let's Encrypt SSL
- System monitoring

**3. Quick Development**
- Minimal setup
- Development server only
- No SSL or production features

## What's Included

### Security & Performance
- Firewall configuration
- SSL/TLS encryption
- Rate limiting
- Gzip compression
- Security headers

### Monitoring & Maintenance
- Health check endpoints
- Automated backups
- Log rotation
- Resource monitoring
- Error tracking

### Automation
- GitHub Actions CI/CD
- SSL auto-renewal
- System monitoring
- Backup scheduling

### Management Tools
- One-command start/stop/restart
- Log viewing
- Status checking
- Deployment scripts
- Backup/restore tools

## File Structure

```
├── 🐳 Docker Setup
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── nginx.conf
│   └── docker-setup.sh
│
├── ⚙️ Traditional Setup
│   ├── setup.sh
│   ├── ecosystem.config.js
│   └── nginx configuration
│
├── 🚀 Main Deployment
│   ├── deploy-vps.sh (chooser)
│   └── .github/workflows/deploy.yml
│
└── 📚 Documentation
    ├── README_VPS_SETUP.md
    ├── DOCKER_DEPLOYMENT.md
    └── DEPLOYMENT_README.md
```

## Post-Setup Commands

### Docker
```bash
./quick-start.sh                    # Start everything
./docker-manage.sh logs             # View logs
./setup-ssl-docker.sh domain.com    # Setup SSL
```

### Traditional
```bash
./start-app.sh                      # Start application
./commands.sh status                # Check status
./scripts/setup-ssl.sh              # Setup SSL
```

Your portfolio is ready for production deployment with enterprise-grade features!