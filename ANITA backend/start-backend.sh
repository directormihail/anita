#!/bin/bash

# ANITA Backend Startup Script
# This script starts the backend server

cd "$(dirname "$0")"

echo "🚀 Starting ANITA Backend Server..."
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  Warning: .env file not found!"
    echo "   Make sure you've created .env with your keys"
    echo ""
fi

# Check if node_modules exists
if [ ! -d node_modules ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Start the server
echo "▶️  Starting server on http://localhost:3001"
echo "   Press Ctrl+C to stop"
echo ""

npm run dev

