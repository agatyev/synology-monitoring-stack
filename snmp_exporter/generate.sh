#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MIB_URL="https://global.synology.com/download/Document/Software/DeveloperGuide/Firmware/DSM/All/enu/Synology_MIB_File.zip"
MIB_DIR="$SCRIPT_DIR/mibs"
GENERATOR_IMAGE="prom/snmp-generator:v0.29.0"

echo "=== Synology SNMP Exporter Config Generator ==="

# Step 1: Download Synology MIBs
if [ ! -d "$MIB_DIR" ] || [ -z "$(ls -A "$MIB_DIR" 2>/dev/null)" ]; then
    echo "[1/3] Downloading Synology MIBs..."
    mkdir -p "$MIB_DIR"
    TMP_ZIP=$(mktemp /tmp/synology_mibs.XXXXXX.zip)
    curl -sL "$MIB_URL" -o "$TMP_ZIP"
    unzip -qo "$TMP_ZIP" -d "$MIB_DIR"
    rm -f "$TMP_ZIP"
    echo "      MIBs extracted to $MIB_DIR"
else
    echo "[1/3] Synology MIBs already present in $MIB_DIR"
fi

# Step 2: Generate snmp.yml
echo "[2/3] Generating snmp.yml using $GENERATOR_IMAGE ..."
docker run --rm \
    -v "$SCRIPT_DIR/generator.yml:/opt/generator.yml:ro" \
    -v "$MIB_DIR:/opt/mibs:ro" \
    "$GENERATOR_IMAGE" \
    generate \
    -g /opt/generator.yml \
    -m /opt/mibs \
    > "$SCRIPT_DIR/snmp.yml"

echo "[3/3] Done! snmp.yml generated at $SCRIPT_DIR/snmp.yml"
echo ""
echo "Verify with:"
echo "  docker run --rm -v $SCRIPT_DIR/snmp.yml:/etc/snmp_exporter/snmp.yml:ro prom/snmp-exporter:v0.29.0 --config.file=/etc/snmp_exporter/snmp.yml --dry-run"
