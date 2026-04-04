#!/usr/bin/env python3
"""
cookie_theft_scorer.py

Wrapper script to score a cookie theft transcript from command line.
Usage: python cookie_theft_scorer.py <transcript_file>
Output: JSON to stdout
"""

import sys
import json
import os
from pathlib import Path

# Import the cookie theft scoring module
# Adjust the path based on where the model files are located
MODEL_DIR = Path(__file__).parent.parent.parent / "model_testing" / "cookie_theft"
sys.path.insert(0, str(MODEL_DIR))

try:
    from cookie import score_transcript
except ImportError:
    print(json.dumps({
        "error": "Failed to import cookie scoring module",
        "model_path": str(MODEL_DIR)
    }), file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: python cookie_theft_scorer.py <transcript_file>"
        }), file=sys.stderr)
        sys.exit(1)
    
    transcript_file = sys.argv[1]
    
    # Validate file exists
    if not os.path.exists(transcript_file):
        print(json.dumps({
            "error": f"Transcript file not found: {transcript_file}"
        }), file=sys.stderr)
        sys.exit(1)
    
    try:
        # Read transcript
        with open(transcript_file, 'r', encoding='utf-8') as f:
            transcript = f.read()
        
        # Score the transcript
        result = score_transcript(transcript)
        
        # Output as JSON to stdout
        print(json.dumps(result))
        
    except Exception as e:
        print(json.dumps({
            "error": f"Error processing transcript: {str(e)}"
        }), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()