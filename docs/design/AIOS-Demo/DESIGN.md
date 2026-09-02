# AIOS Activity First — design notes

## Information hierarchy

The home screen answers one question: “What is already in motion?” It therefore has four visible levels, in a fixed order:

1. **Current Activity** — one continuing activity, represented as a persistent place with a stage, recent change, and a working set of real objects.
2. **Needs Attention** — at most two decisions that belong to continuing activities. They expand in place instead of behaving like notifications.
3. **In Progress** — user-curated activities with stable ordering and explicit management controls.
4. **AI Conversation** — a persistent, voice-first composer replaces app-like bottom navigation. Stable locations remain available through the desktop Prototype Navigator.

The object model is not exposed as navigation. Actors, objects, capabilities, and spaces appear only where they explain the current activity.

## 430 × 930 spatial plan

- 0–64: hardware and system safe area
- 76–154: page title, date, and two system actions
- 168–488: current activity and its working-set previews
- 512–694: two attention items
- 724 onward: stable in-progress activities; natural vertical scrolling is intentional
- 824–930: translucent voice-first AI composer and protected content safe area

The desktop shell scales the entire 432 × 932 neutral rounded-rectangle preview to the available window height. The internal 430 × 930 screen never reflows or scales independently.

## Typography

- Page title: 36/40, 700
- Current activity title: 31/34, 700
- Activity-space title: 35/38, 700
- Section title: 21/25, 700
- Activity title: 18/22, 650
- Stage / main supporting text: 17/22 and 16/22
- Secondary text: 14/19
- Weak metadata only: 12–13/16

## Object previews

The current activity contains three actual working objects rather than decorative thumbnails:

- `interface-architecture.svg` — the active interface architecture frame
- `object-model.svg` — the Actor → Activity → Object relationship map
- `material-study.svg` — a surface/material exploration used by the prototype

The expanded activity space reuses these same objects to preserve continuity.

## SF Symbols

The exact system symbol names are recorded in `assets/icons/sf-symbols/manifest.json`. Web-ready PNGs are rendered from macOS `NSImage(systemSymbolName:)`, so their geometry is the installed Apple system artwork. They can later be replaced by SVG exports at the same asset references without changing layout.

## Library extension

Library keeps two values visible at once: deterministic retrieval and emotionally meaningful presentation. Its hierarchy is Gallery → Recent → Browse, with normal scrolling rather than reduced type or compressed objects.

- **Gallery** is a horizontally stable rail of user-pinned Collections, not an AI recommendation feed. Each Collection has an object-like visual identity.
- **Recent** reflects the user’s latest relationship to an Object—edited, received, viewed, generated, or saved—not only file modification time.
- **Browse** exposes four fixed lenses: Context, Time, semantic Type, and People. Context uses Space → Activity → Object rather than a folder tree.
- **Object Detail** makes belonging, actors, relationships, and available capabilities inspectable without opening an app.
- **Collection Detail** remains available for ordinary framed collections. My Journal is deliberately different: the notebook object opens its latest readable entry directly, while any management belongs in secondary chrome rather than the primary path.
- **Frame this content** always produces a confirmable Collection Proposal before changing the pinned Gallery.

The desktop-only Prototype Navigator is intentionally outside the 430 × 930 system canvas and has no relationship to AIOS navigation.

The bottom composer directly reuses the aggregated-search control’s 387 × 61 geometry, original cool-gray glass material, “按住说话” label, and HarmonyOS `keyboard_circle` glyph. The main area opens AI Command while the right-side video glyph is an independent AI Live entry.

The right-side glyph is now an independently operable `video_fill` entry into AI Live. AI Live is a full-screen conversational state centered on the user-provided translucent blue assistant character, with no titles or status copy and only three persistent call controls: microphone, video, and end. Audio begins muted and video begins off; both controls expose their current state.

## AI Live → Journal continuity

Ending AI Live does not navigate to another page. The atmosphere and assistant settle while one near-safe-width material card forms from the conversation. That card keeps its 390 × 720 geometry through both remaining states:

1. **Generating** — five short execution states arrive one at a time: organize the conversation, extract key moments, integrate already-associated multimodal content, generate the entry body, and compose text with visuals. Only the current line is large and strong; completed lines move upward, shrink, and fade. Future lines do not exist in the DOM yet. This stage does not search or retrieve again, has no progress indicator or completion copy, and keeps only the round `square.fill` Stop action below the card.
2. **Journal** — the generating lines crossfade away and the same card rearranges into a fixed journal surface. The card itself stays still while its document scrolls internally with the scrollbar hidden. Add and Delete controls sit outside the scroll region.

The journal is intentionally approximately two internal viewports long. Its only image assets are a semantic rainy-street scene, a transparent personal proposal booklet, and a transparent personal folded umbrella. A line-drawn weather mark and an unlabeled voice trace provide quiet metadata without adding explanatory interface copy. Delete uses a compact confirmation and contracts the card away; the primary action begins the spatial filing sequence below.

## Journal Object → My Journal → Library

“加入日记” now expresses a relationship rather than a success message. The exact Journal card remains the shared element: its controls leave, its material becomes paper, and its readable identity compresses to the title, rainy scene, and a small amount of text structure. An existing open My Journal forms beneath it from four paper layers, so accumulation is conveyed by physical thickness rather than a count.

The page aligns with the right-hand binding area and settles before the front cover closes once. The page and open-book DOM use the canonical PNG’s measured high-opacity body ratio of approximately 0.691. Closing is performed by the exact `my-journal-closed.png` asset, not a CSS approximation; that same PNG is the live My Journal object in Gallery. During the final movement the book axis remains stable while the Library environment appears around it; a measured shared-element flight places the PNG over its live Gallery target, then hands visibility to that identical target without a white flash, success toast, or duplicate label.

The filing timeline is an interruptible async sequence driven by Web Animations API `finished` promises: focus → page morph → book reveal → page insert → book close → Library reveal. Navigation or Escape cancels active animations and restores a clean state. **Journal Filing** in the external navigator returns to the exact pre-click result so the complete sequence is replayable without an in-device debug control.

## My Journal reading structure

Selecting My Journal skips Collection Detail and opens the latest entry as one readable page. A narrow spine and several offset paper layers remain visible behind the page, communicating an accumulated book without forcing a full two-page spread. Previous/next navigation is chronological, the latest entry disables Next, and the center date opens a compact Quick Jump made from dates plus content previews. Search returns entries and embedded visual objects in the same result surface. Pencil mode makes entry text editable and allows embedded visuals to be selected, removed, and added back.

The persistent 387 × 61 AI conversation control stays in its existing bottom position throughout Journal Open and Journal Search; the reading surface and transient panels reserve its safe area.

### Gallery generation prompts

Three supporting Gallery assets were generated with the built-in image generation tool as transparent, minimalist product objects. My Journal is excluded from this list because it directly reuses the user-provided canonical PNG documented in `assets/SOURCES.md`.

- `outfit-cabinet.png`: compact neutral wardrobe, hanging garments and folded textiles.
- `tokyo-memories.png`: keepsake tray with map, ticket, and Tokyo photo prints.
- `aios-archive.png`: translucent archival folio containing interface and system-model sheets.

Shared constraints: real alpha transparency, centered object silhouette, soft contact shadow, no readable text, no logos, no watermark, no cartoon or 3D-emoji treatment, no high saturation, and no warm-beige cast.
