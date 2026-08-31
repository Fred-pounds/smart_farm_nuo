# Crop disease detection model

Disease detection runs entirely on-device — no network, no API key.

```
assets/models/plant_disease.tflite   # the classifier (1.1 MB, bundled)
assets/models/labels.txt             # 38 class names, one per line
assets/models/model_config.json      # pixel scaling — see below
```

## What is bundled

| | |
|---|---|
| Model | MobileNet, int8 weights, float32 I/O |
| Source | [`khhamid/plants-diseases-lite-model`](https://huggingface.co/khhamid/plants-diseases-lite-model) (MIT) |
| Input | `[1, 224, 224, 3]` float32, **raw 0–255** |
| Output | `[1, 38]` float32, already softmaxed |
| Classes | The standard PlantVillage 38 |

### Measured accuracy

Against 228 labelled images pulled from `leoho36/plant_village_dataset`
(6 per class, all 38 classes), using the same resize and scaling the app
applies:

| | |
|---|---|
| Top-1 | **98.2%** (224/228) |
| Top-3 | **99.6%** |

The four misses are all sensible confusions — `Potato___Late_blight` read as
`Tomato___Late_blight` is literally the same pathogen.

**Treat that number as an upper bound, not field accuracy.** PlantVillage
images are single detached leaves on a plain background under even lighting,
and this model was almost certainly trained on the same dataset these test
images came from. A real photo — soil, sun, several overlapping leaves — is a
harder problem than anything in that 98.2%. The number proves the wiring is
right (label order, scaling, output handling), not that the classifier is
trustworthy in a field.

## Pixel scaling — the part that fails silently

A `.tflite` file records its input **shape** and **dtype**, but not the
preprocessing it was trained with. Those are identical across every option
below, so the app cannot infer it. It is declared in `model_config.json`:

```json
{ "inputScaling": "raw255" }
```

| Value | Pixels become | Top-1 with the bundled model |
|---|---|---|
| `raw255` | 0–255 | **98.2%** |
| `unit` | 0–1 | 3.1% |
| `signed` | -1–1 | 3.1% |

Chance is 2.6% over 38 classes. **Getting this wrong does not throw** — the
model returns a confident, wrong diagnosis. `raw255` is correct here because
the model carries its own `Rescaling` layer, which is the Keras default when
you build one in.

If you swap the model, re-measure this before shipping. `test/disease_model_test.dart`
pins the declared value so the change is at least deliberate.

## Requirements for a replacement

| | |
|---|---|
| Format | TensorFlow Lite image classifier |
| Input | `[1, height, width, 3]`, float32 or uint8 |
| Output | `[1, num_classes]`, float32 or uint8 |
| Labels | One class name per line, in the model's output order |
| Scaling | Declared in `model_config.json` |

Input size and class count are read from the model at load time, so a 224×224
model and a 256×256 model both work with no code change.
`DiseaseService.load()` refuses to start if `labels.txt` has a different number
of lines than the model has output classes — that mismatch is the usual cause
of confidently wrong predictions.

A uint8-quantised input tensor ignores `inputScaling` and takes raw bytes: the
scaling lives in the tensor's own quantisation parameters, and applying it
twice would corrupt the input.

## Label format

Use the PlantVillage convention:

```
Tomato___Late_blight
Tomato___healthy
Corn_(maize)___Common_rust_
Pepper,_bell___Bacterial_spot
```

`lib/data/disease_database.dart` maps these strings to symptoms, organic and
chemical treatment, and prevention advice. Labels with no entry still work —
they are parsed into a crop and disease name and shown without treatment
guidance, so an unmapped class degrades gracefully rather than erroring.

**All 38 bundled classes are mapped** — apple (4), blueberry (1), cherry (2),
maize (4), grape (4), orange (1), peach (2), pepper (2), potato (3),
raspberry (1), soybean (1), squash (1), strawberry (2), tomato (10).
`test/disease_model_test.dart` fails if a class in `labels.txt` has no real
guidance behind it, so a model swap that widens the class list cannot quietly
ship dead entries.

## Getting a model

**Train your own (recommended for a project report).** The PlantVillage
dataset is on Kaggle. Fine-tune MobileNetV2 in Keras, then:

```python
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]   # ~4x smaller, quantised
open("plant_disease.tflite", "wb").write(converter.convert())

with open("labels.txt", "w") as f:
    f.write("\n".join(class_names))   # must match the generator's class order
```

Write `class_names` from your data generator's `class_indices`, sorted by
index — not from a hand-typed list, which is where ordering bugs come from.

**No-code alternative.** Google Teachable Machine → Image Project → export as
TensorFlow Lite (floating point). It ships a `labels.txt` alongside the model,
but strips the `Crop___Disease` convention, so rename the classes to match if
you want the treatment database to resolve.

**Pre-trained.** Search Kaggle or Hugging Face for "PlantVillage tflite".
Verify the label order against the model's outputs before trusting it.

## Size

Quantised MobileNetV2 over 38 classes lands around 3–9 MB, which is fine to
bundle. If you go above ~25 MB, consider downloading the model on first run
into the app's documents directory instead of bundling it as an asset.
