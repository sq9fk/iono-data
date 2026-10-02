#!/usr/bin/env python3
"""Relay of the latest ionosonde soundings for the SQ9FK / SQ9UM antenna pages (browsers cannot read the source cross-origin).

Source: KC2G (https://prop.kc2g.com/api/stations.json), which collects soundings from GIRO / DIDBase and other networks.
Output: site/stations.json with the stations that reported in the last 6 hours and passed the autoscaling confidence check
(cs >= 25, or -1 = manually scaled), published on GitHub Pages every 15 minutes by .github/workflows/iono.yml.
Also: site/psk.json – PSK Reporter reception reports of the last 30 minutes with the sender or the receiver in grid square JO90
(who hears the stations around the QTH now, and whom they hear), and site/solar.json – the solar and band summary of N0NBH
(hamqsl.com). Each source is optional: a failed one leaves the others.
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


UA = {'User-Agent': 'sq9fk-iono-relay/1.0 (+https://github.com/sq9fk/iono-data)'}
BANDS = [(1.8, 2.0, '160'), (3.5, 4.0, '80'), (5.25, 5.45, '60'), (7.0, 7.3, '40'), (10.1, 10.15, '30'), (14.0, 14.35, '20'),
         (18.068, 18.168, '17'), (21.0, 21.45, '15'), (24.89, 24.99, '12'), (28.0, 29.7, '10'), (50.0, 54.0, '6')]


def band(hz):
    mhz = (num(hz) or 0) / 1e6
    return next((b for lo, hi, b in BANDS if lo <= mhz <= hi), None)


def grid(loc):
    """Centre of a Maidenhead locator (4 or 6 characters) → (lat, lon)."""
    loc = (loc or '').strip()
    if len(loc) < 4 or not loc[:2].isalpha() or not loc[2:4].isdigit():
        return None
    L = loc.upper()
    lon = (ord(L[0]) - 65) * 20 - 180 + int(L[2]) * 2
    lat = (ord(L[1]) - 65) * 10 - 90 + int(L[3])
    if len(L) >= 6 and L[4:6].isalpha():
        return round(lat + (ord(L[5]) - 65) * 2.5 / 60 + 1.25 / 60, 3), round(lon + (ord(L[4]) - 65) * 5 / 60 + 2.5 / 60, 3)
    return lat + 0.5, lon + 1


def psk():
    """Reception reports of the last 30 minutes, sender in JO90 (tx) and receiver in JO90 (rx): [band, lat, lon, snr, mode, unix time]
    of the far station. PSK Reporter asks for at most one query every 5 minutes; this runs every 15."""
    import xml.etree.ElementTree as ET
    # the NAS trigger and GitHub's own schedule may meet: reuse the published reports when they are younger than 5 minutes
    try:
        with urllib.request.urlopen(urllib.request.Request('https://sq9fk.github.io/iono-data/psk.json', headers=UA), timeout=30) as r:
            prev = json.load(r)
        age = datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(prev['fetched'].replace('Z', '+00:00'))
        if age < datetime.timedelta(minutes=5):
            with open('site/psk.json', 'w', encoding='utf-8') as f:
                json.dump(prev, f, separators=(',', ':'))
            print(f'psk: reused ({int(age.total_seconds())} s old)')
            return
    except Exception:
        pass
    out = {}
    for way, side in (('tx', 'senderCallsign'), ('rx', 'receiverCallsign')):
        url = f'https://retrieve.pskreporter.info/query?{side}=JO90&modify=grid&flowStartSeconds=-1800&rronly=1&noactive=1&rptlimit=5000'
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90) as r:
            root = ET.fromstring(r.read())
        rows = []
        for e in root.iter('receptionReport'):
            b = band(e.get('frequency'))
            far = grid(e.get('receiverLocator') if way == 'tx' else e.get('senderLocator'))
            if not b or not far:
                continue
            rows.append([b, far[0], far[1], num(e.get('sNR')), e.get('mode'), int(num(e.get('flowStartSeconds')) or 0)])
        out[way] = rows
    now = datetime.datetime.now(datetime.timezone.utc)
    with open('site/psk.json', 'w', encoding='utf-8') as f:
        json.dump({'fetched': now.strftime('%Y-%m-%dT%H:%M:%SZ'), 'grid': 'JO90', 'window_s': 1800,
                   'source': 'PSK Reporter (pskreporter.info), reception reports of the last 30 minutes', **out}, f, separators=(',', ':'))
    print(f"psk: {len(out['tx'])} heard from JO90, {len(out['rx'])} heard in JO90")


def solar():
    """N0NBH solar and band summary (hamqsl.com), as JSON."""
    import xml.etree.ElementTree as ET
    with urllib.request.urlopen(urllib.request.Request('https://www.hamqsl.com/solarxml.php', headers=UA), timeout=60) as r:
        root = ET.fromstring(r.read())
    d = root.find('solardata')
    g = lambda k: (d.findtext(k) or '').strip()
    out = {k: g(k) for k in ('updated', 'solarflux', 'aindex', 'kindex', 'xray', 'sunspots', 'protonflux', 'electonflux', 'aurora',
                            'latdegree', 'solarwind', 'magneticfield', 'geomagfield', 'signalnoise', 'fof2', 'muffactor', 'muf')}
    out['bands'] = [{'band': b.get('name'), 'time': b.get('time'), 'cond': (b.text or '').strip()} for b in d.iter('band')]
    out['source'] = 'N0NBH, hamqsl.com'
    with open('site/solar.json', 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print('solar:', out['solarflux'], out['aindex'], out['kindex'], out['xray'])


if __name__ == '__main__':
    main()
    for extra in (psk, solar):
        try:
            extra()
        except Exception as e:   # an optional source must not stop the relay
            print(extra.__name__, 'failed:', e)
