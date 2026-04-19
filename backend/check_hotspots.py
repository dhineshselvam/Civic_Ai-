import joblib
h = joblib.load('ml_training/zone_hotspots.pkl')
zone = 'Lawspet'
m = 5
issue = 'Garbage'
spots = h.get(zone, {}).get(m, {}).get(issue, [])
print(f'Lawspet May Garbage hotspots ({len(spots)}):')
for s in spots:
    print(f"  lat={s['lat']}, lng={s['lng']}, weight={s['weight']}")

# Show all zones/issues for May
print('\nAll zones with hotspot data for May:')
for z in h:
    for i in h[z].get(5, {}):
        print(f"  {z} | {i}: {len(h[z][5][i])} hotspots")
