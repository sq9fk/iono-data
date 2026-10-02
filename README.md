# iono-data

Relay of the latest ionosonde soundings (foF2, M(3000)F2, MUF(3000), hmF2, foE, foEs) for the propagation tab of the
antenna simulators [anteny-sq9um](https://sq9fk.github.io/anteny-sq9um/#propagacja) and
[anteny-sq9fk](https://sq9fk.github.io/anteny-sq9fk/#propagacja).
Browsers cannot read the source services cross-origin, so a GitHub Actions workflow fetches them every 15 minutes and
publishes the result on GitHub Pages:

**https://sq9fk.github.io/iono-data/stations.json**

Also published by the same run:

- **[psk.json](https://sq9fk.github.io/iono-data/psk.json)** – [PSK Reporter](https://pskreporter.info/) reception reports of
  the last 30 minutes with the sender (`tx`) or the receiver (`rx`) in grid square JO90: band, position of the far station
  (locator centre), SNR, mode, time. Queried once per run (PSK Reporter asks for at most one query every 5 minutes).
- **[solar.json](https://sq9fk.github.io/iono-data/solar.json)** – the solar and band summary of N0NBH
  ([hamqsl.com](https://www.hamqsl.com/)): 10.7 cm flux, A, K, X-ray, solar wind, Bz, aurora, band conditions.

- `fetch.py` – fetches [KC2G](https://prop.kc2g.com/) `api/stations.json` and keeps the stations that reported in the last
  6 hours with an autoscaling confidence of at least 25 (or manually scaled).
- `.github/workflows/iono.yml` – schedule (every 15 minutes), deployment to Pages; one keep-alive commit a month so that
  GitHub does not pause the schedule.

Data: PSK Reporter (Philip Gladstone, N1DQ) and its reporting stations; N0NBH (Paul Herrman, hamqsl.com); KC2G (Andrew Rodland), the Global Ionosphere Radio Observatory (GIRO / DIDBase, University of Massachusetts Lowell)
and the operators of the ionosondes. Please credit them when using the data.
