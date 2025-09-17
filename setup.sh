#!/bin/bash

# Clean Laravel Docker Development Setup

set -e  # Exit on any error

echo "🔧 Setting up Laravel Docker development environment..."

# Get current user ID and group ID for proper file permissions
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

echo "📋 Using USER_ID=$USER_ID and GROUP_ID=$GROUP_ID"

# Rebuild with correct user mapping if needed
echo "🔧 Checking if rebuild is needed for user mapping..."

# Clean up any existing containers first
echo "🧹 Cleaning up existing containers..."
./dev.sh stop 2>/dev/null || true

# Build the development container with proper user mapping
echo "🏗️  Building development container..."
./dev.sh build

# Start the services (database and redis)
echo "🚀 Starting services (PostgreSQL + Redis)..."
./dev.sh start --postgres --redis

# Wait a moment for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 5

# Create vendor directory on host to avoid permission issues
echo "📁 Creating vendor directory..."
mkdir -p ../../catapult/vendor
chmod 755 ../../catapult/vendor

# Install composer dependencies (now that DB is available)
echo "📦 Installing Composer dependencies..."
./dev.sh composer install --no-scripts

# Run post-autoload scripts now that DB is available
echo "🔄 Running Composer post-autoload scripts..."
./dev.sh composer run-script post-autoload-dump || echo "⚠️  Some scripts may fail without proper Laravel setup - this is normal"

# Install npm dependencies
echo "📦 Installing NPM dependencies..."
./dev.sh npm install

echo ""
echo "✅ Development environment is ready!"
echo ""
echo "🌐 Available services:"
echo "   App:        http://localhost:8000"
echo "   Vite:       http://localhost:5173"
echo "   PostgreSQL: localhost:5432"
echo "   Redis:      localhost:6379"
echo ""
echo "🚀 Next steps:"
echo "   ./dev.sh artisan key:generate     # Generate app key"
echo "   ./dev.sh artisan migrate          # Run migrations"
echo "   ./dev.sh npm run dev              # Start frontend dev server"
echo ""
echo "💡 Useful commands:"
echo "   ./dev.sh shell                    # Get into container"
echo "   ./dev.sh logs                     # View logs"
echo "   ./dev.sh composer update          # Update dependencies"