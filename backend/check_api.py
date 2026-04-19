import requests
import json

r = requests.get('http://localhost:8000/api/predictions/?month=5', headers={'Authorization': 'Bearer test'})
d = r.json()
if isinstance(d, list):
    for p in d[:3]:  # Print first 3
        print(f"Zone: {p['zone']} | Primary: {p['predicted_issue']}")
        probs = p.get('issue_probabilities')
        if probs:
            for k, v in probs.items():
                print(f"  {k}: {v}%")
        print("-" * 20)
else:
    print(d)
