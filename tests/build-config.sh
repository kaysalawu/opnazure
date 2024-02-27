#!/bin/bash

CONFIG_XML="$1"
IPSEC_CONFIG="$2"
PLACEHOLDER="$3"
FINAL_OUTPUT="final-config.xml"

# Escape backslashes, forward slashes, and ampersands for sed compatibility
ESCAPED_PLACEHOLDER=$(echo $PLACEHOLDER | sed 's/[\/&]/\\&/g')

# Use awk to replace the placeholder with the contents of the IPSEC config file
awk -v var="$ESCAPED_PLACEHOLDER" -v file="$IPSEC_CONFIG" '
    BEGIN { while((getline line < file) > 0) { content = content line "\n" } }
    { gsub(var, content); print }
' "$CONFIG_XML" > "$FINAL_OUTPUT"

# Remove empty lines from FINAL_OUTPUT
sed -i '/^$/d' "$FINAL_OUTPUT"
