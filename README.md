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

## Trigger from a NAS (Synology)

GitHub delays the schedule of a little-used public repository, often by hours, but runs a dispatched workflow at once.
`synology/` holds a tiny container that dispatches the workflow every 15 minutes:

- `docker-compose.yml` – `curlimages/curl` running `trigger.sh` (no image to build, 32 MB memory limit, small logs);
- `trigger.sh` – `POST /repos/sq9fk/iono-data/actions/workflows/iono.yml/dispatches` every `INTERVAL` seconds (default
  900, at least 300), logs the HTTP status; `ONCE=1` makes one call for a test;
- `.env.example` – copy to `.env` with a fine-grained token: repository access only `sq9fk/iono-data`, permission
  **Actions: read and write**. `.env` is ignored by git.

On Synology: copy the folder to the NAS (e.g. `/volume1/docker/iono-trigger`), create `.env`, then Container Manager →
Project → Create → that folder (it finds `docker-compose.yml`) → Build/Start. Or over SSH: `sudo docker compose up -d`.
The log of the container shows `dispatched` every 15 minutes. GitHub's own schedule stays as a fallback; when both run
within 5 minutes the PSK Reporter reports are reused instead of queried again.

Data: PSK Reporter (Philip Gladstone, N1DQ) and its reporting stations; N0NBH (Paul Herrman, hamqsl.com); KC2G (Andrew Rodland), the Global Ionosphere Radio Observatory (GIRO / DIDBase, University of Massachusetts Lowell)
and the operators of the ionosondes. Please credit them when using the data.
