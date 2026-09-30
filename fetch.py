#!/usr/bin/env python3
"""Relay of the latest ionosonde soundings for the SQ9FK / SQ9UM antenna pages (browsers cannot read the source cross-origin).

Source: KC2G (https://prop.kc2g.com/api/stations.json), which collects soundings from GIRO / DIDBase and other networks.
Output: site/stations.json with the stations that reported in the last 6 hours and passed the autoscaling confidence check
(cs >= 25, or -1 = manually scaled), published on GitHub Pages every 15 minutes by .github/workflows/iono.yml.
"""
import datetime
import json
import os
import urllib.request

URL = 'https://prop.kc2g.com/api/stations.json'
MAX_AGE = datetime.timedelta(hours=6)


def num(v):
    try:
        return None if v is None else float(v)
    except (TypeError, ValueError):
        return None


def main():
    req = urllib.request.Request(URL, headers={'User-Agent': 'sq9fk-iono-relay/1.0 (+https://github.com/sq9fk/iono-data)'})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)
    now = datetime.datetime.now(datetime.timezone.utc)
    out = []
    for s in data:
        st = s.get('station') or {}
        try:
            t = datetime.datetime.fromisoformat(str(s['time']).replace('Z', '+00:00'))
        except (KeyError, ValueError):
            continue
        if t.tzinfo is None:
            t = t.replace(tzinfo=datetime.timezone.utc)
        cs = num(s.get('cs'))
        if now - t > MAX_AGE or (cs is not None and 0 <= cs < 25):
            continue
        lat, lon = num(st.get('latitude')), num(st.get('longitude'))
        if lat is None or lon is None:
            continue
        if lon > 180:
            lon -= 360
        out.append({'name': st.get('name'), 'code': st.get('code'), 'la': lat, 'lo': round(lon, 2),
                    't': t.strftime('%Y-%m-%dT%H:%M:%SZ'), 'fof2': num(s.get('fof2')), 'md': num(s.get('md')),
                    'mufd': num(s.get('mufd')), 'hmf2': num(s.get('hmf2')), 'foe': num(s.get('foe')),
                    'foes': num(s.get('foes')), 'fbes': num(s.get('fbes')), 'cs': cs, 'src': s.get('source')})
    out.sort(key=lambda x: x['name'] or '')
    os.makedirs('site', exist_ok=True)
    with open('site/stations.json', 'w', encoding='utf-8') as f:
        json.dump({'fetched': now.strftime('%Y-%m-%dT%H:%M:%SZ'),
                   'source': 'KC2G prop.kc2g.com (GIRO / DIDBase and other ionosonde networks)',
                   'stations': out}, f, ensure_ascii=False, separators=(',', ':'))
    with open('site/index.html', 'w', encoding='utf-8') as f:
        f.write('<!doctype html><meta charset="utf-8"><title>Ionosonde relay</title>'
                '<p>Latest ionosonde soundings for the SQ9FK / SQ9UM antenna pages: <a href="stations.json">stations.json</a> '
                f'({len(out)} stations, fetched {now:%Y-%m-%d %H:%M} UTC). Data: KC2G, GIRO / DIDBase and the station operators.</p>')
    print(f'{len(out)} stations')


if __name__ == '__main__':
    main()
