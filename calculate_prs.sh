#!/bin/bash

# Script to calculate Polygenic Risk Scores using PLINK2

# --- Configuration: Directory Paths ---
# Assuming the script is run from the 'Linh PRS' directory
BASE_DIR="."
INPUT_DATA_DIR="${BASE_DIR}/data/input"
CONVERTED_BINARY_DIR="${BASE_DIR}/data/converted_binary"
RESULTS_DIR="${BASE_DIR}/results"

# --- Configuration: File Names ---
MAP_FILE_NAME="Top_UNLV_GlobalDiversityArray_PRS_20231213.map"
PED_FILE_NAME="Top_UNLV_GlobalDiversityArray_PRS_20231213.ped"
# NOTE: This file is expected to be a TAB-SEPARATED (TSV) file.
BETA_SUMMARY_STATS_FILE_NAME="betas.tsv" # Or your new TSV filename

# Output file name prefixes (without directory paths)
PLINK_BINARY_NAME_PREFIX="unlv_gda_binary"
SCORE_FILE_NAME="my_scores.txt" # This will be created from the summary statistics
FREQ_FILE_NAME_PREFIX="${PLINK_BINARY_NAME_PREFIX}_freqs"
PRS_RESULTS_NAME_PREFIX="unlv_prs_results"

# --- Construct full paths for files ---
MAP_FILE="${INPUT_DATA_DIR}/${MAP_FILE_NAME}"
PED_FILE="${INPUT_DATA_DIR}/${PED_FILE_NAME}"
BETA_SUMMARY_STATS_FILE="${INPUT_DATA_DIR}/${BETA_SUMMARY_STATS_FILE_NAME}"

# PLINK2 binary files will be prefixed with the directory path
PLINK_BINARY_OUT_PREFIX="${CONVERTED_BINARY_DIR}/${PLINK_BINARY_NAME_PREFIX}"

# Score file will be placed in the converted_binary directory
SCORE_FILE_PATH="${CONVERTED_BINARY_DIR}/${SCORE_FILE_NAME}"

# Allele frequency files will be prefixed with the directory path
FREQ_FILE_OUT_PREFIX="${CONVERTED_BINARY_DIR}/${FREQ_FILE_NAME_PREFIX}"
FREQ_FILE_AFREQ_PATH="${FREQ_FILE_OUT_PREFIX}.afreq" # Full path to the .afreq file

# PRS results files will be prefixed with the directory path
PRS_RESULTS_OUT_PREFIX="${RESULTS_DIR}/${PRS_RESULTS_NAME_PREFIX}"
PRS_SSCORE_FILE_PATH="${PRS_RESULTS_OUT_PREFIX}.sscore" # Full path to the .sscore file

# --- Create output directories if they don't exist ---
mkdir -p "${CONVERTED_BINARY_DIR}"
mkdir -p "${RESULTS_DIR}"
echo "Ensured output directories exist:"
echo "  Converted binary data: ${CONVERTED_BINARY_DIR}"
echo "  Results: ${RESULTS_DIR}"
echo ""

# --- Step 1: Prepare the scoring file from the GWAS summary statistics TSV ---
echo "Step 1: Preparing scoring file (${SCORE_FILE_PATH}) from GWAS TSV: ${BETA_SUMMARY_STATS_FILE}..."
if [ ! -f "${BETA_SUMMARY_STATS_FILE}" ]; then
    echo "Error: GWAS summary statistics TSV file not found: ${BETA_SUMMARY_STATS_FILE}"
    exit 1
fi

# From the new TSV format, we need:
# 1. Variant ID (rsID): From 2nd column 'SNP'
# 2. Effect Allele: From 4th column 'effect_allele'
# 3. Beta: From 8th column 'beta'
# The input TSV is assumed to have a header, so we skip it with 'tail -n +2'.
tail -n +2 "${BETA_SUMMARY_STATS_FILE}" | awk -F'\t' '
{
    rsid = $2;          # SNP column
    effect_allele = $4; # effect_allele column
    beta = $8;          # beta column

    # Clean leading/trailing whitespace from extracted values
    gsub(/^[ \t]+|[ \t]+$/, "", rsid);
    gsub(/^[ \t]+|[ \t]+$/, "", effect_allele);
    gsub(/^[ \t]+|[ \t]+$/, "", beta);

    # Ensure rsid, effect_allele are not empty and beta is a numeric value before printing
    # This also helps filter out lines where parsing might have failed or beta is non-numeric
    if (rsid != "" && effect_allele != "" && beta ~ /^[+-]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/) {
        print rsid "\t" effect_allele "\t" beta;
    } else if (NR > 1) { # Avoid warning for header if tail failed for some reason
        # Optional: print a warning to stderr for lines that couldnt be fully parsed or had non-numeric beta
        # print "Warning (awk): Skipping line " NR " due to parsing issues or non-numeric beta: rsid='"'"'" rsid "'"'"', allele='"'"'" effect_allele "'"'"', beta='"'"'" beta "'"'"'" > "/dev/stderr";
    }
}' > "${SCORE_FILE_PATH}"


