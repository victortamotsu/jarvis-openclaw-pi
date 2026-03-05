#!/usr/bin/env python3
"""
pipeline/anonymizer.py — Anonymize sensitive data before sending to AI

Task T031: Replace PII for secure Copilot processing:
- Cardholder names: victor → MEMBER_A, spouse → MEMBER_B, etc.
- Exact values: R$100 → LOW, R$500 → MED, >R$1000 → HIGH
- Preserves data structure for analysis without exposing sensitive info
"""

import json
import csv
import sys
import re
from pathlib import Path
from datetime import datetime

def load_cardholder_mapping(rules_path: str) -> dict:
    """Load member mapping (victor → MEMBER_A, etc.)"""
    mapping = {
        'victor': 'MEMBER_A',
        'spouse': 'MEMBER_B',
        'child1': 'MEMBER_C',
        'child2': 'MEMBER_D',
        # Additional common names shortened
        'mari': 'MEMBER_B',
        'kids': 'MEMBER_C,MEMBER_D'
    }
    
    if Path(rules_path).exists():
        try:
            with open(rules_path, 'r') as f:
                custom = json.load(f)
                mapping.update(custom)
        except:
            pass
    
    return mapping

def mask_value(value: float, brackets: dict = None) -> str:
    """
    Mask numeric value into bracket (LOW/MED/HIGH)
    
    Default brackets (BRL):
    - 0-100: LOW
    - 100-500: MED
    - 500+: HIGH
    """
    if brackets is None:
        brackets = {'low': 100, 'med': 500}
    
    if value <= brackets['low']:
        return 'LOW'
    elif value <= brackets['med']:
        return 'MED'
    else:
        return 'HIGH'

def mask_name(name: str, mapping: dict) -> str:
    """Replace cardholder name with anonymized ID"""
    if not name:
        return 'UNKNOWN'
    
    name_lower = name.lower().strip()
    
    # Exact match
    if name_lower in mapping:
        return mapping[name_lower]
    
    # Partial match
    for key, val in mapping.items():
        if key in name_lower or name_lower in key:
            return val
    
    # Default: extract first letter + hash
    hash_val = str(hash(name_lower))[-4:]
    return f"USER_{hash_val}"

def anonymize_row(row: dict, cardholder_mapping: dict, value_brackets: dict) -> dict:
    """Anonymize a single transaction row"""
    anon = dict(row)
    
    # Anonymize owner/cardholder
    if 'owner' in anon and anon['owner']:
        anon['owner'] = mask_name(anon['owner'], cardholder_mapping)
    
    if 'cardholder' in anon and anon['cardholder']:
        anon['cardholder'] = mask_name(anon['cardholder'], cardholder_mapping)
    
    # Mask value
    if 'value' in anon:
        try:
            val = float(anon['value'])
            anon['value_bracket'] = mask_value(val, value_brackets)
            # Keep original for reference, but mark as sensitive
            anon['value'] = '[MASKED]'
        except (ValueError, TypeError):
            pass
    
    # Keep establishment for context (already business-related, not PII)
    # Keep date (not sensitive)
    
    return anon

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 anonymizer.py <enriched_csv_path>")
        print("Output: anonymized CSV to stdout")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    cardholder_mapping = load_cardholder_mapping("/mnt/external/openclaw/memory/owner-rules.json")
    value_brackets = {'low': 100, 'med': 500}
    
    try:
        sys.stderr.write(f"[Anonymizer] Reading: {csv_path}\n")
        
        rows = []
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
        
        sys.stderr.write(f"[Anonymizer] Anonymizing {len(rows)} rows...\n")
        
        # Anonymize all rows
        anon_rows = [anonymize_row(row, cardholder_mapping, value_brackets) for row in rows]
        
        # Output as CSV
        if anon_rows:
            fieldnames = list(anon_rows[0].keys())
            
            output_path = csv_path.replace('_enriched.csv', '_anonymous.csv')
            with open(output_path, 'w', encoding='utf-8', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(anon_rows)
            
            sys.stderr.write(f"[Anonymizer] ✓ Output: {output_path}\n")
            
            # Also output anonymized JSON for API
            json_path = output_path.replace('.csv', '.json')
            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(anon_rows, f, indent=2)
            
            sys.stderr.write(f"[Anonymizer] ✓ JSON: {json_path}\n")
            
            # Summary
            brackets_count = {}
            for row in anon_rows:
                bracket = row.get('value_bracket', 'UNKNOWN')
                brackets_count[bracket] = brackets_count.get(bracket, 0) + 1
            
            sys.stderr.write(f"[Anonymizer] Value distribution: {json.dumps(brackets_count)}\n")
            
            print(output_path)
        
    except Exception as e:
        sys.stderr.write(f"[Anonymizer] ERROR: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
