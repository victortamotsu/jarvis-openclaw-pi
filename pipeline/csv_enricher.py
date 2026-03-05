#!/usr/bin/env python3
"""
pipeline/csv_enricher.py — Enrich CSV with PDF data and apply owner rules

Task T030: Merge CSV (from bank) with PDF (from statement):
1. Read CSV: date, establishment, value (minimal bank export)
2. Read PDF output: parsed transactions from pdf_parser.py
3. Merge by: date ±1 day, exact value, similar establishment name
4. Apply owner-rules.json: ESTABELECIMENTO → member_id mapping
5. Output: enriched CSV with owner identification
"""

import json
import csv
import sys
from datetime import datetime, timedelta
from pathlib import Path
from difflib import SequenceMatcher

def load_owner_rules(rules_path: str) -> dict:
    """Load owner-rules.json mapping establishments to member IDs"""
    if not Path(rules_path).exists():
        return {}
    
    with open(rules_path, 'r', encoding='utf-8') as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            return {}

def similarity_ratio(a: str, b: str) -> float:
    """Calculate string similarity (0.0-1.0)"""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

def merge_transactions(csv_data: list, pdf_data: list, rules: dict) -> list:
    """
    Merge CSV + PDF transactions, apply owner rules
    
    Merge strategy:
    - For each CSV row: find PDF match (±1 day, exact value, sim establishment)
    - If found: use PDF cardholder info
    - Apply owner rules for establishment
    - Return enriched rows
    """
    enriched = []
    matched_pdf_ids = set()
    
    for csv_row in csv_data:
        try:
            csv_date = datetime.strptime(csv_row['date'], '%Y-%m-%d')
            csv_value = float(csv_row['value'])
            csv_estab = csv_row.get('establishment', '').strip()
            
        except (ValueError, KeyError) as e:
            sys.stderr.write(f"[Enricher] Skipping invalid CSV row: {e}\n")
            continue
        
        # Find matching PDF transaction
        best_pdf_match = None
        best_similarity = 0.0
        
        for i, pdf_txn in enumerate(pdf_data):
            if i in matched_pdf_ids:
                continue  # Already used
            
            try:
                pdf_date = datetime.strptime(pdf_txn['date'], '%Y-%m-%d')
                pdf_value = float(pdf_txn['value'])
                pdf_estab = pdf_txn.get('establishment', '').strip()
                
                # Check if dates within ±1 day
                date_diff = abs((csv_date - pdf_date).days)
                if date_diff > 1:
                    continue
                
                # Check if values match exactly
                if abs(csv_value - pdf_value) > 0.01:
                    continue
                
                # Check establishment similarity
                sim = similarity_ratio(csv_estab, pdf_estab)
                if sim > 0.6 and sim > best_similarity:
                    best_pdf_match = i
                    best_similarity = sim
            
            except (ValueError, KeyError):
                continue
        
        # Build enriched row
        enriched_row = dict(csv_row)
        enriched_row['merge_confidence'] = 'HIGH' if best_pdf_match is not None else 'LOW'
        
        if best_pdf_match is not None:
            pdf_txn = pdf_data[best_pdf_match]
            enriched_row['pdf_matched'] = True
            enriched_row['cardholder'] = pdf_txn.get('cardholder')
            enriched_row['establishment'] = pdf_txn.get('establishment', csv_estab)
            matched_pdf_ids.add(best_pdf_match)
        else:
            enriched_row['pdf_matched'] = False
            enriched_row['cardholder'] = None
        
        # Apply owner rules
        estab_normalized = enriched_row['establishment'].upper()
        owner = None
        
        # Exact match
        if estab_normalized in rules:
            owner = rules[estab_normalized]
        
        # Fuzzy match (if partial match in rules)
        if not owner:
            for rule_estab, rule_owner in rules.items():
                if similarity_ratio(estab_normalized, rule_estab) > 0.8:
                    owner = rule_owner
                    break
        
        enriched_row['owner'] = owner
        enriched_row['owner_confidence'] = 'HIGH' if owner else 'MANUAL_REQUIRED'
        
        enriched.append(enriched_row)
    
    # Add any unmatched PDF transactions (in case CSV is incomplete)
    for i, pdf_txn in enumerate(pdf_data):
        if i not in matched_pdf_ids:
            # Create row from PDF
            estab_normalized = pdf_txn.get('establishment', '').upper()
            owner = None
            
            if estab_normalized in rules:
                owner = rules[estab_normalized]
            
            enriched_row = {
                'date': pdf_txn['date'],
                'establishment': pdf_txn['establishment'],
                'value': pdf_txn['value'],
                'description': pdf_txn.get('description', ''),
                'pdf_matched': True,
                'cardholder': pdf_txn.get('cardholder'),
                'owner': owner,
                'merge_confidence': 'LOW',
                'owner_confidence': 'HIGH' if owner else 'MANUAL_REQUIRED'
            }
            enriched.append(enriched_row)
    
    return enriched

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 csv_enricher.py <csv_path> <pdf_json_path>")
        print("Requires: /mnt/external/openclaw/memory/owner-rules.json")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    pdf_json_path = sys.argv[2]
    rules_path = "/mnt/external/openclaw/memory/owner-rules.json"
    
    try:
        # Read CSV
        sys.stderr.write(f"[Enricher] Reading CSV: {csv_path}\n")
        csv_data = []
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            csv_data = list(reader)
        
        sys.stderr.write(f"[Enricher] CSV rows: {len(csv_data)}\n")
        
        # Read PDF JSON
        sys.stderr.write(f"[Enricher] Reading PDF data: {pdf_json_path}\n")
        with open(pdf_json_path, 'r', encoding='utf-8') as f:
            pdf_output = json.load(f)
            pdf_data = pdf_output.get('transactions', [])
        
        sys.stderr.write(f"[Enricher] PDF transactions: {len(pdf_data)}\n")
        
        # Load owner rules
        rules = load_owner_rules(rules_path)
        sys.stderr.write(f"[Enricher] Owner rules loaded: {len(rules)} mappings\n")
        
        # Merge
        sys.stderr.write("[Enricher] Merging CSV + PDF...\n")
        enriched = merge_transactions(csv_data, pdf_data, rules)
        
        # Output CSV with enriched columns
        if enriched:
            output_path = csv_path.replace('.csv', '_enriched.csv')
            fieldnames = list(enriched[0].keys())
            
            with open(output_path, 'w', encoding='utf-8', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(enriched)
            
            sys.stderr.write(f"[Enricher] ✓ Enriched CSV: {output_path}\n")
            print(output_path)
        else:
            sys.stderr.write("[Enricher] ✗ No transactions merged\n")
            sys.exit(1)
    
    except Exception as e:
        sys.stderr.write(f"[Enricher] ERROR: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
