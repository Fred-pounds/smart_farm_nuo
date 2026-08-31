# Smart Farm

A Flutter companion app for an ESP32 soil-moisture irrigation controller,
extended into a full farm assistant: weather-aware irrigation advice, crop
recommendations, on-device disease detection, and a growth-stage task
calendar.

## Features

**Farm** — live soil moisture, pump status and manual/automatic mode over
Firebase Realtime Database, plus:

- **Smart irrigation advice** — fuses the soil reading with the rain forecast.
  Instead of "soil is dry", it says *"hold irrigation, 8 mm of rain is coming
  in 4 hours — saves about 800 litres"*, and can push a wetter dry-threshold
  to the ESP32 when evaporation is high.
- **Moisture trend charts** over 24 h / 3 d / 7 d, with the dry threshold
  drawn as a reference line.
- **Water usage** — pump runtime converted to litres and irrigation cycles.
- **Alerts** — dry soil, pump stuck on, pump not responding, implausible
  sensor readings, controller offline, heavy rain, heat stress, high
  evaporation, overdue farm tasks. Several carry a one-tap remedy.

**Weather** — current conditions, 24-hour outlook and a 7-day forecast from
Open-Meteo, with the numbers translated into farming decisions: irrigation
need, disease-pressure warnings, and spraying windows.

**Crops** — 14 West African crops scored 0–100 against your live soil
moisture, forecast temperature, forecast rainfall and the current month, each
with the reasons behind its score. Per-crop detail covers growth requirements,
a growth calendar, grower tips and common pests — and can write that crop's
recommended irrigation threshold straight to the controller.

**Diagnose** — photograph a leaf, classify it on-device with TensorFlow Lite,
and get organic treatment, chemical treatment and prevention advice for the
detected disease. Requires a model asset (see below).

**Tasks** — a farm calendar generated automatically from what you have
planted, bucketed into overdue / today / this week / this month.

## Setup

### 1. Firebase

Follow `FIREBASE_SETUP.md` for credentials. Then deploy the database rules so
the history query is indexed:

```bash
firebase deploy --only database
```

Without the `ts` index the app still works, but Firebase downloads every
sample and sorts on the client.

### 2. Disease detection model (optional)

Drop a TensorFlow Lite classifier into `assets/models/`:

```text
assets/models/plant_disease.tflite
assets/models/labels.txt
```

See `assets/models/README.md` for the format, label convention, and how to
train or obtain one. **The app builds and runs without it** — the Diagnose tab
shows setup instructions instead of the camera.

### 3. Run

```bash
flutter pub get
flutter run
```

Android needs `minSdk 26` (already set) for the TensorFlow Lite delegate.

## Architecture

```text
lib/
  models/      plain data classes, no Flutter imports
  data/        crop and disease knowledge bases
  logic/       pure decision functions — irrigation advisor, crop
               recommender, alert builder (all unit-tested)
  services/    Firebase, Open-Meteo, GPS, TFLite, preferences
  providers/   ChangeNotifiers bridging services to the UI
  screens/     one file per screen
  widgets/     reusable cards
  theme/       light/dark themes + semantic farm colours
```

Decision logic lives in `logic/` as pure functions so it can be tested without
Firebase, a network, or a device:

```bash
flutter test
```

### Who owns which field

`/farm` is not a one-way feed. Data flows in both directions, and each field
has exactly one writer:

| Field | Written by | Read by |
| --- | --- | --- |
| `mode`, `pump`, `threshold` | app | ESP32 |
| `pumpStatus`, `soilMoisture`, `temperature`, `humidity` | ESP32 | app |
| `irrigationDuration`, `irrigationReason` | ESP32 | app |
| `weather/rainExpected`, `weather/rainProbability` | **app** | ESP32 |

That last row is the third layer of the irrigation decision. The controller
has no route to a weather service, so it reads a rain outlook the app must
publish — see `logic/rain_outlook.dart`. If nothing publishes,
`rainExpected` stays `false` and rain delay never happens.

Publishing carries an obligation the other fields do not: a stale
`rainExpected: true` would hold the pump off indefinitely, and the controller
cannot tell a fresh outlook from a week-old one. `WeatherPublisher` therefore
retracts a standing delay once its forecast ages out. The durable fix is for
the firmware to expire the block itself using the `weather/updatedAt`
timestamp the app already writes.

### Farm assistant

`Ask` (the chat icon on the Farm header) answers questions about *this* farm
using Claude. Three properties make it safe to point at a real pump:

- **It cannot invent farm facts.** `logic/farm_brief.dart` builds the model's
  entire view of the farm as a pure function, marks every unknown as unknown,
  and carries the age of each reading. It is regenerated per request and never
  replayed into history, so a stale value can't be answered as current.
- **It cannot move water.** A pump request arrives as a strict tool call and is
  executed through the same `FarmProvider.requestPump` the button uses — so
  automatic-mode refusal, the command lock, the debounce and the offline check
  all apply. The model then receives the *real* outcome and can only report
  that; "sent, not yet confirmed" never becomes "the pump is on".
- **It cannot change the operating mode.** Switching to manual is the farmer's
  decision, so the assistant has no tool for it.

It runs on **free, open-weights models** over the OpenAI-compatible
chat-completions API, so one client covers Groq, OpenRouter, Together, vLLM,
llama.cpp, LM Studio and Ollama. Pick a backend at build time:

```bash
# Groq free tier — hosted and fast (default endpoint, just add a key)
flutter build apk --release --dart-define=ASSISTANT_API_KEY=gsk_...

# Ollama on your own machine — no key, no quota, no data leaves your network
flutter build apk --release \
  --dart-define=ASSISTANT_BASE_URL=http://192.168.1.20:11434/v1 \
  --dart-define=ASSISTANT_MODEL=qwen2.5:14b
```

The model must support **tool calling**, or the assistant will answer questions
but be unable to request a pump change. Provider model IDs get renamed and
retired often, which is why the model is a build flag — a 404 means check the
provider's current list, not a code change.

A hosted key compiled into an APK is **extractable**; fine on your own device,
not for distribution. Self-hosting (Ollama) or a proxy avoids that entirely.
Without either, every other feature works and the Ask screen says what's
missing.

### Conventions

Three conventions worth knowing before editing:

- **`pump` is a command; `pumpStatus` is the truth.** `pump` is what the app
  last asked for. `pumpStatus` is what the ESP32 measured. Only `pumpStatus`
  may drive anything that tells the farmer the pump is running. A request
  travels `sending → awaitingDevice → confirmed`, and reaching
  `timedOut`/`failed` instead means the physical outcome is *unknown* — never
  render that as success. The rules are pure functions in
  `logic/pump_command_machine.dart`; `FarmProvider` supplies the clock and
  performs the write. Anything that commands the pump goes through
  `FarmProvider.requestPump`, which carries the command lock, the debounce and
  the automatic-mode refusal.
- **The soil sensor reads higher when drier.** Crop thresholds, moisture
  scoring and threshold suggestions all depend on that sign.
- **Never hard-code `Colors.blue` or `Colors.grey` in a widget.** Use
  `context.farmColors` from `theme/app_theme.dart`, or dark mode breaks.

## Data sources

- Weather: [Open-Meteo](https://open-meteo.com) — free, no API key
- Disease classes: PlantVillage label convention (`Crop___Disease_Name`)
- Crop data: tuned for Ghana's major (Mar–Jul) and minor (Sep–Nov) seasons

Disease detection is a decision aid, not a substitute for an extension
officer. Confirm before applying any chemical.
