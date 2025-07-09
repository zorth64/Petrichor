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

# Logging functions
log() { echo -e "✅ $1"; }
error() { echo -e "❌ $1" >&2; }
warning() { echo -e "⚠️  $1"; }
info() { echo -e "ℹ️  $1"; }

# Progress animation
show_progress() {
    local pid=$1
    tput civis  # Hide cursor
    while kill -0 $pid 2>/dev/null; do
        for dots in "" "." ".." "..."; do
            printf "\r   Building%-4s " "$dots"
            sleep 0.1
            kill -0 $pid 2>/dev/null || break
        done
    done
    printf "\r                    \r"
    tput cnorm  # Show cursor
}

# Run xcodebuild with standard parameters
run_build() {
    local action="$1"
    local log_file="$2"
    local arch="$3"
    shift 3
    
    local cmd="xcodebuild $action \
        -project '$PROJECT' \
        -scheme '$SCHEME' \
        -configuration '$CONFIGURATION' \
        CODE_SIGN_IDENTITY='' \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        DEVELOPMENT_TEAM='' \
        MARKETING_VERSION='$VERSION' \
        CURRENT_PROJECT_VERSION='$VERSION' \
        ARCHS='$arch' \
        ONLY_ACTIVE_ARCH=NO \
        $*"
    
    if [ "$VERBOSE" = false ]; then
        cmd="$cmd -quiet"
        
        if command -v xcpretty >/dev/null 2>&1; then
            (eval "$cmd" 2>&1 | tee "$log_file" | xcpretty --no-utf --simple >/dev/null 2>&1) &
            local pid=$!
            show_progress $pid
            wait $pid
            return $?
        fi
    fi
    
    eval "$cmd" 2>&1 | tee "$log_file"
    return ${PIPESTATUS[0]}
}

# Create DMG for specific architecture
create_installer() {
    local arch="$1"
    local suffix="$2"
    local display_name="$3"
    
    log "Building $display_name version..."
    
    local archive_path="$BUILD_DIR/$APP_NAME-$suffix.xcarchive"
    local export_path="$BUILD_DIR/export-$suffix"
    local dmg_path="$BUILD_DIR/${APP_NAME}-${VERSION}-$suffix.dmg"
    local error_log="$BUILD_DIR/build-$suffix.log"
    
    # Step 1: Archive
    info "Archiving for $display_name..."
    run_build archive "$error_log" "$arch" \
        -archivePath "$archive_path" \
        -destination "platform=macOS"
    
    if [ ! -d "$archive_path" ]; then
        error "Archive failed for $display_name! Check $error_log for details"
        grep -E "(error:|ERROR:|failed|FAILED)" "$error_log" 2>/dev/null | tail -10
        return 1
    fi
    
    # Step 2: Extract app
    mkdir -p "$export_path"
    cp -R "$archive_path/Products/Applications/$APP_NAME.app" "$export_path/" || {
        error "Failed to extract app from archive for $display_name"
        return 1
    }
    
    # Step 3: Sign app
    info "Signing $display_name app..."
    codesign --remove-signature "$export_path/$APP_NAME.app" 2>/dev/null || true
    codesign --force --deep --strict --timestamp \
        --options runtime \
        --entitlements "Configuration/Petrichor.entitlements" \
        -s - \
        "$export_path/$APP_NAME.app" &>/dev/null || {
        error "Failed to sign app for $display_name"
        return 1
    }
    
    # Step 4: Create DMG
    info "Creating DMG for $display_name..."
    cd "$export_path"
    
    if command -v create-dmg >/dev/null 2>&1 && \
       (convert --version >/dev/null 2>&1 || gm version >/dev/null 2>&1); then
        # Use create-dmg
        # Keep title under 27 chars for create-dmg limitation
        local dmg_title="$APP_NAME $VERSION"
        if [ "$suffix" != "Universal" ]; then
            dmg_title="$APP_NAME-$suffix"
        fi
        create-dmg "$APP_NAME.app" --dmg-title="$dmg_title" || {
            error "create-dmg failed for $display_name"
            return 1
        }
        mv *.dmg "../${APP_NAME}-${VERSION}-$suffix.dmg"
    else
        # Fallback method
        cd ..
        DMG_DIR="$BUILD_DIR/dmg-$suffix"
        mkdir -p "$DMG_DIR"
        cp -R "$export_path/$APP_NAME.app" "$DMG_DIR/"
        ln -s /Applications "$DMG_DIR/Applications"
        
        hdiutil create -volname "$APP_NAME $VERSION" \
            -srcfolder "$DMG_DIR" -ov -format UDZO "$dmg_path"
        
        rm -rf "$DMG_DIR"
    fi
    
    cd - >/dev/null
    
    [ -f "$dmg_path" ] || { error "DMG creation failed for $display_name!"; return 1; }
    
    # Generate checksum
    cd "$BUILD_DIR"
    shasum -a 256 "$(basename "$dmg_path")" > "$(basename "$dmg_path").sha256"
    cd - >/dev/null
    
    # Cleanup
    rm -rf "$archive_path" "$export_path" "$error_log"
    
    log "$display_name installer created: $dmg_path"
    return 0
}

