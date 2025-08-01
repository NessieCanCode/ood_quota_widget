#!/bin/bash

# Define the output file for Open OnDemand
OUTPUT_JSON="/var/www/ood/public/dquota.json"

# Get the current timestamp
TIMESTAMP=$(date +%s)

# Start JSON structure
echo '{ "version": 1, "timestamp": '"$TIMESTAMP"', "quotas": [' > "$OUTPUT_JSON"

# Get all LDAP usernames in memory
USERS=$(ldapsearch -x -LLL '(&(uid=*))' uid | awk '/^uid:/ {print $2}')

# Initialize a counter for formatting JSON correctly
FIRST_ENTRY=true

# Loop through each LDAP user
for USER in $USERS; do
    # Get quota details with --no-wrap to prevent incorrect line breaks
    QUOTA_OUTPUT=$(quota -s --no-wrap -u "$USER" 2>/dev/null)

    # Parse each filesystem separately
    echo "$QUOTA_OUTPUT" | awk 'NR>2 {print $1, $2, $3, $4, $6, $7}' | while read -r FS SPACE QUOTA LIMIT FILES FILE_LIMIT; do
        # Convert space and limits to KiB for JSON formatting
        SPACE_KB=$(echo "$SPACE" | numfmt --from=iec 2>/dev/null)
        LIMIT_KB=$(echo "$LIMIT" | numfmt --from=iec 2>/dev/null)

        # Skip invalid or empty results
        if [[ -z "$SPACE_KB" || -z "$LIMIT_KB" || "$SPACE_KB" == "-" ]]; then
            continue
        fi

        # Ensure file limits are set, defaulting to 0
        if [[ -z "$FILES" || "$FILES" == "-" ]]; then FILES=0; fi
        if [[ -z "$FILE_LIMIT" || "$FILE_LIMIT" == "-" ]]; then FILE_LIMIT=0; fi

        # Format JSON entry
        QUOTA_ENTRY='{
          "type": "user",
          "user": "'"$USER"'",
          "path": "'"$FS"'",
          "block_limit": '"$LIMIT_KB"',
          "total_block_usage": '"$SPACE_KB"',
          "file_limit": '"$FILE_LIMIT"',
          "total_file_usage": '"$FILES"'
        }'

        # Append to JSON file with correct formatting
        if $FIRST_ENTRY; then
            echo "  $QUOTA_ENTRY" >> "$OUTPUT_JSON"
            FIRST_ENTRY=false
        else
            echo "  ,$QUOTA_ENTRY" >> "$OUTPUT_JSON"
        fi
    done
done

# Close JSON structure
echo '] }' >> "$OUTPUT_JSON"

echo "Quota JSON has been updated at $OUTPUT_JSON"
