# Asset sources

## Appless aggregated-search AI conversation control

- Source project: `/Users/xuan/.codex/worktrees/0d47/https-github-com-xiaoluolyg-appless-phone/design-prototype`
- Migrated runtime asset: `harmony-symbols/HMSymbol.ttf`
- Original source: Huawei HarmonyOS Symbol, <https://developer.huawei.com/consumer/cn/design/harmonyos-symbol/HarmonyOS>
- Mapping: `keyboard_circle` = `U+F0172`; `video_fill` = `U+F00A3`; `video_slasj_fill` = `U+F0841`; `mic_fill` = `U+F0315`; `mic_slash_fill` = `U+F0317`; `xmark` = `U+F0056`.
- Usage: the AIOS bottom conversation control reuses the reference glyphs, 387 × 61 geometry, and aggregated-search material values; its right-side control is independently operable for AI Live.

## Apple SF Symbols for AI Live and Journal

- Source: macOS `NSImage(systemSymbolName:)`, exported by `tools/export_symbols.swift`.
- Mapping: microphone = `mic.fill` / `mic.slash.fill`; video = `video.fill` / `video.slash.fill`; end = `xmark`; generation stop = `square.fill`; journal delete = `trash`.
- Usage: the AI Live call controls and the two icon-only Journal actions use rasterized official Apple system symbols rather than private font code points.

## AI Live assistant image

- Source: user-provided transparent PNG from the AI Live visual reference.
- Local file: `ai-live/ai-avatar.png`.
- Usage: the sole central AI presence on the full-screen AI Live surface; no supporting title or status copy is shown.

## AI Live → Journal story assets

All three were created with the built-in OpenAI image generation tool for this prototype. They are the only image assets inside the final journal card.

- `journal/rainy-street.png` — full-frame rainy street scene. Prompt: “Editorial journal illustration, 16:9. A modern office-district street just after rain at early evening: wet pavement, shallow puddles, cool blue-gray reflections, a recently cleared sky, restrained urban details and a few small distant figures. Ground the scene in believable space and light. Quiet, observant, understated and personal; no readable text, logos, neon spectacle, cinematic grading, AI glow, warm beige cast, or hyperreal product-photography treatment.”
- `journal/notebook-cutout.png` — transparent personal proposal-booklet cutout. Final prompt: “A transparent cutout derived from a casual iPhone snapshot: one thin A4 proposal booklet, not a notebook or hardcover, with a flexible light blue-gray matte paper cover, visibly 12–18 sheets, slightly misregistered inner pages, a gently curled corner and minor handling wear. Ordinary three-quarter-above angle; cool uneven office window/overhead light, modest smartphone dynamic range and a tiny natural contact shadow. Complete uncropped subject with true alpha. Avoid a thick journal, premium product shot, catalog/studio light, CGI, illustration, sticker border, white outline, rim light, halo, pristine condition, readable writing, logo or watermark.”
- `journal/umbrella-cutout.png` — transparent personal folded-umbrella cutout. Final prompt: “A transparent cutout derived from a quick casual iPhone photo: one ordinary compact folding umbrella just used after rain, loosely and imperfectly rolled, with pale blue-gray lightweight fabric, uneven real folds, a twisted strap, thin dark handle/wrist cord and a few damp spots. Natural three-quarter-above angle; cool uneven ambient light, modest smartphone dynamic range and local fabric shadows. Complete uncropped subject with true alpha. Avoid a retail packshot, catalog/studio image, perfect centering, pristine fabric, CGI, illustration, icon, sticker border, white outline, rim light, glow, branding or watermark.”

## Canonical My Journal notebook

- Source: user-provided transparent notebook PNG; it is reused directly and was not regenerated or visually redesigned.
- Local file: `journal/my-journal-closed.png`.
- Native canvas: 1086 × 1448 RGBA. The high-opacity main book body is approximately x 140–951 and y 71–1244, giving a cover/page body ratio of about 0.691; the lower ribbon remains part of the canonical canvas.
- Usage: the My Journal object in Library Gallery, the closing cover during Journal Filing, the final shared-element flight, and the Gallery handoff all use this exact file. The DOM page used during filing follows the measured body ratio instead of the PNG canvas ratio.

## Outfit Cabinet Library cover

- Source: user-provided transparent outfit PNG, reused directly without image generation.
- Local file: `gallery/outfit-cover-model.png` (1024 × 1536 RGBA).
- Usage: Library Gallery only. The transparent person PNG is presented directly as the independent Outfit Cabinet object, with no cover substrate, paper layer, border, or generated background. Outfit Cabinet detail and every other page retain their existing assets and behavior.

## Now home avatar

- Source: user-provided avatar image, reused directly without generation or visual alteration.
- Local file: `profile/user-avatar.jpg` (512 × 512).
- Usage: circular user avatar in the top-right corner of the Now home screen.

## Lin avatar

- Source: user-provided crocodile illustration, reused directly without generation.
- Local file: `profile/lin-crocodile.png` (1024 × 1024).
- Usage: Lin's circular avatar in the Now screen collaboration item.

## Now wallpaper

- Source: user-provided blue-and-black wallpaper, reused directly without generation.
- Local file: `wallpapers/now-blue.png` (853 × 1844).
- Usage: full-bleed background of the Now home screen only.
