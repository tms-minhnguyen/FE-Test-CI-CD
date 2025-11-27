#!/bin/bash

echo "Setting up MongoDB for Next.js Login Page..."

# Check if MongoDB is already installed
if brew list mongodb-community &>/dev/null; then
    echo "MongoDB is already installed."
else
    echo "Installing MongoDB..."
    brew tap mongodb/brew
    brew install mongodb-community
fi

# Check if MongoDB service is running
if brew services list | grep -q "mongodb-community.*started"; then
    echo "MongoDB service is already running."
else
    echo "Starting MongoDB service..."
    brew services start mongodb/brew/mongodb-community
    echo "Waiting for MongoDB to start..."
    sleep 3
fi

# Verify MongoDB is running
if mongosh --eval "db.version()" --quiet &>/dev/null; then
    echo "✓ MongoDB is running successfully!"
    echo "Connection string: mongodb://localhost:27017/nextjs-auth"
else
    echo "⚠ MongoDB might not be ready yet. Please wait a few seconds and try again."
    echo "You can check MongoDB status with: brew services list"
fi

