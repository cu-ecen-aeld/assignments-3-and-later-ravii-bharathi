#!/bin/sh

# Tester script for AESD Assignment 3
# Finds files containing a specific string and counts matching lines
# Author: ravibharathi

set -e
set -u

# ============================================================================
# CONFIGURATION
# ============================================================================

NUMFILES=10
WRITESTR=AELD_IS_FUN
WRITEDIR=/tmp/aeld-data
RESULT_FILE=/tmp/assignment4-result.txt
CONF_DIR=/etc/finder-app/conf

# Load configuration - try multiple paths for flexibility
if [ -f "./username.txt" ]; then
    username=$(cat "${CONF_DIR}/username.txt")
else
    echo "ERROR: Cannot find username.txt"
    exit 1
fi

# Load assignment number
if [ -f "./assignment.txt" ]; then
    assignment=$(cat ${CONF_DIR}/assignment.txt)
else
    echo "ERROR: Cannot find assignment.txt"
    exit 1
fi

# ============================================================================
# PARSE COMMAND LINE ARGUMENTS
# ============================================================================

if [ $# -lt 3 ]; then
    echo "Using default value ${WRITESTR} for string to write"
    if [ $# -lt 1 ]; then
        echo "Using default value ${NUMFILES} for number of files to write"
    else
        NUMFILES=$1
    fi    
else
    NUMFILES=$1
    WRITESTR=$2
    WRITEDIR=/tmp/aeld-data/$3
fi

MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

# ============================================================================
# SETUP & PREPARATION
# ============================================================================

echo "=========================================="
echo "FINDER TEST - ASSIGNMENT ${assignment}"
echo "=========================================="
echo "Configuration:"
echo "  Username: ${username}"
echo "  Files to write: ${NUMFILES}"
echo "  String to search: ${WRITESTR}"
echo "  Output directory: ${WRITEDIR}"
echo ""

# Clean previous test data
echo "Cleaning up previous test artifacts..."
rm -rf "${WRITEDIR}"

# Create output directory (for assignment2+)
if [ "${assignment}" != "assignment1" ]; then
    echo "Creating output directory: ${WRITEDIR}"
    mkdir -p "$WRITEDIR"
    
    if [ ! -d "$WRITEDIR" ]; then
        echo "ERROR: Failed to create $WRITEDIR"
        exit 1
    fi
    echo "✓ Directory created"
fi

# ============================================================================
# WRITE TEST FILES
# ============================================================================

echo ""
echo "Writing ${NUMFILES} files containing string '${WRITESTR}' to ${WRITEDIR}..."

for i in $(seq 1 $NUMFILES); do
    filename="${WRITEDIR}/${username}$i.txt"
   	writer "$filename" "$WRITEDIR" 
done

echo "✓ Files written"

# ============================================================================
# RUN FINDER SCRIPT
# ============================================================================

echo ""
echo "Running finder.sh to count matching lines..."

OUTPUTSTRING=$(finder.sh "$WRITEDIR" "$WRITESTR")

echo "Result: ${OUTPUTSTRING}"

# ============================================================================
# VALIDATION
# ============================================================================

echo ""
echo "Validation:"
echo "  Expected: ${MATCHSTR}"
echo "  Got:      ${OUTPUTSTRING}"
echo ""

# Save result for debugging
echo "${OUTPUTSTRING}" > "${RESULT_FILE}"

# Clean temporary directories
rm -rf /tmp/aeld-data

# Check if output matches expected pattern
if echo "${OUTPUTSTRING}" | grep "${MATCHSTR}" >/dev/null 2>&1; then
    echo "=========================================="
    echo "✓ TEST PASSED"
    echo "=========================================="
    exit 0
else
    echo "=========================================="
    echo "✗ TEST FAILED"
    echo "=========================================="
    echo "Expected: ${MATCHSTR}"
    echo "Got:      ${OUTPUTSTRING}"
    exit 1
fi

