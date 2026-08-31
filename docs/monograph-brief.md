# Smart Farm — Project Brief for Monograph Generation

> **How to use this document.** Paste it whole into an AI as source material for
> a final-year project monograph / thesis. Every number, filename, pin
> assignment and design decision below is taken from the actual implementation,
> so the AI should treat it as ground truth and must not invent additional
> hardware, results, or figures. Where a section says *(to be measured)*, that
> is a genuine gap the author must fill with field data.

---

## 1. Identity

- **Title:** Smart Farm — A Weather-Aware Intelligent Irrigation and Farm
  Advisory System for Smallholder Farms
- **Institution context:** KNUST (Kwame Nkrumah University of Science and
  Technology), Ghana — undergraduate engineering / computer science project in
  smart agriculture.
- **Domain:** IoT, embedded systems, mobile computing, edge machine learning,
  agricultural decision support.
- **Deliverables:** an ESP32 irrigation controller (2,329 lines of Arduino
  C++), a Flutter Android application (~18,900 lines of Dart across 9 layers),
  and a Firebase Realtime Database acting as the broker between them.

---

## 2. Problem statement

Smallholder irrigation in Ghana is either fully manual or, where automated,
driven by a single soil-moisture threshold. A threshold-only controller has
three failure modes that waste water and cost yield:

1. **It irrigates into rain.** The controller has no route to a weather
   service, so it will run a full cycle hours before a downpour.
2. **It cannot explain itself.** A farmer sees "pump on" and has no basis to
   trust or override it.
3. **It is blind to everything except moisture.** It offers no help with what
   to plant, when to plant it, what disease is on the leaf, or what task is
   due this week — the decisions that actually determine the season's outcome.

Additionally, a naive IoT design conflates *command* with *state*: the app
tells the pump to switch on and immediately renders it as running. If the link
drops, the farmer is shown a pump that is not running, or worse, believes a
pump is off while the relay is stuck closed.

---

## 3. Aim and objectives

**Aim.** To design, build and evaluate a low-cost irrigation controller and
companion mobile application that make irrigation decisions from three fused
signals — soil moisture, local climate, and rainfall forecast — and that
extend into a general farm advisory tool, while never misreporting the
physical state of the pump.

**Specific objectives.**

1. Build an ESP32-based controller that reads a capacitive soil probe and a
   DHT11, drives a relay-switched pump, displays state locally on an I²C LCD,
   and synchronises bidirectionally with Firebase.
2. Design a database contract in which every field has exactly one writer, so
   command and measured state can never be confused.
3. Implement a rain-delay layer: the phone fetches a forecast the controller
   cannot reach, condenses it to two fields, and publishes it for the firmware
   to act on — with automatic retraction when the outlook goes stale.
4. Implement a pump-command state machine that models the command's journey
   from intent to confirmed physical state, including timeout, so that an
   unconfirmed command is never rendered as success.
5. Extend the application with weather-derived farming signals, a crop
   recommender scored against live conditions, on-device leaf-disease
   classification, an automatically generated task calendar, and a
   farm-grounded conversational assistant.
6. Keep all decision logic as pure, side-effect-free functions so it can be
   verified by unit test without Firebase, network, or hardware — and verify
   it (131 tests across 9 suites).
7. Evaluate the system for water saved, decision accuracy, and reliability
   under intermittent rural connectivity.

---

## 4. Scope and limitations (state these honestly in the monograph)

- Single-zone irrigation: one soil probe, one pump, one relay.
- Android only; iOS untested.
- The disease classifier is a decision aid trained on the PlantVillage
  dataset's leaf photography, not a field-validated diagnostic. Its 38 classes
  include temperate crops (apple, grape, blueberry) that are irrelevant to the
  Ghanaian context — a known limitation of the public dataset.
- Weather comes from Open-Meteo's model output, not from an on-farm station.
- Crop scoring encodes agronomic rules of thumb tuned to Ghana's seasons; it
  is not calibrated against measured yield.
- The assistant's language model runs on a third-party or self-hosted
  endpoint; an API key compiled into an APK is extractable and therefore
  suitable for a personal build only.

---

## 5. Hardware

