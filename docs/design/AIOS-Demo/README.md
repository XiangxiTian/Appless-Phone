# AIOS — Activity First home

A fixed-coordinate, high-fidelity concept prototype for a future operating system organized around continuing activities rather than apps.

## Open

Open `index.html` directly in a current desktop browser. No build step or package installation is required.

If the browser restricts local assets, serve the folder with any static server, for example:

```sh
python3 -m http.server 4187 --bind 127.0.0.1
```

Then visit `http://127.0.0.1:4187/`.

## Key interactions

- Use the desktop-only **Prototype Navigator** above the device to jump directly to Now, Library, Spaces, Activity, Object, Gallery, AI Command, Live, Generating, Journal, Journal Open, Journal Search, or Journal Filing.
- Select **AIOS Concept Design** to see the activity itself expand into its working space.
- Select either **Needs Attention** row to make its decision controls unfold in place.
- Select **Manage** to pin, reorder, or remove activities from Home.
- Use the bottom **按住说话** area to reveal the dismissible AI Command layer. The capsule’s HarmonyOS Symbol glyphs, material, and dimensions are migrated directly from the Appless aggregated-search prototype.
- Select the video icon on the right side of that capsule to enter **AI Live**. Microphone and video controls toggle their live states; the red end control contracts the live conversation into one persistent floating card.
- In **Generating**, five concise execution states arrive sequentially with current-line focus. They organize the existing conversation context and already-associated multimodal content; no retrieval or search is repeated. The only control is the round Stop button. The same card then becomes the internally scrollable **Journal**, with Add and Delete actions below it.
- **Live**, **Generating**, and **Journal** in the Prototype Navigator open each state directly. Generating always starts again from its first line.
- Select **加入日记** to watch the existing Journal card become a recognizable page, enter the already-populated My Journal, close with the same cover used in Gallery, and settle into Library. **Journal Filing** resets to the pre-filing state so the sequence can be replayed.
- In Library Gallery, select the canonical **My Journal** notebook object to open its latest entry directly. The reading surface keeps visible paper edges and binding structure without introducing an intermediate Collection Detail screen.
- In **Journal Open**, use the left/right controls to move between entries, select the center date for content-preview Quick Jump, search across entries and embedded objects, or use the pencil to edit text and select/delete embedded visuals. The persistent bottom AI conversation bar remains available.
- Move among **Now**, **Spaces**, and **Library** from the desktop Prototype Navigator.
- Use Search and the user/system entry in the top-right.
- In **Library**, open pinned Gallery collections, Recent Objects, Context/Time/Type/People lenses, or use **Frame** to review a Collection Proposal before it is created.
- The **Object** state exposes ownership relationships; **Gallery** returns to the Library Gallery rail, where My Journal behaves as a first-class notebook object.

The internal AIOS canvas is always 430 × 930. On smaller desktop windows, the complete device preview scales as one object; the interface inside does not reflow.

Design decisions, type scale, screen proportions, Gallery asset prompts, preview intent, and the SF Symbols workflow are documented in `DESIGN.md`.
