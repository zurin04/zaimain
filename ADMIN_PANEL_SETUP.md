# Zaihash Portfolio - Complete Admin Panel Setup

## Overview

Your portfolio now includes a complete Web3-based admin panel system accessible at `admin.zaihash.xyz` with the following features:

- **Web3 Wallet Authentication**: Only authorized wallet `0x4aa26202ef61c6c7867046afd4ef2cf4c3dc2afd` can access
- **Content Management**: Edit site settings, social links, contact info, and posts
- **Database Integration**: PostgreSQL with Drizzle ORM
- **Secure API**: Role-based access control with wallet verification
- **Production Ready**: Optimized Nginx configuration with rate limiting

## Features Implemented

### 1. Web3 Authentication System
- SIWE (Sign-In with Ethereum) integration
- MetaMask wallet connection
- Signature verification for admin access
- Session management with localStorage

### 2. Admin Panel Sections

#### Settings Management
- Site name and description
- Hero section content
- About section content
- Real-time content updates

#### Social Links Management
- Add/Edit/Delete social media links
- Platform, URL, and icon configuration
- Visibility toggles and ordering
- Support for GitHub, LinkedIn, Twitter, etc.

#### Contact Information
- Email address management
- Phone number and location
- Availability status
- Real-time updates to main site

#### Posts & Announcements
- Create and edit blog posts
- Draft/Published/Archived status
- Post types: regular posts and announcements
- Featured images and tags support
- SEO-friendly slugs

### 3. Database Schema

```sql
-- Admin management
CREATE TABLE admins (
  id SERIAL PRIMARY KEY,
  wallet_address TEXT UNIQUE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  last_login TIMESTAMP
);

-- Site settings
CREATE TABLE site_settings (
  id SERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value JSON NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT NOW(),
  updated_by TEXT NOT NULL
);

-- Social links
CREATE TABLE social_links (
  id SERIAL PRIMARY KEY,
  platform TEXT NOT NULL,
  url TEXT NOT NULL,
  icon TEXT,
  is_visible BOOLEAN DEFAULT true,
  order INTEGER DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Posts and announcements
CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  excerpt TEXT,
  slug TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'draft',
  type TEXT DEFAULT 'post',
  featured_image TEXT,
  tags JSON,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  published_at TIMESTAMP,
  author_wallet TEXT NOT NULL
);

-- Contact information
CREATE TABLE contact_info (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  phone TEXT,
  location TEXT,
  availability TEXT,
  updated_at TIMESTAMP DEFAULT NOW(),
  updated_by TEXT NOT NULL
);
```

## VPS Deployment Setup

### 1. Domain Configuration

The setup includes configurations for both domains:

**Main Site**: `zaihash.xyz` and `www.zaihash.xyz`
**Admin Panel**: `admin.zaihash.xyz`

### 2. Nginx Configuration

```nginx
# Main site configuration
server {
    listen 80;
    server_name zaihash.xyz www.zaihash.xyz;
    
    location / {
        proxy_pass http://localhost:3000;
        # Standard proxy headers
    }
}

# Admin panel configuration
server {
    listen 80;
    server_name admin.zaihash.xyz;
    
    # Enhanced security for admin
    location / {
        limit_req zone=admin burst=10 nodelay;
        proxy_pass http://localhost:3000;
        proxy_set_header X-Admin-Domain "true";
    }
    
    # Stricter API rate limiting
    location /api/ {
        limit_req zone=admin burst=5 nodelay;
        proxy_pass http://localhost:3000;
    }
}
```

### 3. Security Features

- **Rate Limiting**: Admin endpoints have stricter rate limits
- **CORS Protection**: Separate headers for admin domain
- **Wallet Verification**: Only authorized wallet can access admin functions
- **SSL Ready**: Let's Encrypt integration included
- **Firewall Configuration**: UFW rules for secure access

## API Endpoints

