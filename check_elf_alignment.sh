#!/bin/bash

# Script to check ELF alignment for 16KB page size compatibility
# This script checks all .so files in the APK for proper alignment

echo "Checking ELF alignment for 16KB page size compatibility..."
echo "================================================"

# Function to check a single .so file
check_so_file() {
    local file="$1"
    echo "Checking: $file"
    
    # Check if file exists and is an ELF file
    if [[ ! -f "$file" ]]; then
        echo "  ❌ File not found: $file"
        return 1
    fi
    
    # Use readelf to check program headers
    if command -v readelf >/dev/null 2>&1; then
        # Check LOAD segments alignment
        readelf -l "$file" | grep LOAD | while read -r line; do
            # Extract alignment value (last column)
            alignment=$(echo "$line" | awk '{print $NF}')
            
            # Convert hex to decimal if needed
            if [[ $alignment == 0x* ]]; then
                alignment=$((alignment))
            fi
            
            # Check if alignment is >= 16384 (16KB)
            if [[ $alignment -ge 16384 ]]; then
                echo "  ✅ LOAD segment aligned to $alignment bytes (>= 16KB)"
            else
                echo "  ❌ LOAD segment aligned to $alignment bytes (< 16KB) - NEEDS FIX"
                return 1
            fi
        done
    else
        echo "  ⚠️  readelf not available, skipping detailed check"
    fi
    
    return 0
}

# Find and check all .so files in common locations
echo "Searching for .so files..."

# Check in build outputs
find . -name "*.so" -type f 2>/dev/null | while read -r so_file; do
    check_so_file "$so_file"
done

# If APK exists, extract and check .so files from it
if [[ -f "build/app/outputs/flutter-apk/app-release.apk" ]]; then
    echo ""
    echo "Checking .so files in APK..."
    
    # Create temp directory
    temp_dir=$(mktemp -d)
    
    # Extract APK
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "build/app/outputs/flutter-apk/app-release.apk" -d "$temp_dir"
        
        # Check .so files in APK
        find "$temp_dir" -name "*.so" -type f | while read -r so_file; do
            check_so_file "$so_file"
        done
        
        # Clean up
        rm -rf "$temp_dir"
    else
        echo "  ⚠️  unzip not available, cannot check APK contents"
    fi
fi

echo ""
echo "Alignment check completed!"
echo "If any files show alignment < 16KB, rebuild with updated toolchain."