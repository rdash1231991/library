#!/bin/bash
set -euo pipefail
python3.8 -m venv .venv && source .venv/bin/activate
pip install -r invoke-requirements.txt
python invoke.py $*
