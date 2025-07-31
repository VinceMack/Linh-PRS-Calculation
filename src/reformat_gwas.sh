#!/bin/bash
set -e

# This script's only job is to format the raw GWAS file for PRS-CS.
# It is designed to be run from the project's root directory.

# --- Configuration ---
# All paths are relative to the project root directory.
RAW_GWAS_FILE="./data/input/gwas.txt"
FORMATTED_GWAS_FILE="./data/input/formatted_gwas.txt"

echo "--- Starting GWAS Formatting ---"

# 1. Check if the raw input file exists
if [ ! -f "$RAW_GWAS_FILE" ]; then
    echo "Error: Raw GWAS file not found at: $RAW_GWAS_FILE"
    exit 1
fi

# 2. Format the file, treating any spaces or tabs as delimiters.
# NOTE: These column numbers are for the Chronic Periodontitis GWAS (GCST90044102).
# If you use a different GWAS, you must update these numbers.
awk -F'[ \t]+' 'BEGIN{OFS="\t"; print "SNP", "A1", "A2", "BETA", "P"} \
     NR > 1 { \
        # $2: variant_id (SNP)
        # $4: effect_allele (A1)
        # $5: other_allele (A2)
        # $11: beta (BETA)
        # $13: p_value (P)
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