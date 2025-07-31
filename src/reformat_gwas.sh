#!/bin/bash
set -e

# This script's only job is to format the raw GWAS file for PRS-CS.
# It includes checks to ensure the output is created correctly.

# --- Configuration ---
RAW_GWAS_FILE="/home/username/Desktop/PRScs/test_data/wood_gwasGCST006901.txt"
FORMATTED_GWAS_FILE="/home/username/Desktop/PRScs/final_gwas_for_prscs.txt"

echo "--- Starting GWAS Formatting ---"

# 1. Check if the raw input file exists
if [ ! -f "$RAW_GWAS_FILE" ]; then
    echo "Error: Raw GWAS file not found at: $RAW_GWAS_FILE"
    exit 1
fi

# 2. Format the file, treating any spaces or tabs as delimiters.
awk -F'[ \t]+' 'BEGIN{OFS="\t"; print "SNP", "A1", "A2", "BETA", "P"} \
     NR > 1 { \
        # Input columns from wood_gwasGCST006901.txt:
        # $3: SNP
        # $4: Tested_Allele (A1)
        # $5: Other_Allele (A2)
        # $7: BETA
        # $9: P
        print $3, $4, $5, $7, $9 \
     }' "${RAW_GWAS_FILE}" > "${FORMATTED_GWAS_FILE}"

# 3. Verify that the new file was created and is not empty
if [ ! -s "$FORMATTED_GWAS_FILE" ]; then
    echo "Error: The formatted GWAS file (${FORMATTED_GWAS_FILE}) is empty."
    echo "The awk command failed. Please check the raw file's format."
    exit 1
fi

echo "Success! Formatted GWAS file created at: ${FORMATTED_GWAS_FILE}"
echo "You can now run the main PRS script."