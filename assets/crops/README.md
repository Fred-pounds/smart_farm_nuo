# Crop photography

This directory is an **image slot**. Any crop without a picture here still
renders, so it can be as full or as empty as you like.

`CropImage` looks for `assets/crops/<crop id>.jpg`, then
`assets/crops/<crop id>.jpeg`. If either is there it is drawn; if neither is,
the card falls back to a tinted plate carrying the crop's emoji. The fallback
is the same size and shape as the photo, so adding pictures later changes
nothing about the layout.

**Present so far:** `maize.jpeg`.

## Adding pictures

Drop in files named by crop id. The fourteen ids in the catalogue are:

```
maize        tomato       cassava      pepper
okra         cowpea       groundnut    lettuce
cabbage      onion        garden_egg   sweet_potato
watermelon   rice
```

So `assets/crops/maize.jpg`, `assets/crops/sweet_potato.jpeg`, and so on —
either extension works.

No code or `pubspec.yaml` change is needed — the whole directory is already
declared as an asset bundle.

## What makes a good one

The cards render these as small squares, cropped with `BoxFit.cover`, in both
light and dark themes.

- **Square, or close.** Anything much wider than 1:1 loses its subject to the
  crop.
- **512×512 is plenty.** The largest on-screen size is 60pt. Shipping 3000px
  photographs would add megabytes to the APK for no visible gain.
- **Subject centred and filling the frame.** Cover-cropping trims the edges.
- **Consistent lighting across the set.** Fourteen photographs from fourteen
  sources look worse in a grid than fourteen emoji plates do. Treat this as
  all-or-nothing.
- **A white background is fine, but commit to it.** Studio shots on white are
  the marketplace idiom the crop cards are built around, and they read well in
  both themes. What does not work is mixing white cut-outs with in-field
  photographs — the grid then looks like two different apps.

## Licensing

Everything in this directory ships inside the APK, `maize.jpeg` included, and
none of it has been licensed on your behalf. Make sure you hold distribution
rights for each image before the app goes anywhere — a stock photo used
without a licence is the kind of thing that surfaces at a demo.
