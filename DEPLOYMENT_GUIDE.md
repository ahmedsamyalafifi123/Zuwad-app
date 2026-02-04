# Zuwad Academy - Dokploy Deployment Guide

This guide explains how to deploy the Zuwad Flutter web app to your Dokploy server.

---

## 📋 Prerequisites

1. **Dokploy Server**: You have a server with Dokploy installed and running
2. **Domain Name**: A domain/subdomain pointing to your Dokploy server
3. **Git Repository**: Your code should be pushed to a Git repository (GitHub, GitLab, etc.)

---

## 🏗️ What Was Created

I've created the following deployment files for you:

### 1. [`Dockerfile`](Dockerfile)

Multi-stage Docker build that:

- Uses Flutter 3.27.0 to build the web app
- Compiles with CanvasKit renderer for better performance
- Serves the app using Nginx Alpine

### 2. [`nginx.conf`](nginx.conf)

Nginx configuration with:

- Gzip compression for faster loading
- Proper caching for static assets
- Flutter route handling (SPA support)
- Security headers
- CORS support for API calls

### 3. [`.dockerignore`](.dockerignore)

Excludes unnecessary files from Docker build to reduce image size.

---

## 🚀 Deployment Steps on Dokploy

### Step 1: Push Code to Git Repository

Make sure all files are committed and pushed:

```bash
git add Dockerfile nginx.conf .dockerignore DEPLOYMENT_GUIDE.md
git commit -m "Add Dokploy deployment configuration"
git push origin main
```

### Step 2: Create Application in Dokploy

1. **Login to your Dokploy dashboard**
   - Go to `https://your-dokploy-server.com`

2. **Create a New Application**
   - Click **"Create Application"**
   - Select **"Git"** as the source
   - Choose your provider (GitHub/GitLab) or use **"Git Repository"** for custom

3. **Configure Git Repository**
   - Repository URL: `https://github.com/yourusername/zuwad.git`
   - Branch: `main` (or your default branch)
   - Build Path: `/` (root)

4. **Build Configuration**
   - Build Type: **Dockerfile**
   - Dockerfile Path: `./Dockerfile`
   - Port: `80`

5. **Environment Variables** (Optional)
   If you need to override the default API URLs:
   - `BASE_URL`: Your WordPress backend URL
   - `LIVEKIT_URL`: Your LiveKit server URL

### Step 3: Configure Domain

1. Go to the **Domains** tab in your application
2. Click **"Add Domain"**
3. Enter your domain: `app.zuwad-academy.com` (or your domain)
4. Enable **HTTPS** (Let's Encrypt)
5. Click **Save**

### Step 4: Deploy

1. Click **"Deploy"** button
2. Dokploy will:
   - Clone your repository
   - Build the Docker image
   - Deploy the container
   - Configure Nginx reverse proxy

3. Wait for the build to complete (usually 3-5 minutes for first build)

### Step 5: Verify Deployment

1. Visit your domain: `https://app.zuwad-academy.com`
2. Check that the app loads correctly
3. Test login and main features

---

## 🔧 Important Configuration Notes

### API Base URL

The app uses [`lib/core/config/env_config.dart`](lib/core/config/env_config.dart) for API configuration:

```dart
static const String baseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://system.zuwad-academy.com',
);
```

**Current default**: `https://system.zuwad-academy.com`

If your backend is on the same server or different domain, update this in Dokploy environment variables.

### LiveKit Configuration

```dart
static const String livekitUrl = String.fromEnvironment(
  'LIVEKIT_URL',
  defaultValue: 'wss://livekit.zuwad-academy.com',
);
```

### Web-Specific Limitations

Since this is a web deployment, some mobile features won't work:

| Feature            | Web Support | Notes                                     |
| ------------------ | ----------- | ----------------------------------------- |
| Push Notifications | ⚠️ Limited  | FCM works on web but needs service worker |
| Local Alarms       | ❌ No       | Use backend notifications instead         |
| Local Database     | ⚠️ Limited  | Uses IndexedDB instead of SQLite          |
| File Picker        | ✅ Yes      | Works with browser file picker            |
| Camera/Mic         | ✅ Yes      | For LiveKit meetings                      |
| Audio Playback     | ✅ Yes      | Works in browser                          |

---

## 🔄 Updating the App

To deploy updates:

1. Make your code changes
2. Commit and push to Git:
   ```bash
   git add .
   git commit -m "Your changes"
   git push origin main
   ```
3. Go to Dokploy dashboard
4. Click **"Deploy"** on your application
5. Dokploy will automatically pull and rebuild

---

## 🐛 Troubleshooting

### Build Fails

**Check Flutter version compatibility:**

```bash
# The Dockerfile uses Flutter 3.27.0
# Make sure your pubspec.yaml SDK constraint matches
```

**View build logs in Dokploy:**

- Go to your application → Logs tab

### App Shows Blank Page

1. Check browser console for errors
2. Verify `base href` in `web/index.html`:
   ```html
   <base href="/" />
   ```
3. For subpath deployment (e.g., `/app`), update:
   ```html
   <base href="/app/" />
   ```

### API Calls Failing (CORS)

If your WordPress backend blocks requests:

1. Add to your WordPress `wp-config.php` or use a CORS plugin:

   ```php
   header("Access-Control-Allow-Origin: *");
   header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
   header("Access-Control-Allow-Headers: Authorization, Content-Type");
   ```

2. Or configure Dokploy to proxy API requests

### Assets Not Loading

Check that all assets are included in [`pubspec.yaml`](pubspec.yaml):

```yaml
assets:
  - assets/images/
  - assets/audio/
  # etc...
```

---

## 📊 Performance Optimization

The current setup includes:

- ✅ CanvasKit renderer (better performance than HTML renderer)
- ✅ Gzip compression enabled
- ✅ Static asset caching (1 year for images/fonts)
- ✅ Service worker caching

### For Better Performance:

1. **Use CDN for assets** (CloudFlare, etc.)
2. **Enable HTTP/2** in Dokploy Nginx config
3. **Preload critical fonts** in `web/index.html`

---

## 🔒 Security Checklist

- ✅ HTTPS enabled via Dokploy/Let's Encrypt
- ✅ Security headers in Nginx config
- ✅ No sensitive data in Docker image
- ✅ CORS properly configured

### Additional Security (Recommended):

1. **Add rate limiting** in Dokploy
2. **Enable Web Application Firewall (WAF)** if available
3. **Set up monitoring** for failed requests

---

## 📞 Support

If you encounter issues:

1. Check Dokploy logs first
2. Test locally with: `flutter build web --release`
3. Verify Docker build locally:
   ```bash
   docker build -t zuwad-web .
   docker run -p 8080:80 zuwad-web
   ```
   Then visit `http://localhost:8080`

---

## 📝 Summary

You now have:

1. ✅ `Dockerfile` - Multi-stage build for production
2. ✅ `nginx.conf` - Optimized web server configuration
3. ✅ `.dockerignore` - Reduced build context
4. ✅ This guide - Step-by-step deployment instructions

**Next Steps:**

1. Push these files to your Git repository
2. Create application in Dokploy dashboard
3. Configure your domain
4. Deploy!

Your Zuwad Academy app will be live on the web! 🎉
