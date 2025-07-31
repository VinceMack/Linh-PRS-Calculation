#!/bin/bash
set -e

# This script's only job is to format the raw GWAS file for PRS-CS.
# It automatically determines the project's root directory.

# --- Dynamic Path Configuration ---
# Get the directory where this script is located.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# The project root is one level up from the 'src' directory.
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# --- Configuration ---
RAW_GWAS_FILE="${ROOT_DIR}/data/input/gwas.txt"
FORMATTED_GWAS_FILE="${ROOT_DIR}/data/input/formatted_gwas.txt"

echo "--- Starting GWAS Formatting ---"

# 1. Check if the raw input file exists
if [ ! -f "$RAW_GWAS_FILE" ]; then
    echo "Error: Raw GWAS file not found at: $RAW_GWAS_FILE"
    exit 1
fi

# 2. Format the file, treating any spaces or tabs as delimiters.
awk -F'[ \t]+' 'BEGIN{OFS="\t"; print "SNP", "A1", "A2", "BETA", "P"} \
     NR > 1 { \
        print $2, $4, $5, $11, $13 \
     }' "${RAW_GWAS_FILE}" > "${FORMATTED_GWAS_FILE}"

# 3. Verify that the new file was created and is not empty
if [ ! -s "$FORMATTED_GWAS_FILE" ]; then
    echo "Error: The formatted GWAS file (${FORMATTED_GWAS_FILE}) is empty."
    echo "The awk command failed. Please check the column numbers and the raw file's format."
    exit 1
fi

echo "Success! Formatted GWAS file created at: ${FORMATTED_GWAS_FILE}"
echo "You can now run the main PRS script."