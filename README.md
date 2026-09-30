# iono-data

Relay of the latest ionosonde soundings (foF2, M(3000)F2, MUF(3000), hmF2, foE, foEs) for the propagation tab of the
antenna simulators [anteny-sq9um](https://sq9fk.github.io/anteny-sq9um/#propagacja) and
[anteny-sq9fk](https://sq9fk.github.io/anteny-sq9fk/#propagacja).
Browsers cannot read the source services cross-origin, so a GitHub Actions workflow fetches them every 15 minutes and
publishes the result on GitHub Pages:

**https://sq9fk.github.io/iono-data/stations.json**

- `fetch.py` – fetches [KC2G](https://prop.kc2g.com/) `api/stations.json` and keeps the stations that reported in the last
  6 hours with an autoscaling confidence of at least 25 (or manually scaled).
- `.github/workflows/iono.yml` – schedule (every 15 minutes), deployment to Pages; one keep-alive commit a month so that
  GitHub does not pause the schedule.

Data: KC2G (Andrew Rodland), the Global Ionosphere Radio Observatory (GIRO / DIDBase, University of Massachusetts Lowell)
and the operators of the ionosondes. Please credit them when using the data.
