#!/bin/bash

# Zaihash Portfolio - VPS Deployment Chooser
# This script helps you choose between different deployment methods

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ╔═══════════════════════════════════════════════════╗    ║
║    ║           ZAIHASH PORTFOLIO                       ║    ║
║    ║         One-Click VPS Setup                       ║    ║
║    ╚═══════════════════════════════════════════════════╝    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}$1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check system requirements
log "Checking system requirements..."

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    error "sudo is required but not installed. Please install sudo first."
fi

# Check OS
if [[ ! -f /etc/os-release ]]; then
    error "Unsupported operating system. This script requires a Debian-based Linux distribution."
fi

. /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    warn "This script is optimized for Ubuntu/Debian. Other distributions may require manual adjustments."
fi

# Check available memory
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [[ $TOTAL_MEM -lt 512 ]]; then
    warn "Low memory detected ($TOTAL_MEM MB). Recommended: 1GB+ for optimal performance."
fi

# Check available disk space
AVAILABLE_SPACE=$(df / | awk 'NR==2 {printf "%.0f", $4/1024}')
if [[ $AVAILABLE_SPACE -lt 2048 ]]; then
    warn "Low disk space detected ($AVAILABLE_SPACE MB). Recommended: 5GB+ free space."
fi

echo ""
info "System Requirements Check Complete"
info "Memory: ${TOTAL_MEM}MB | Disk: ${AVAILABLE_SPACE}MB available"
echo ""

# Deployment method selection
echo -e "${CYAN}Choose your deployment method:${NC}"
echo ""
echo "1. 📦 Docker Deployment (Recommended)"
echo "   • Containerized setup with Docker & Docker Compose"
echo "   • Isolated environment with automatic scaling"
echo "   • Easy backup and restore"
echo "   • Production-ready with SSL support"
echo ""
echo "2. 🔧 Traditional Deployment"
echo "   • Direct installation with PM2 process manager"
echo "   • Native performance"
echo "   • More control over system configuration"
echo "   • Advanced monitoring and logging"
echo ""
echo "3. ⚡ Quick Development Setup"
echo "   • Minimal setup for development/testing"
echo "   • Fast deployment without production features"
echo "   • No SSL or advanced monitoring"
echo ""

while true; do
    echo -n -e "${YELLOW}Enter your choice (1-3): ${NC}"
    read -r choice
    case $choice in
        1)
            DEPLOYMENT_TYPE="docker"
            break
            ;;
        2)
            DEPLOYMENT_TYPE="traditional"
            break
            ;;
        3)
            DEPLOYMENT_TYPE="quick"
            break
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
            ;;
    esac
done

echo ""
log "Selected deployment type: $DEPLOYMENT_TYPE"

# Confirm deployment
echo ""
echo -e "${CYAN}Deployment Summary:${NC}"
case $DEPLOYMENT_TYPE in
    "docker")
        echo "• Installing Docker and Docker Compose"
        echo "• Setting up containerized environment"
        echo "• Configuring Nginx reverse proxy"
        echo "• PostgreSQL database in container"
        echo "• SSL certificate ready"
        echo "• Automated monitoring and backups"
        ;;
    "traditional")
        echo "• Installing Node.js and PM2"
        echo "• Setting up PostgreSQL database"
        echo "• Configuring Nginx web server"
        echo "• SSL certificate with Let's Encrypt"
        echo "• System-level monitoring"
        echo "• Automated backups and log rotation"
        ;;
    "quick")
        echo "• Installing Node.js"
        echo "• Basic application setup"
        echo "• Development-ready configuration"
        echo "• No SSL or advanced features"
        ;;
esac

echo ""
while true; do
    echo -n -e "${YELLOW}Proceed with installation? (y/n): ${NC}"
    read -r confirm
    case $confirm in
        [Yy]* ) break;;
        [Nn]* ) echo "Installation cancelled."; exit 0;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Execute chosen deployment
echo ""
log "Starting $DEPLOYMENT_TYPE deployment..."

case $DEPLOYMENT_TYPE in
    "docker")
        if [[ ! -f "docker-setup.sh" ]]; then
            error "docker-setup.sh not found. Please ensure all setup files are present."
        fi
        chmod +x docker-setup.sh
        ./docker-setup.sh
        ;;
    "traditional")
        if [[ ! -f "setup.sh" ]]; then
            error "setup.sh not found. Please ensure all setup files are present."
        fi
        chmod +x setup.sh
        ./setup.sh
        ;;
    "quick")
        # Quick setup
        log "Updating system packages..."
        sudo apt update && sudo apt upgrade -y
        
        log "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt install -y nodejs
        
        log "Installing dependencies..."
        npm install
        
        log "Building application..."
        npm run build
        
        log "Starting application..."
        npm run dev &
        
        echo ""
        log "Quick setup completed!"
        info "Application running at: http://localhost:5000"
        info "For production deployment, run this script again and choose option 1 or 2."
        ;;
esac

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    DEPLOYMENT COMPLETE!                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Post-installation instructions
case $DEPLOYMENT_TYPE in
    "docker")
        info "🐳 Docker Deployment Complete!"
        echo ""
        echo "Next steps:"
        echo "1. Configure your domain in .env file"
        echo "2. Run: cd /var/www/zaihash-portfolio && ./quick-start.sh"
        echo "3. Setup SSL: ./setup-ssl-docker.sh your-domain.com"
        echo ""
        echo "Management commands:"
        echo "• ./docker-manage.sh start    - Start services"
        echo "• ./docker-manage.sh logs     - View logs"
        echo "• ./docker-manage.sh status   - Check status"
        ;;
    "traditional")
        info "⚙️ Traditional Deployment Complete!"
        echo ""
        echo "Next steps:"
        echo "1. Configure your environment: cd /var/www/zaihash-portfolio"
        echo "2. Start application: ./start-app.sh"
        echo "3. Setup SSL: ./scripts/setup-ssl.sh"
        echo ""
        echo "Management commands:"
        echo "• ./commands.sh start     - Start application"
        echo "• ./commands.sh logs      - View logs"
        echo "• ./commands.sh status    - Check status"
        ;;
    "quick")
        info "⚡ Quick Setup Complete!"
        echo ""
        echo "Application is running in development mode"
        echo "Access your portfolio at: http://your-server-ip:5000"
        echo ""
        echo "For production deployment:"
        echo "• Run this script again"
        echo "• Choose Docker (option 1) or Traditional (option 2)"
        ;;
esac

echo ""
info "Documentation available in:"
case $DEPLOYMENT_TYPE in
    "docker")
        echo "• DOCKER_DEPLOYMENT.md - Complete Docker guide"
        ;;
    "traditional")
        echo "• DEPLOYMENT_README.md - Traditional deployment guide"
        ;;
esac

echo ""
log "Your Zaihash Portfolio is ready! 🚀"