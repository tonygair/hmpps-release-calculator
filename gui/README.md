# HMPPS sentence-release calculator — Gnoga front-end

A web-rendered front-end for the SPARK-verified `HMPPS_Release` package.
Single-stack Ada: this Gnoga GUI calls directly into `HMPPS_Release.Decide`
— no FFI, no JSON, no IPC. The same SPARK-proven contract that holds in
the CLI demo holds for every web-form submission.

## Live demonstrator

`https://hmpps-release-demo.thedarkfactory.dev/`

Open in any modern browser. Form inputs map to the four-source records
(Court / NOMIS / OASys / Delius). Submit triggers the verified `Decide`
procedure. The result panel shows the decision reason and, on
`Released`, the days-until-release plus the absolute release date.

## What it demonstrates

- **Four distinct typed Subject_Id values** at the input boundary —
  one number entry per source, types kept distinct in the Ada layer
- **Records_Agree as an explicit reconciliation step** before any
  release decision
- **All seven decision reasons** from the spec (`Released`,
  `No_Sentences`, `Subject_Id_Mismatch`, `Time_Served_Exceeds_Sentence`,
  `Discount_Exceeds_Remaining`, `Active_Restriction_Held`,
  `Recall_Active`) exercisable from the form
- **Calendar conversion at the I/O boundary only.** The SPARK core
  works in `Day_Number` integer days; only the GUI layer converts
  to/from ISO date strings (`Days_Since_Epoch`,
  `Day_Num_To_Date_String`). The prover never sees leap-year reasoning

## Build

The GUI depends on Gnoga 2.2 (`https://sourceforge.net/p/gnoga/code/`).
The expected directory layout when building locally is:

```
<workspace>/
├── gnoga/                       # Gnoga source tree, built
│   ├── src/gnoga.gpr
│   └── settings.gpr
└── hmpps-release-gui/           # this directory
    ├── hmpps_release_gui.gpr
    ├── src/
    │   ├── hmpps_release.ads    # SPARK core (copied from ../src/)
    │   ├── hmpps_release.adb
    │   └── hmpps_release_gui.adb
    └── exe/                     # build output
```

To build:

```bash
git clone https://github.com/tonygair/hmpps-release-calculator.git
cd hmpps-release-calculator
# Place a built Gnoga 2.2 source tree at ../gnoga/ as shown above
cd gui/
ln -s ../src/hmpps_release.ads src/
ln -s ../src/hmpps_release.adb src/
ln -s hmpps_release_gui.adb src/
gprbuild -P hmpps_release_gui.gpr
./exe/hmpps_release_gui
# point a browser at http://localhost:8088/
```

## Deploy

The production deployment at
`https://hmpps-release-demo.thedarkfactory.dev/` runs as a systemd
service on a small Linode VM (Debian 12, x86_64). The systemd unit is
straightforward:

```ini
[Unit]
Description=HMPPS sentence-release calculator demonstrator (Gnoga)
After=network.target

[Service]
Type=simple
User=tony
Group=tony
WorkingDirectory=/opt/hmpps-release-demo/exe
ExecStart=/opt/hmpps-release-demo/exe/hmpps_release_gui
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/hmpps-release-demo.log
StandardError=append:/var/log/hmpps-release-demo.log

[Install]
WantedBy=multi-user.target
```

Caddy reverse-proxies HTTPS on `hmpps-release-demo.thedarkfactory.dev`
to `127.0.0.1:8088`. Auto TLS via Let's Encrypt. Gnoga handles the
WebSocket upgrade transparently behind the proxy.

## Files

- `hmpps_release_gui.adb` — the Gnoga UI, ~310 lines
- `hmpps_release_gui.gpr` — the GPR project file (expects `../gnoga/`)
- `config/` — Alire-generated build-configuration helpers

The SPARK core itself (`hmpps_release.ads`/`adb`) lives in the parent
`src/` directory and is shared between the CLI demo and this GUI.

## Commercial enquiries

This GUI and its SPARK core are a free public gift under Apache-2.0 —
adopt without obligation.

If you'd like to commission a production-grade version of the
calculator, or apply the same formally-verified approach to other
civilian government calculators, contact
`tony.gair@thedarkfactory.co.uk`.

## GOV.UK-flavoured styling (live)

The live demonstrator at `hmpps-release-demo.thedarkfactory.dev` uses
`govuk-style.css` — a GOV.UK Design System–inspired stylesheet (typography,
colour, layout). NOT affiliated with the Government Digital Service.
Demonstrator copy explicitly prefixed *DEMONSTRATOR — NOT A GOVERNMENT
SERVICE*.

### How it's wired

The stylesheet ships as a sibling file to the Gnoga static assets and is
linked from Gnoga's `boot.html`. Two manual deployment steps after the
binary is in place at `/opt/hmpps-release-demo/exe/`:

1. Copy `govuk-style.css` into the runtime's `css/` directory:
   ```bash
   cp gui/govuk-style.css /opt/hmpps-release-demo/exe/css/govuk-style.css
   ```

2. Add a stylesheet link to the runtime's `boot.html`:
   ```html
   <link rel="stylesheet" href="/css/govuk-style.css">
   ```
   (Drop it right after the favicon link in `boot.html`'s `<head>`.)

3. The systemd service does not need restarting — Gnoga serves static
   assets fresh on every connection.

### Known visual quirks worth knowing

- The "DEMONSTRATOR ONLY." prefix in the Ada `Disclaimer_Banner` constant
  is now redundant with the CSS-injected "DEMONSTRATOR — NOT A GOVERNMENT
  SERVICE" phase tag. Cleaning that up needs an Ada edit + binary rebuild.
- Pre-submission, the empty `Result_Days`/`Result_Day` divs pick up the
  CSS row-divider styling and render as a couple of faint grey lines under
  "(awaiting input)". Easy CSS-only fix with `:empty` if it becomes annoying.
