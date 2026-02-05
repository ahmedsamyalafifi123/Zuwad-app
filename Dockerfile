# Multi-stage Dockerfile for Flutter Web App Deployment on Dokploy
# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:3.38.5 AS builder

# Set working directory
WORKDIR /app

# Copy pubspec files first for better layer caching
COPY pubspec.yaml ./

# Get dependencies (without pubspec.lock to avoid version conflicts)
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build the Flutter web app with release mode
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built Flutter web app from builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]