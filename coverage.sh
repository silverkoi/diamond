#!/bin/bash

set -eou pipefail

# Clean current coverage artifacts.
rm -rf tmp/*

# This generates tmp/forge-coverage/lcov.info.
mkdir -p tmp/forge-coverage && forge coverage --report lcov -r tmp/forge-coverage/lcov.info

# This generates tmp/hardhat-coverage/lcov.info. See .solcover.js if you want to
# change this.
npx hardhat coverage

# Foundry uses relative paths but Hardhat uses absolute paths.
# Convert absolute paths to relative paths for consistency.
sed -i -e 's@/.*sk/diamond/@@g' tmp/hardhat-coverage/lcov.info

# Hardhat starts from one for block numbers in BRDA lines. To make them line up
# with forge's lcov file, subtract one from all the block numbers in the
# hardhat's lcov's BRDA lines.
sed -e 's/BRDA:\([0-9]\+\),\([0-9]\+\),\([0-9]\+\),\([0-9]\+\)/echo "BRDA:\1,$((\2-1)),\3,\4"/ge' tmp/hardhat-coverage/lcov.info > tmp/hardhat-coverage/fixed-lcov.info

# Merge lcov files.
lcov \
    --rc lcov_branch_coverage=1 \
    --add-tracefile tmp/hardhat-coverage/fixed-lcov.info \
    --add-tracefile tmp/forge-coverage/lcov.info \
    --output-file tmp/merged-lcov.info

# Filter out tests.
lcov \
    --rc lcov_branch_coverage=1 \
    --remove tmp/merged-lcov.info \
    --output-file tmp/filtered-lcov.info \
    "*tests/*"

# Generate summary.
lcov \
    --rc lcov_branch_coverage=1 \
    --list tmp/filtered-lcov.info

# Generate html report.
genhtml \
    --rc genhtml_branch_coverage=1 \
    --output-directory tmp/coverage \
    tmp/filtered-lcov.info

# TODO: Disable within CICD.
open tmp/coverage/index.html