| Component | Detail |
| --- | --- |
| Microcontroller | ESP32 WROOM-32 |
| Soil moisture | Capacitive analogue probe, **GPIO 34** (ADC1), 10-sample average per reading |
| Temperature / humidity | DHT11, **GPIO 26** |
| Pump actuation | Relay module, **GPIO 33**, `RELAY_ACTIVE_LOW = true` |
| Local display | 16×2 I²C LCD, address **0x27**, SDA **GPIO 21**, SCL **GPIO 22** |
| Connectivity | On-board Wi-Fi → Firebase Realtime Database over TLS |

**Critical sensor convention.** The capacitive probe reads *higher when drier*
(`SOIL_DRY_WHEN_HIGH = true`). Every downstream computation — the firmware's
threshold comparison, the app's crop `recommendedThreshold` values, the
recommender's moisture scoring, and the advisor's "lower the threshold"
suggestion — depends on this sign. Default dry threshold: **1650** (raw ADC).

---

## 6. Firmware design

**File:** `firmware/smart_farm/smart_farm.ino`

**Timing constants** (the app's timeouts are derived from these, not guessed):

| Constant | Value | Meaning |
| --- | --- | --- |
| `FIREBASE_READ_INTERVAL` | 3 s | polls `/farm` for commands |
| `FIREBASE_UPLOAD_INTERVAL` | 5 s | publishes measured state |
| `SENSOR_INTERVAL` | 3 s | soil + DHT sampling |
| `LCD_SCREEN_INTERVAL` | 3 s | rotates local display pages |
| `IRRIGATION_COOLDOWN` | 30 s | minimum gap between cycles |
| `MAX_PUMP_RUNTIME` | 120 s | hard ceiling on any single run |
| `RAIN_PROBABILITY_LIMIT` | 60 % | confidence needed to honour a rain delay |

Because read and upload run on **independent timers**, a command issued just
after a poll can take up to ~8 s to appear in `pumpStatus`. This single fact
sizes the mobile app's 15 s confirmation timeout.

**Safety architecture — worth a full subsection in the monograph.** The
irrigation cut-off is enforced in `enforceIrrigationTimeout()`, which runs on
**every** loop iteration and also during Wi-Fi reconnection — deliberately
*outside* any `app.ready()` / connectivity guard. An earlier design reached
the stop path only through the Firebase-gated branch; if the network dropped
mid-cycle, the timer never fired and the relay stayed energised indefinitely.
This is a textbook example of why a safety interlock must not depend on a
network condition, and the code carries a comment forbidding the function from
being moved back inside the guard.

---

## 7. Data contract — one writer per field

The database is not a one-way telemetry feed. Data flows both ways, and
ownership is explicit:

| Field | Written by | Read by |
| --- | --- | --- |
| `mode`, `pump`, `threshold` | app | ESP32 |
| `pumpStatus`, `soilMoisture`, `temperature`, `humidity` | ESP32 | app |
| `irrigationDuration`, `irrigationReason` | ESP32 | app |
| `weather/rainExpected`, `weather/rainProbability`, `weather/updatedAt` | **app** | ESP32 |
| `/farm/history/*` | app | app |

**The central naming convention:** `pump` is a *command* — what the app last
asked for. `pumpStatus` is *truth* — what the ESP32 measured. Only
`pumpStatus` may drive anything that tells the farmer the pump is running.

**The last row is the novel contribution.** The controller has no route to a
weather service, so the phone acts as its forecast proxy, condensing a full
hourly forecast to two actionable fields. This creates an obligation the other
fields do not have: a stale `rainExpected: true` would hold the pump off
indefinitely, and the controller cannot distinguish a fresh outlook from a
week-old one. The app's `WeatherPublisher` therefore **retracts** a standing
delay once its forecast ages out; the durable fix, documented as future work,
is for the firmware to expire the block itself using the `weather/updatedAt`
timestamp the app already writes. If nothing ever publishes, `rainExpected`
stays `false` and rain delay simply never happens — the system degrades to a
plain threshold controller rather than failing.

---

## 8. Mobile application architecture

Strict layering, one concern per directory:

```
lib/
  models/      plain data classes, zero Flutter imports
  data/        knowledge bases (14 crops, 38 disease labels → treatment)
  logic/       pure decision functions — no I/O, fully unit-tested
  services/    Firebase, Open-Meteo, GPS, TFLite, preferences, LLM client
  providers/   ChangeNotifiers bridging services to the UI (Provider pattern)
  screens/     one file per screen (13 screens, 5-tab shell)
  widgets/     reusable cards and instrumentation
  theme/       design tokens, light/dark themes, semantic farm colours
```

The architectural claim to defend in the monograph: **decision logic contains
no I/O**, so the parts of the system that could give a farmer bad advice are
testable without Firebase, a network, or a device. `logic/` modules:

| Module | Responsibility |
| --- | --- |
| `irrigation_advisor.dart` | fuses soil reading + rain forecast into a verdict (`irrigateNow`, `holdForRain`, `soilIsMoist`, `sensorUnknown`) with quantified litres saved |
| `rain_outlook.dart` | condenses an hourly forecast to `rainExpected` / probability / mm / first rain hour, and distinguishes "dry" from "unknown" |
| `pump_command_machine.dart` | the command lifecycle as pure transitions |
| `alert_builder.dart` | derives the whole alert list from live state |
| `crop_recommender.dart` | scores every crop 0–100 against live conditions |
| `farm_status.dart` / `field_band.dart` | reduce system state to a one-second headline |
| `weather_advice.dart` | turns forecast numbers into farming signals |
| `farm_brief.dart` | builds the LLM assistant's entire view of the farm |

---

## 9. Key algorithms

### 9.1 Three-layer irrigation decision

1. **Soil layer** — raw ADC against `threshold`, remembering higher = drier.
2. **Climate layer** — DHT11 temperature and humidity, used for evaporation
   pressure and heat-stress alerts.
3. **Forecast layer** — `rainExpected` published by the phone, honoured only
   above `RAIN_PROBABILITY_LIMIT` (60 %).

The advisor turns this into farmer-facing language with a quantified benefit —
"hold irrigation, 8 mm of rain is coming in 4 hours — saves about 800 litres"
— using the identity **1 mm of rain over 1 m² = 1 litre**, multiplied by the
farm's configured `areaSqm`. The thresholds used on screen are the *same
constants* published to the controller, so the advice and the controller's
behaviour are always the same judgement.

### 9.2 Pump command state machine

States: `sending → awaitingDevice → confirmed`, with `timedOut` / `failed` as
terminal failure states meaning **the physical outcome is unknown** — never
rendered as success.

- `deviceTimeout` = **15 s**, derived from the firmware's 3 s poll + 5 s
  publish on independent timers plus two network round trips. Tighter would
  report healthy hardware as faulty; looser would leave a real fault
  unreported.
- `noticeDuration` = 4 s before the UI settles back to plain device state.
- A **debounce** prevents ON→OFF→ON faster than the relay can follow.
- A **command lock** serialises requests.
- In automatic mode, manual commands are **refused**, not silently queued.

Every path that can move water — the button, and the AI assistant's tool call
— goes through the single `FarmProvider.requestPump`, so all four protections
apply uniformly.

### 9.3 Alert derivation

Alerts are **derived on every rebuild and never persisted**, so resolving a
condition clears its alert automatically and a stale warning is structurally
impossible. Categories: `soil`, `pump`, `sensor`, `weather`, `crop`;
severities: `info`, `warning`, `critical`. Conditions covered: dry soil, pump
stuck on, pump not responding, implausible sensor readings, controller
offline, heavy rain, heat stress, high evaporation, overdue farm tasks.
Several carry a one-tap remedy.

Tuning constants: `sensorTimeout` = 45 min (no reading ⇒ controller presumed
offline); `maxContinuousRuntime` = 2 h; automatic cycles are flagged as
overrunning at 6× their declared duration with a 1-minute floor, which absorbs
the coarse observation caused by the 3 s / 5 s firmware cadence without hiding
a genuinely stuck pump.

### 9.4 Crop recommender

14 West African crops — maize, tomato, cassava, pepper, okra, cowpea,
groundnut, lettuce, cabbage, onion, garden egg, sweet potato, watermelon, rice
— each scored 0–100 as a weighted sum of four independent fits:

| Factor | Weight |
| --- | --- |
| Forecast temperature fit | 40 |
| Season fit (Ghana major Mar–Jul, minor Sep–Nov) | 25 |
| Live soil moisture fit | 20 |
| Forecast 7-day rainfall fit | 15 |

Independence is deliberate: a crop can lose all its season points and still
rank well on climate, and the UI surfaces *why* each crop scored what it did.
Per-crop detail covers growth requirements, a growth calendar, grower tips and
common pests, and can write that crop's `recommendedThreshold` straight to the
controller.

### 9.5 On-device disease classification

TensorFlow Lite via `tflite_flutter`, running entirely on the handset (no
image leaves the phone; works with no signal). 38 PlantVillage classes in the
`Crop___Disease_Name` convention, mapped to organic treatment, chemical
treatment and prevention advice in `data/disease_database.dart`. Top-3
predictions are surfaced with confidence.

Two engineering points worth writing up:

- **Input shape, input type and class count are read from the model at load
  time**, not hard-coded; the service refuses to run if the `labels.txt` line
  count disagrees with the model's output tensor.
- **Pixel scaling cannot be inferred from a `.tflite` file** — the format
  records shape and dtype but not the preprocessing the model was trained
  with. Getting it wrong does not throw; it silently produces confident
  nonsense. The project therefore *declares* it in
  `assets/models/model_config.json` (`"inputScaling": "raw255"`).
- Output vectors are checked for whether they already form a distribution;
  softmax is applied only when they do not.

### 9.6 Farm-grounded assistant

An "Ask" chat that answers questions about *this* farm using a language model
over the **OpenAI-compatible chat-completions API**, so one client covers
Groq, OpenRouter, Together, vLLM, llama.cpp, LM Studio and Ollama. The backend
is a build-time flag (`--dart-define=ASSISTANT_BASE_URL / _MODEL / _API_KEY`)
because provider model IDs are renamed and retired frequently.

Three safety properties make it acceptable to point at a real pump:

1. **It cannot invent farm facts.** `logic/farm_brief.dart` builds the model's
   entire view of the farm as a pure function. Two rules shape it: *unknown is
   stated, never omitted* (silence in a context window becomes invention), and
   *age travels with every value* (`stalenessThreshold` = 10 min). The brief is
   regenerated per request and never replayed into history, so a stale value
   cannot be answered as current.
2. **It cannot move water directly.** A pump request arrives as a strict tool
   call and is executed through the same `FarmProvider.requestPump` the button
   uses, so automatic-mode refusal, the command lock, the debounce and the
   offline check all apply. The model then receives the *real* outcome and can
   only report that — "sent, not yet confirmed" never becomes "the pump is on".
3. **It cannot change the operating mode.** Switching to manual is the
   farmer's decision, so no tool for it exists.

### 9.7 History and analytics

Soil samples are logged **app-side**, not by firmware, so trend charts work
without reflashing the ESP32: 10-minute sample interval (plus an immediate
sample on any pump state change), 7-day retention, 1000-sample cap, pruned at
most hourly. Charts cover 24 h / 3 d / 7 d with the dry threshold drawn as a
reference line. Water usage is pump runtime converted to litres and irrigation
cycles. The database rules file indexes on `ts`; without it Firebase downloads
every sample and sorts client-side.

---

## 10. User interface

Five tabs: **Farm**, **Weather**, **Crops**, **Diagnose**, **Tasks**, plus
alerts, settings, farm setup, and the assistant.

Design decisions with engineering justification (see `docs/design-system.md`):

- **Plus Jakarta Sans is bundled as a variable font**, never fetched via
  `google_fonts`, which downloads at first paint — this app must render a
  moisture reading in a field with no signal. One file (weight axis 200–800)
  covers every weight, selected via `FontVariation`.
- The palette (brand greens `#2E7D32` / `#4CAF50`, sky blue `#4FC3F7`) splits
  every meaning in two: `growth` / `water` / `sun` / `alert` are
  contrast-checked for text, while `*Bright` variants are for fills only —
  sky blue on white measures 1.9:1 and fails as text.
- Widgets must use `context.farmColors`; hard-coding `Colors.blue` or
  `Colors.grey` breaks dark mode.
- The status band layers strictly: **an unconfirmed command outranks
  everything else**, so while a request is in flight the band describes the
  request, not the farm.

---

## 11. Verification

**131 unit tests across 9 suites**, all runnable with `flutter test` on a
machine with no device, no network and no Firebase project:

| Suite | Tests |
| --- | --- |
| `logic_test.dart` (advisor, recommender, alerts) | 26 |
| `pump_command_test.dart` | 18 |
| `farm_brief_test.dart` | 16 |
| `weather_advice_test.dart` | 16 |
| `rain_outlook_test.dart` | 15 |
| `field_band_test.dart` | 12 |
| `farm_status_test.dart` | 10 |
| `disease_model_test.dart` | 9 |
| `widget_test.dart` | 9 |

This testability is a *consequence of the architecture*, not an add-on: it is
possible only because `logic/` has no I/O.

**Evaluation still to be carried out by the author** *(the AI must not
fabricate these)*:

- Soil-probe calibration curve: raw ADC vs gravimetric moisture content.
- End-to-end command latency, measured against the predicted ~8 s bound.
- Water saved over a season vs a threshold-only baseline.
- Rain-delay decision accuracy: forecast rain events vs observed rainfall.
- Disease classifier accuracy on locally photographed leaves, not the
  PlantVillage validation split.
- Behaviour under induced Wi-Fi loss mid-cycle (verifies §6's safety claim).

---

## 12. Contributions to argue in the conclusion

1. **The phone as forecast proxy for a network-limited controller** — a
   general pattern for giving cheap edge hardware access to services it cannot
   reach, together with the staleness obligation that pattern creates and the
   retraction mechanism that discharges it.
2. **Command/state separation as a safety property**, expressed as a pure
   state machine whose timeout is *derived from the firmware's own loop
   constants* rather than guessed.
3. **Safety interlocks that do not depend on connectivity** — the cut-off
   timer runs unconditionally, including during reconnection.
4. **Derived-not-stored alerts**, which make stale warnings structurally
   impossible.
5. **A grounded LLM assistant over a real actuator**, safe by construction:
   pure-function grounding that marks unknowns, tool execution through the
   same guarded path as the UI, and no tool for the one decision that must
   remain the farmer's.
6. **Offline-first agronomy on a commodity phone** — bundled fonts, on-device
   inference, and a keyless weather API, so the app degrades gracefully rather
   than failing in a field with no signal.

---

## 13. Future work

- Move rain-block expiry into the firmware using `weather/updatedAt` so the
  controller is safe even if the phone never runs again.
- Multi-zone irrigation with per-zone probes and valves.
- Replace the PlantVillage classifier with a model trained on locally
  photographed Ghanaian crop disease, dropping the irrelevant temperate
  classes.
- Flow-meter feedback so litres are measured rather than inferred from runtime.
- Solar power with battery monitoring for off-grid deployment.
- A proxy for the assistant endpoint so no key ships inside the APK.
- Calibrate crop scoring weights against measured yield.

---

## 14. Suggested chapter mapping

| Chapter | Draw from |
| --- | --- |
| 1 — Introduction | §2 problem, §3 aim/objectives, §4 scope |
| 2 — Literature review | *author-supplied*; frame around threshold-only vs forecast-aware irrigation, IoT command/state reliability, edge ML for plant disease |
| 3 — Methodology / System design | §5 hardware, §6 firmware, §7 data contract, §8 architecture |
| 4 — Implementation | §9 algorithms, §10 interface |
| 5 — Testing and results | §11 (tests are real; field results are *author-supplied*) |
| 6 — Discussion, conclusion, future work | §12, §13, §4 limitations |

**Instruction to the generating AI:** do not invent measurements, graphs,
accuracy figures, survey responses, or citations. Where field data is required,
insert a clearly marked placeholder describing exactly what must be measured.
Prefer the project's own vocabulary — *command vs status*, *rain outlook*,
*derived alerts*, *pure logic layer* — and preserve the engineering
justifications, since the reasoning behind each constant is the substance of
the work.