### Public Content API (for main website)
```
GET /api/content/settings      - Site settings
GET /api/content/social-links  - Visible social links
GET /api/content/contact       - Contact information
GET /api/content/posts         - Published posts
GET /api/content/posts/:slug   - Individual post
```

### Admin API (requires authentication)
```
POST /api/auth/verify          - Wallet authentication

GET  /api/admin/settings       - All settings
POST /api/admin/settings       - Update setting

GET  /api/admin/social-links   - All social links
POST /api/admin/social-links   - Create link
PUT  /api/admin/social-links/:id - Update link
DELETE /api/admin/social-links/:id - Delete link

GET  /api/admin/contact        - Contact info
POST /api/admin/contact        - Update contact

GET  /api/admin/posts          - All posts
GET  /api/admin/posts/:id      - Single post
POST /api/admin/posts          - Create post
PUT  /api/admin/posts/:id      - Update post
DELETE /api/admin/posts/:id    - Delete post
```

## Deployment Instructions

### 1. One-Click VPS Setup

```bash
# Upload files to VPS
scp -r . user@your-vps:/home/user/zaihash-portfolio

# Run deployment script
cd zaihash-portfolio
chmod +x deploy-vps.sh
./deploy-vps.sh

# Choose option 1 (Docker) or 2 (Traditional)
```

### 2. Domain Configuration

Update your DNS records:
```
A    zaihash.xyz          -> YOUR_VPS_IP
A    www.zaihash.xyz      -> YOUR_VPS_IP
A    admin.zaihash.xyz    -> YOUR_VPS_IP
```

### 3. SSL Setup

```bash
# For Docker deployment
./setup-ssl-docker.sh zaihash.xyz

# For traditional deployment
./scripts/setup-ssl.sh
```

### 4. Database Migration

```bash
# The database schema is automatically created
# Your admin wallet is pre-configured
npm run db:push
```

## Admin Panel Access

1. **Navigate to**: `https://admin.zaihash.xyz`
2. **Connect Wallet**: MetaMask with your authorized wallet
3. **Sign Message**: SIWE authentication
4. **Access Dashboard**: Full content management capabilities

## Security Considerations

### Wallet Security
- Admin wallet: `0x4aa26202ef61c6c7867046afd4ef2cf4c3dc2afd`
- Only this wallet can access admin functions
- Private key must be securely stored
- Consider hardware wallet for production

### Network Security
- Admin subdomain has separate rate limiting
- Enhanced monitoring for admin access
- SSL certificate required for production
- Regular security updates recommended

### Backup Strategy
- Database backups automated daily
- Admin wallet backup essential
- Site settings and content backed up
- Recovery procedures documented

## Usage Guide

### Managing Site Content

1. **Site Settings**: Update site name, description, hero content
2. **Social Links**: Add/remove social media profiles
3. **Contact Info**: Update email, location, availability
4. **Posts**: Create announcements and blog posts

### Content Publishing Workflow

1. Create post in admin panel
2. Set status to "draft" for review
3. Add featured image and tags
4. Publish when ready
5. View on main site immediately

### Monitoring and Maintenance

- Check admin panel logs: `./commands.sh logs`
- Monitor database health: Admin panel shows stats
- Review security logs regularly
- Update content as needed

## Support and Troubleshooting

### Common Issues

**Cannot access admin panel**:
- Verify wallet address is correct
- Check network connection
- Clear browser cache and try again

**Database connection errors**:
- Verify DATABASE_URL is set
- Check PostgreSQL service status
- Review connection logs

**Nginx configuration issues**:
- Test config: `sudo nginx -t`
- Check domain DNS settings
- Verify SSL certificates

### Getting Help

1. Check deployment logs in VPS
2. Review browser console for errors
3. Verify wallet signature process
4. Test API endpoints directly

Your admin panel is now fully operational with comprehensive content management capabilities, secure Web3 authentication, and production-ready deployment configuration.