# Parse arguments
VERSION=""
VERBOSE=false
BUILD_UNIVERSAL=true
BUILD_INTEL=false
BUILD_ARM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --universal) BUILD_UNIVERSAL=true; BUILD_INTEL=false; BUILD_ARM=false; shift ;;
        --intel-only) BUILD_INTEL=true; BUILD_UNIVERSAL=false; BUILD_ARM=false; shift ;;
        --arm-only) BUILD_ARM=true; BUILD_UNIVERSAL=false; BUILD_INTEL=false; shift ;;
        --separate) BUILD_UNIVERSAL=false; BUILD_INTEL=true; BUILD_ARM=true; shift ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --version <version>  Specify version number (e.g., 1.0.0)"
            echo "  --verbose           Show full build output"
            echo "  --universal         Build universal binary (default)"
            echo "  --intel-only        Build Intel-only installer"
            echo "  --arm-only          Build Apple Silicon-only installer"
            echo "  --separate          Build separate Intel and Apple Silicon installers"
            echo "  --help              Show this help message"
            exit 0 ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
done

# Detect version if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || \
              xcodebuild -showBuildSettings -project "$PROJECT" 2>/dev/null | \
              grep "MARKETING_VERSION" | head -1 | awk '{print $3}' || \
              echo "1.0.0")
    log "Using version: $VERSION"
fi

# Setup paths
BUILD_DIR="build"

# Prepare build directory
log "Building $APP_NAME version $VERSION"
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"

# Build based on selected options
if [ "$BUILD_UNIVERSAL" = true ]; then
    create_installer "x86_64 arm64" "Universal" "Universal"
fi

if [ "$BUILD_INTEL" = true ] && [ "$BUILD_UNIVERSAL" = false ]; then
    create_installer "x86_64" "Intel" "Intel"
fi

if [ "$BUILD_ARM" = true ] && [ "$BUILD_UNIVERSAL" = false ]; then
    create_installer "arm64" "AppleSilicon" "Apple Silicon"
fi

# Summary
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# List all created DMGs
for dmg in "$BUILD_DIR"/*.dmg; do
    if [ -f "$dmg" ]; then
        echo -e "📦 $(basename "$dmg")"
        echo -e "   📏 Size: ${GREEN}$(du -h "$dmg" | cut -f1)${NC}"
        echo -e "   📋 SHA256: ${GREEN}$(cat "$dmg.sha256" | awk '{print $1}')${NC}"
        echo ""
    fi
done

# GitHub Actions outputs (for the first DMG found)
if [ -n "$GITHUB_ACTIONS" ]; then
    for dmg in "$BUILD_DIR"/*.dmg; do
        if [ -f "$dmg" ]; then
            {
                echo "dmg-path=$dmg"
                echo "dmg-name=$(basename "$dmg")"
                echo "version=$VERSION"
                echo "sha256=$(cat "$dmg.sha256" | awk '{print $1}')"
            } >> "$GITHUB_OUTPUT"
            break
        fi
    done
fi

log "Done!"