#!/usr/bin/env bash

# Package the sweeper Cloud Function source for upload (kept for parity with the
# repo's other function playbooks; the sandbox module zips via archive_file).

cd "$(dirname "$0")"
rm -f sweeper.zip .terraform-archive.zip
zip -r sweeper.zip main.py requirements.txt >/dev/null
echo "sweeper.zip ready"