if [ ! -s "${SCORE_FILE_PATH}" ]; then
    echo "Error: Failed to create scoring file or scoring file is empty: ${SCORE_FILE_PATH}"
    echo "Please check ${BETA_SUMMARY_STATS_FILE}, its format, and the awk command."
    exit 1
fi
echo "Scoring file ${SCORE_FILE_PATH} created successfully."
echo "Preview of ${SCORE_FILE_PATH} (first 5 lines):"
head -n 5 "${SCORE_FILE_PATH}"
echo ""

# --- Step 2: Convert .map and .ped files to PLINK2 binary format ---
echo "Step 2: Converting .map and .ped to PLINK2 binary format (output prefix: ${PLINK_BINARY_OUT_PREFIX}) and sorting variants..."
if [ ! -f "${MAP_FILE}" ] || [ ! -f "${PED_FILE}" ]; then
    echo "Error: MAP file (${MAP_FILE}) or PED file (${PED_FILE}) not found."
    exit 1
fi

plink2 \
    --map "${MAP_FILE}" \
    --ped "${PED_FILE}" \
    --make-pgen \
    --sort-vars \
    --out "${PLINK_BINARY_OUT_PREFIX}"

if [ ! -f "${PLINK_BINARY_OUT_PREFIX}.pgen" ] || [ ! -f "${PLINK_BINARY_OUT_PREFIX}.pvar" ] || [ ! -f "${PLINK_BINARY_OUT_PREFIX}.psam" ]; then
    echo "Error: Failed to create PLINK2 binary files."
    echo "Please check the plink2 command, its log file (${PLINK_BINARY_OUT_PREFIX}.log), and the input .map/.ped files."
    exit 1
fi
echo "PLINK2 binary files created successfully in ${CONVERTED_BINARY_DIR}."
echo ""

# --- Step 2.5: Calculate allele frequencies from the PLINK2 binary fileset ---
echo "Step 2.5: Calculating allele frequencies (output prefix: ${FREQ_FILE_OUT_PREFIX})..."
plink2 \
    --pfile "${PLINK_BINARY_OUT_PREFIX}" \
    --freq \
    --out "${FREQ_FILE_OUT_PREFIX}"

if [ ! -f "${FREQ_FILE_AFREQ_PATH}" ]; then
    echo "Error: Failed to calculate allele frequencies. The .afreq file was not created: ${FREQ_FILE_AFREQ_PATH}"
    echo "Please check the plink2 --freq command and its log file (${FREQ_FILE_OUT_PREFIX}.log)."
    exit 1
fi
echo "Allele frequencies calculated successfully: ${FREQ_FILE_AFREQ_PATH}"
echo ""

# --- Step 3: Calculate the Polygenic Risk Score ---
# Ensure each line ending with '\' has NO characters (especially spaces) after the '\'
echo "Step 3: Calculating Polygenic Risk Scores (output prefix: ${PRS_RESULTS_OUT_PREFIX})..."
plink2 \
    --pfile "${PLINK_BINARY_OUT_PREFIX}" \
    --read-freq "${FREQ_FILE_AFREQ_PATH}" \
    --score "${SCORE_FILE_PATH}" 1 2 3 cols=+scoresums list-variants \
    --out "${PRS_RESULTS_OUT_PREFIX}"

if [ ! -f "${PRS_SSCORE_FILE_PATH}" ]; then
    echo "Error: Failed to calculate PRS. The .sscore file was not created: ${PRS_SSCORE_FILE_PATH}"
    echo "Please check the plink2 --score command and its log file (${PRS_RESULTS_OUT_PREFIX}.log)."
    exit 1
fi

echo ""
echo "--- PRS Calculation Complete ---"
echo "Input genotype files: ${MAP_FILE}, ${PED_FILE}"
echo "Input GWAS summary statistics: ${BETA_SUMMARY_STATS_FILE}"
echo ""
echo "Intermediate scoring file: ${SCORE_FILE_PATH}"
echo "PLINK2 binary files generated: ${PLINK_BINARY_OUT_PREFIX}.pgen, .pvar, .psam"
echo "Allele frequency file generated: ${FREQ_FILE_AFREQ_PATH}"
echo ""
echo "PRS results are in: ${PRS_SSCORE_FILE_PATH}"
echo "Variants used for scoring listed in: ${PRS_RESULTS_OUT_PREFIX}.sscore.vars"
echo "Log file for conversion step: ${PLINK_BINARY_OUT_PREFIX}.log"
echo "Log file for frequency calculation: ${FREQ_FILE_OUT_PREFIX}.log"
echo "Log file for the scoring step: ${PRS_RESULTS_OUT_PREFIX}.log"
echo ""
echo "You can view the top of the results file with: head ${PRS_SSCORE_FILE_PATH}"
echo "---------------------------------"

exit 0
