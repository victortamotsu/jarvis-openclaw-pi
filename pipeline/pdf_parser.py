#!/usr/bin/env python3
"""
pipeline/pdf_parser.py — Extract transactions from PDF bank statements

Task T029: Parse PDF via @sylphx/pdf-reader-mcp (subprocess), extract:
- Date
- Establishment
- Value
- Description
- Cardholder (if identified)

Output: JSON array of transactions
"""

import json
import sys
import subprocess
import re
from datetime import datetime
from pathlib import Path

def parse_pdf_via_mcp(pdf_path: str) -> str:
    """
    Call pdf-reader-mcp via npx subprocess (Node.js MCP)
    Returns extracted text and tables
    """
    try:
        # Call @sylphx/pdf-reader-mcp
        result = subprocess.run(
            ['npx', '@sylphx/pdf-reader-mcp', 'read_pdf', '--file', pdf_path],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"PDF reading failed: {result.stderr}")
        
        return result.stdout
    except FileNotFoundError:
        raise RuntimeError("npx not found. Install Node.js and '@sylphx/pdf-reader-mcp'")
    except subprocess.TimeoutExpired:
        raise RuntimeError("PDF parsing timeout (>60s)")

def extract_transactions(pdf_text: str) -> list:
    """
    Extract transaction records from PDF text/tables
    Returns: List of {date, establishment, value, description, cardholder}
    """
    transactions = []
    
    # Regex patterns for common bank statement formats
    # Pattern 1: DATE | ESTABLISHMENT | VALUE
    patterns = [
        # DD/MM | Estabelecimento | Valor
        r'(\d{2}/\d{2})\s*\|\s*([A-Za-z0-9\s\-\.]+?)\s*\|\s*([\d.,]+)',
        # DD/MM/YYYY | DESCRIPTION | VALUE
        r'(\d{2}/\d{2}/\d{4})\s+([^0-9\n]+?)\s+([\d.,]+)',
    ]
    
    for pattern in patterns:
        matches = re.finditer(pattern, pdf_text, re.MULTILINE)
        for match in matches:
            try:
                date_str = match.group(1)
                establishment = match.group(2).strip()
                value_str = match.group(3).replace('.', '').replace(',', '.')
                
                # Skip if value seems invalid
                if not value_str or float(value_str) <= 0:
                    continue
                
                # Parse date (try formats DD/MM and DD/MM/YYYY)
                try:
                    if len(date_str) == 5:  # DD/MM
                        # Assume current year
                        date_obj = datetime.strptime(
                            f"{date_str}/{datetime.now().year}",
                            "%d/%m/%Y"
                        )
                    else:
                        date_obj = datetime.strptime(date_str, "%d/%m/%Y")
                except ValueError:
                    continue
                
                transaction = {
                    "date": date_obj.strftime("%Y-%m-%d"),
                    "establishment": establishment,
                    "value": float(value_str),
                    "description": establishment,  # Can be refined by NLP later
                    "cardholder": None,  # Will be identified by csv_enricher
                    "source": "pdf_statement"
                }
                
                # Check for duplicate (avoid duplicates from multiple patterns)
                is_duplicate = any(
                    t['date'] == transaction['date'] and
                    t['value'] == transaction['value'] and
                    t['establishment'] == transaction['establishment']
                    for t in transactions
                )
                
                if not is_duplicate:
                    transactions.append(transaction)
            
            except (ValueError, IndexError, AttributeError) as e:
                # Log parse error but continue
                sys.stderr.write(f"[Parse Error] Skipping malformed line: {match.group(0)}\n")
                continue
    
    return transactions

def identify_cardholder(pdf_text: str) -> str:
    """
    Attempt to identify cardholder name from PDF (usually printed on statement)
    Returns: Name or None
    """
    # Common patterns in Brazilian bank statements
    patterns = [
        r'(?:Titular|Cardholder|Portador)\s*:?\s*([A-Z][A-Za-z\s]+)',
        r'(?:TITULAR|PORTADOR)\s*-\s*([A-Z][A-Z\s]+)',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, pdf_text, re.IGNORECASE)
        if match:
            name = match.group(1).strip()
            if len(name) > 2 and len(name) < 100:
                return name
    
    return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 pdf_parser.py <pdf_path>")
        print("Output: JSON array to stdout")
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    
    # Validate file
    if not Path(pdf_path).exists():
        print(json.dumps({"error": f"File not found: {pdf_path}"}), file=sys.stderr)
        sys.exit(1)
    
    try:
        # Parse PDF via MCP
        sys.stderr.write(f"[PDF Parser] Reading: {pdf_path}\n")
        pdf_text = parse_pdf_via_mcp(pdf_path)
        
        # Extract transactions
        sys.stderr.write("[PDF Parser] Extracting transactions...\n")
        transactions = extract_transactions(pdf_text)
        
        # Try to identify cardholder
        cardholder = identify_cardholder(pdf_text)
        if cardholder:
            for t in transactions:
                t['cardholder'] = cardholder
            sys.stderr.write(f"[PDF Parser] Identified cardholder: {cardholder}\n")
        
        # Output as JSON
        output = {
            "source": "pdf_statement",
            "pdf_path": pdf_path,
            "parse_timestamp": datetime.now().isoformat(),
            "transaction_count": len(transactions),
            "transactions": transactions
        }
        
        print(json.dumps(output, indent=2))
        sys.stderr.write(f"[PDF Parser] ✓ Extracted {len(transactions)} transactions\n")
        
    except Exception as e:
        error_output = {
            "error": str(e),
            "pdf_path": pdf_path,
            "timestamp": datetime.now().isoformat()
        }
        print(json.dumps(error_output), file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
