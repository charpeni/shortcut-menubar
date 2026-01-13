#!/bin/bash

set -e

# Configuration
PROJECT_NAME="shortcut-menubar"
SCHEME="shortcut-menubar"
BUILD_DIR="build"
APP_NAME="Shortcut Menu Bar.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Get project root (same as script directory)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$PROJECT_ROOT"

# Parse arguments
CONFIGURATION="Release"
CLEAN=false
NO_OPEN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            CONFIGURATION="Debug"
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --no-open)
            NO_OPEN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --debug    Build in Debug configuration (default: Release)"
            echo "  --clean    Clean build folder before building"
            echo "  --no-open  Don't open the app after building"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}Building $PROJECT_NAME ($CONFIGURATION)...${NC}"

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo "Cleaning build folder..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Build the app
xcodebuild \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$PROJECT_NAME.xcarchive" \
    archive \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    -quiet

# Export the app from the archive
xcodebuild \
    -exportArchive \
    -archivePath "$BUILD_DIR/$PROJECT_NAME.xcarchive" \
    -exportPath "$BUILD_DIR/export" \
    -exportOptionsPlist "ExportOptions.plist" \
    2>/dev/null || {
    # If export fails (no signing), just copy from archive
    echo "Copying app from archive..."
    mkdir -p "$BUILD_DIR/export"
    cp -R "$BUILD_DIR/$PROJECT_NAME.xcarchive/Products/Applications/$PROJECT_NAME.app" "$BUILD_DIR/export/$APP_NAME"
}

# Find the app in the export directory
if [ -d "$BUILD_DIR/export/$PROJECT_NAME.app" ]; then
    APP_PATH="$BUILD_DIR/export/$PROJECT_NAME.app"
elif [ -d "$BUILD_DIR/export/$APP_NAME" ]; then
    APP_PATH="$BUILD_DIR/export/$APP_NAME"
else
    APP_PATH=""
fi

if [ -d "$APP_PATH" ]; then
    echo -e "${GREEN}Build successful!${NC}"
    echo "App location: $APP_PATH"
    
    # Show app size
    APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
    echo "App size: $APP_SIZE"
    
    # Open the app unless --no-open was specified
    if [ "$NO_OPEN" = false ]; then
        echo "Opening app..."
        open "$APP_PATH"
    fi
else
    echo -e "${RED}Build failed: App not found${NC}"
    exit 1
fi
