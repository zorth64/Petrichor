#!/bin/bash

# build-installer.sh - Build and create a signed DMG installer for Petrichor

set -e  # Exit on error

# Configuration
APP_NAME="Petrichor"
SCHEME="Petrichor"
CONFIGURATION="Release"
PROJECT="Petrichor.xcodeproj"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    echo -e "✅ $1"
}

error() {
    echo -e "❌ $1" >&2
}

warning() {
    echo -e "⚠️  $1"
}

info() {
    echo -e "ℹ️  $1"
}

# Check if xcpretty is available
HAS_XCPRETTY=false
if command -v xcpretty >/dev/null 2>&1; then
    HAS_XCPRETTY=true
    log "Using xcpretty for formatted output"
else
    warning "xcpretty not found. Output will be verbose."
    warning "To install xcpretty: gem install xcpretty"
fi

# Parse command line arguments
VERSION=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --version <version>  Specify version number (e.g., 1.0.0)"
            echo "  --verbose           Show full build output"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Override xcpretty if verbose mode
if [ "$VERBOSE" = true ]; then
    HAS_XCPRETTY=false
    log "Verbose mode: showing full build output"
fi

# Set version from git tag if not specified
if [ -z "$VERSION" ]; then
    # Try to get the latest git tag
    GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$GIT_TAG" ]; then
        # Remove 'v' prefix if present
        VERSION=${GIT_TAG#v}
        log "Using version from git tag: $GIT_TAG -> $VERSION"
    else
        # No git tag found, try to get version from Xcode project
        XCODE_VERSION=$(xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" 2>/dev/null | grep "MARKETING_VERSION" | head -1 | awk '{print $3}')
        if [ -n "$XCODE_VERSION" ]; then
            VERSION="$XCODE_VERSION"
            log "Using version from Xcode project settings: $VERSION"
        else
            # Final fallback
            VERSION="1.0.0"
            warning "No version found in git tags or Xcode project, using default: $VERSION"
        fi
    fi
fi

# Create build directory
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"

log "Building $APP_NAME version $VERSION"
info "Creating build directories..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Archive the app
log "Archiving $APP_NAME..."
info "This may take a few minutes..."

# Show a note about build time
if [ "$HAS_XCPRETTY" = true ] && [ "$VERBOSE" = false ]; then
    info "Compiling Swift files..."
fi

# Create a temp file for capturing errors
ERROR_LOG="$BUILD_DIR/archive_errors.log"

# Function to show progress
show_progress() {
    local pid=$1
    local delay=0.1
    local elapsed=0
    
    # Hide cursor
    tput civis
    
    while kill -0 $pid 2>/dev/null; do
        elapsed=$((elapsed + 1))
        local dots=$((elapsed % 4))
        local dot_string=$(printf '%*s' $dots | tr ' ' '.')
        printf "\r   Building%-4s " "$dot_string"
        sleep $delay
    done
    
    # Clear line and show cursor
    printf "\r                    \r"
    tput cnorm
}

# Run archive command and capture exit code
if [ "$HAS_XCPRETTY" = true ]; then
    set -o pipefail
    (
        xcodebuild archive \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -archivePath "$ARCHIVE_PATH" \
            -destination "platform=macOS" \
            CODE_SIGN_IDENTITY="" \
            "CODE_SIGN_IDENTITY[config=Release]"="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGN_STYLE="Manual" \
            PROVISIONING_PROFILE_SPECIFIER="" \
            DEVELOPMENT_TEAM="" \
            MARKETING_VERSION="$VERSION" \
            CURRENT_PROJECT_VERSION="$VERSION" \
            -quiet \
            2>&1 | tee "$ERROR_LOG" | xcpretty --no-utf --simple >/dev/null 2>&1
    ) &
    BUILD_PID=$!
    
    if [ "$VERBOSE" = false ]; then
        show_progress $BUILD_PID
    fi
    
    wait $BUILD_PID
    ARCHIVE_RESULT=$?
else
    if [ "$VERBOSE" = true ]; then
        xcodebuild archive \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -archivePath "$ARCHIVE_PATH" \
            -destination "platform=macOS" \
            CODE_SIGN_IDENTITY="" \
            "CODE_SIGN_IDENTITY[config=Release]"="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGN_STYLE="Manual" \
            PROVISIONING_PROFILE_SPECIFIER="" \
            DEVELOPMENT_TEAM="" \
            MARKETING_VERSION="$VERSION" \
            CURRENT_PROJECT_VERSION="$VERSION" \
            2>&1 | tee "$ERROR_LOG"
        ARCHIVE_RESULT=$?
    else
        (
            xcodebuild archive \
                -project "$PROJECT" \
                -scheme "$SCHEME" \
                -configuration "$CONFIGURATION" \
                -archivePath "$ARCHIVE_PATH" \
                -destination "platform=macOS" \
                CODE_SIGN_IDENTITY="" \
                "CODE_SIGN_IDENTITY[config=Release]"="" \
                CODE_SIGNING_REQUIRED=NO \
                CODE_SIGNING_ALLOWED=NO \
                CODE_SIGN_STYLE="Manual" \
                PROVISIONING_PROFILE_SPECIFIER="" \
                DEVELOPMENT_TEAM="" \
                MARKETING_VERSION="$VERSION" \
                CURRENT_PROJECT_VERSION="$VERSION" \
                -quiet \
                > "$ERROR_LOG" 2>&1
        ) &
        BUILD_PID=$!
        show_progress $BUILD_PID
        wait $BUILD_PID
        ARCHIVE_RESULT=$?
    fi
fi

# Check if archive command succeeded
if [ $ARCHIVE_RESULT -ne 0 ]; then
    error "Archive command failed with exit code: $ARCHIVE_RESULT"
    error "Error details:"
    grep -E "(error:|ERROR:|failed|FAILED)" "$ERROR_LOG" | grep -v "warning:" | tail -20
    exit 1
fi

# Double-check archive was created
if [ ! -d "$ARCHIVE_PATH" ]; then
    error "Archive command completed but archive not found at $ARCHIVE_PATH"
    log "Contents of build directory:"
    ls -la "$BUILD_DIR"
    log "Checking for errors in log:"
    grep -E "(error:|ERROR:|warning:|WARNING:)" "$ERROR_LOG" | tail -20
    exit 1
fi

log "Archive created successfully"
rm -f "$ERROR_LOG"

# Step 2: Copy app from archive (skip export for unsigned build)
log "Copying app from archive..."

# Create export directory
mkdir -p "$EXPORT_PATH"

# Copy the app directly from archive
APP_IN_ARCHIVE="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
if [ -d "$APP_IN_ARCHIVE" ]; then
    log "Copying $APP_NAME.app from archive to export directory..."
    cp -R "$APP_IN_ARCHIVE" "$EXPORT_PATH/" || {
        error "Failed to copy app from archive"
        exit 1
    }
else
    error "App not found in archive!"
    error "Expected at: $APP_IN_ARCHIVE"
    log "Archive contents:"
    find "$ARCHIVE_PATH" -name "*.app" -type d
    exit 1
fi

if [ ! -d "$EXPORT_PATH/$APP_NAME.app" ]; then
    error "App not found after copying to export directory"
    exit 1
fi

log "App copied successfully"

# Step 3: Optional - Ad-hoc sign the app to prevent "damaged" warnings
log "Applying ad-hoc signature..."
if [ -d "$EXPORT_PATH/$APP_NAME.app" ]; then
    if [ "$VERBOSE" = true ]; then
        codesign --force --deep -s - "$EXPORT_PATH/$APP_NAME.app" 2>&1 || {
            warning "Could not apply ad-hoc signature, continuing anyway..."
        }
    else
        codesign --force --deep -s - "$EXPORT_PATH/$APP_NAME.app" >/dev/null 2>&1 || {
            warning "Could not apply ad-hoc signature, continuing anyway..."
        }
    fi
else
    error "App not found at: $EXPORT_PATH/$APP_NAME.app"
    exit 1
fi

# Step 4: Create DMG
log "Creating DMG installer..."

# Check if create-dmg and its dependencies are available
CREATE_DMG_AVAILABLE=false
log "Checking for create-dmg..."
if command -v create-dmg >/dev/null 2>&1; then
    log "create-dmg found at: $(which create-dmg)"
    # Check for ImageMagick (convert) or GraphicsMagick (gm)
    # Note: We check if 'convert' or 'gm' can actually run with version flag
    if convert --version >/dev/null 2>&1; then
        CREATE_DMG_AVAILABLE=true
        log "Found ImageMagick - will use create-dmg"
    elif gm version >/dev/null 2>&1; then
        CREATE_DMG_AVAILABLE=true
        log "Found GraphicsMagick - will use create-dmg"
    else
        warning "create-dmg found but ImageMagick/GraphicsMagick not installed"
        warning "Install with: brew install imagemagick"
    fi
else
    warning "create-dmg not found"
fi

if [ "$CREATE_DMG_AVAILABLE" = true ]; then
    # Use create-dmg for a beautiful DMG
    log "Creating DMG with create-dmg..."
    cd "$EXPORT_PATH"
    
    log "Running: create-dmg $APP_NAME.app --dmg-title='$APP_NAME $VERSION'"
    if create-dmg "$APP_NAME.app" --dmg-title="$APP_NAME $VERSION"; then
        log "create-dmg completed"
    else
        error "create-dmg failed"
        exit 1
    fi
    
    # Find and rename the DMG
    created_dmg=$(ls -1 *.dmg 2>/dev/null | head -1)
    if [ -n "$created_dmg" ]; then
        log "Found DMG: $created_dmg"
        mv "$created_dmg" "../${APP_NAME}-${VERSION}.dmg"
        cd - >/dev/null
        DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"
    else
        error "DMG not found after create-dmg"
        exit 1
    fi
else
    # Fallback: Create basic DMG without create-dmg
    log "Using fallback DMG creation method..."
    log "BUILD_DIR=$BUILD_DIR"
    log "EXPORT_PATH=$EXPORT_PATH"
    log "APP_NAME=$APP_NAME"
    
    DMG_DIR="$BUILD_DIR/dmg"
    log "DMG_DIR=$DMG_DIR"
    mkdir -p "$DMG_DIR"
    
    # Debug: Log what we're doing
    log "Copying $EXPORT_PATH/$APP_NAME.app to $DMG_DIR/"
    
    # Copy app to DMG staging directory
    if [ -d "$EXPORT_PATH/$APP_NAME.app" ]; then
        cp -R "$EXPORT_PATH/$APP_NAME.app" "$DMG_DIR/" || {
            error "Failed to copy app"
            error "Source: $EXPORT_PATH/$APP_NAME.app"
            error "Destination: $DMG_DIR/"
            exit 1
        }
    else
        error "App not found at: $EXPORT_PATH/$APP_NAME.app"
        exit 1
    fi
    
    # Create Applications symlink
    ln -s /Applications "$DMG_DIR/Applications"
    
    # Create DMG
    DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"
    hdiutil create \
        -volname "$APP_NAME $VERSION" \
        -srcfolder "$DMG_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH"
    
    # Cleanup DMG staging
    rm -rf "$DMG_DIR"
fi

if [ ! -f "$DMG_PATH" ]; then
    error "DMG creation failed!"
    exit 1
fi

log "DMG created successfully at: $DMG_PATH"

# Note about signing
log "Checking for Developer ID certificate..."
DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk '{print $2}' || true)
if [ -z "$DEVELOPER_ID" ]; then
    warning "No Developer ID certificate found"
    warning "DMG is unsigned. Users will need to right-click → Open when first launching"
else
    log "Note: create-dmg automatically signs DMGs when Developer ID is available"
fi

# Step 5: Generate checksums
log "Generating checksums..."
cd "$BUILD_DIR" || exit 1
shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256"
cd - > /dev/null

log "Checksum: $(cat "$DMG_PATH.sha256")"

# Step 6: Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📦 Installer: ${GREEN}$DMG_PATH${NC}"
echo -e "📏 Size: ${GREEN}$(du -h "$DMG_PATH" | cut -f1)${NC}"
echo -e "🔖 Version: ${GREEN}$VERSION${NC}"
echo -e "🔐 Signed: ${YELLOW}No (unsigned build)${NC}"
echo -e "📋 Checksum: ${GREEN}$(basename "$DMG_PATH").sha256${NC}"
echo ""
echo -e "${GREEN}Installation Instructions:${NC}"
echo "  1. Open the DMG file"
echo "  2. Drag Petrichor to Applications"
echo "  3. Right-click Petrichor and select 'Open' on first launch"
echo "  4. Click 'Open' in the security dialog"
echo ""

# Step 7: Final cleanup
log "Cleaning up build artifacts..."

# Remove everything except DMG and checksum
if [ -d "$ARCHIVE_PATH" ]; then
    rm -rf "$ARCHIVE_PATH"
fi
if [ -d "$EXPORT_PATH" ]; then
    rm -rf "$EXPORT_PATH"
fi
if [ -f "$BUILD_DIR/archive_errors.log" ]; then
    rm -f "$BUILD_DIR/archive_errors.log"
fi

# If in CI, set output variables
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "dmg-path=$DMG_PATH" >> $GITHUB_OUTPUT
    echo "dmg-name=$(basename "$DMG_PATH")" >> $GITHUB_OUTPUT
    echo "version=$VERSION" >> $GITHUB_OUTPUT
    echo "sha256=$(cat "$DMG_PATH.sha256" | awk '{print $1}')" >> $GITHUB_OUTPUT
fi

log "Done!"