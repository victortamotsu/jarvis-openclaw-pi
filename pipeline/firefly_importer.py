#!/usr/bin/env python3
"""
pipeline/firefly_importer.py — Import transactions to Firefly III

Task T032: POST enriched transactions to Firefly REST API:
- Reads anonymized CSV
- Calls POST /transactions via Firefly API
- Marks owner as tag
- Reports summary (imported, duplicates, errors)
"""

import json
import csv
import sys
import requests
from datetime import datetime
from pathlib import Path
import os

def get_firefly_token() -> str:
    """Get Firefly API token from environment"""
    token = os.environ.get('FIREFLY_TOKEN')
    if not token:
        raise ValueError("FIREFLY_TOKEN not set in environment")
    return token

def get_firefly_url() -> str:
    """Get Firefly base URL from environment"""
    url = os.environ.get('FIREFLY_URL', 'http://firefly-iii:8080')
    return url.rstrip('/')

def get_or_create_category(session: requests.Session, firefly_url: str, category_name: str) -> str:
    """Get or create category, return ID"""
    # List existing categories
    resp = session.get(f"{firefly_url}/api/v1/categories")
    if resp.status_code == 200:
        for cat in resp.json().get('data', []):
            if cat['attributes']['name'].lower() == category_name.lower():
                return cat['id']
    
    # Create new category if not found
    resp = session.post(
        f"{firefly_url}/api/v1/categories",
        json={'name': category_name}
    )
    if resp.status_code in [200, 201]:
        return resp.json()['data']['id']
    
    return None

def import_transaction(session: requests.Session, firefly_url: str, row: dict, tag: str = None) -> dict:
    """
    Import single transaction to Firefly
    
    Returns: {'success': bool, 'transaction_id': str/None, 'error': str/None}
    """
    try:
        # Prepare transaction payload
        transaction_data = {
            "type": "withdrawal",  # Default to withdrawal (expenses)
            "date": row.get('date', datetime.now().strftime('%Y-%m-%d')),
            "currency_code": "BRL",
            "amount": row.get('value', '0'),
            "description": row.get('establishment', 'Imported transaction'),
            "category_name": row.get('owner', 'Uncategorized') or 'Other'
        }
        
        # Add tag if owner provided
        if tag:
            transaction_data['tags'] = [tag]
        
        # Remove masked value if present
        if transaction_data['amount'] == '[MASKED]':
            transaction_data['amount'] = row.get('value', '0')
        
        # POST to Firefly
        resp = session.post(
            f"{firefly_url}/api/v1/transactions",
            json={"transactions": [transaction_data]},
            timeout=10
        )
        
        if resp.status_code in [200, 201]:
            txn_id = resp.json()['data'][0]['id']
            return {'success': True, 'transaction_id': txn_id, 'error': None}
        else:
            return {
                'success': False,
                'transaction_id': None,
                'error': f"HTTP {resp.status_code}: {resp.text[:200]}"
            }
    
    except Exception as e:
        return {'success': False, 'transaction_id': None, 'error': str(e)}

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 firefly_importer.py <anonymous_csv_path>")
        print("Requires: FIREFLY_TOKEN, FIREFLY_URL in environment")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    
    try:
        # Get Firefly credentials
        firefly_url = get_firefly_url()
        firefly_token = get_firefly_token()
        
        sys.stderr.write(f"[Firefly] Connecting to: {firefly_url}\n")
        
        # Setup session with auth
        session = requests.Session()
        session.headers.update({
            'Authorization': f'Bearer {firefly_token}',
            'Content-Type': 'application/json',
            'Accept': 'application/vnd.api+json'
        })
        
        # Test connection
        resp = session.get(f"{firefly_url}/api/v1/about")
        if resp.status_code != 200:
            raise RuntimeError(f"Firefly connection failed: HTTP {resp.status_code}")
        
        version = resp.json()['data']['version']
        sys.stderr.write(f"[Firefly] Connected. Version: {version}\n")
        
        # Read CSV
        sys.stderr.write(f"[Firefly] Reading: {csv_path}\n")
        rows = []
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
        
        sys.stderr.write(f"[Firefly] Found {len(rows)} transactions\n")
        
        # Import each transaction
        summary = {
            'total': len(rows),
            'imported': 0,
            'skipped': 0,
            'errors': 0,
            'transactions': []
        }
        
        for i, row in enumerate(rows):
            sys.stderr.write(f"[Firefly] {"[%d/%d]" % (i+1, len(rows))} {row.get('establishment', 'Unknown')[:30]}...\n")
            
            # Extract owner tag
            tag = row.get('owner', row.get('cardholder', None))
            
            # Import
            result = import_transaction(session, firefly_url, row, tag)
            
            if result['success']:
                summary['imported'] += 1
                summary['transactions'].append({
                    'date': row.get('date'),
                    'establishment': row.get('establishment'),
                    'owner': tag,
                    'transaction_id': result['transaction_id'],
                    'status': 'success'
                })
            else:
                summary['errors'] += 1
                sys.stderr.write(f"  ✗ Error: {result['error'][:100]}\n")
        
        # Output summary
        sys.stderr.write(f"\n[Firefly] ✓ Import Summary:\n")
        sys.stderr.write(f"  Imported: {summary['imported']}/{summary['total']}\n")
        sys.stderr.write(f"  Errors: {summary['errors']}\n")
        
        # Save summary JSON
        summary_path = csv_path.replace('_anonymous.csv', '_import_summary.json')
        with open(summary_path, 'w', encoding='utf-8') as f:
            json.dump(summary, f, indent=2)
        
        sys.stderr.write(f"[Firefly] Summary: {summary_path}\n")
        
        if summary['imported'] > 0:
            print(json.dumps(summary, indent=2))
        else:
            sys.stderr.write("[Firefly] ✗ No transactions imported\n")
            sys.exit(1)
    
    except Exception as e:
        sys.stderr.write(f"[Firefly] FATAL ERROR: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
