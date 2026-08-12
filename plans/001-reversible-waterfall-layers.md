# 001 — Make Waterfall layers reversible

- **Status**: DONE
- **Commit**: 26710e22
- **Severity**: MEDIUM
- **Category**: Interruptibility
- **Estimated scope**: 2 files, about 25 lines

## Problem

The full-text reader and source-preferences drawer become hidden immediately when the active class is removed. Their transform and opacity transitions therefore render only on entry; closing teleports away instead of reversing from the current state.

entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets:910 — current

    .waterfall-reader {
      position: fixed; z-index: 8; inset: 0; display: block; overflow: hidden;
      background: var(--paper); color: var(--ink); pointer-events: none; visibility: hidden;
      opacity: 0; transform: translateY(28px); transition: opacity 180ms ease-out, transform 220ms cubic-bezier(0.32, 0.72, 0, 1);
    }
    .waterfall-reader.active { pointer-events: auto; visibility: visible; opacity: 1; transform: translateY(0); }

entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets:978 — current

    .waterfall-preferences {
      position: fixed; z-index: 3; inset: auto 14px calc(14px + env(safe-area-inset-bottom)) 14px;
      display: block; max-height: min(72dvh, 560px); overflow-y: auto; padding: 18px 18px 20px;
      border: 1px solid rgba(38, 49, 60, 0.12); border-radius: 24px; background: #fbfcfd;
      box-shadow: 0 20px 60px rgba(39, 50, 62, 0.18); pointer-events: none; transform: translateY(calc(100% + 20px));
      visibility: hidden;
      transition: transform 220ms cubic-bezier(0.32, 0.72, 0, 1);
    }
    .waterfall-preferences.active { pointer-events: auto; transform: translateY(0); visibility: visible; }

## Target

Add the two motion tokens to the existing root token block:

    --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
    --ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);

Keep visibility visible until the 220ms exit finishes. Use transitions, not keyframes, so repeated open/close actions retarget from their current state:

    .waterfall-reader {
      opacity: 0;
      transform: translateY(28px);
      transition:
        opacity 180ms var(--ease-out),
        transform 220ms var(--ease-drawer),
        visibility 0s linear 220ms;
    }
    .waterfall-reader.active {
      visibility: visible;
      opacity: 1;
      transform: translateY(0);
      transition-delay: 0s;
    }

    .waterfall-preferences {
      opacity: 0;
      transform: translateY(calc(100% + 20px));
      transition:
        opacity 180ms var(--ease-out),
        transform 220ms var(--ease-drawer),
        visibility 0s linear 220ms;
    }
    .waterfall-preferences.active {
      visibility: visible;
      opacity: 1;
      transform: translateY(0);
      transition-delay: 0s;
    }

Do not add timers to WATERFALL_JS. CSS transitions own interruption and reversal.

## Repo conventions to follow

- Motion stays in the existing WATERFALL_CSS string; do not introduce a library.
- HtmlHotelHomeRenderer.ets:22 already uses the exact --ease-out token value.
- Existing Waterfall entry motion uses 180ms opacity and 220ms drawer movement; retain those budgets.

## Steps

1. Add --ease-out and --ease-drawer to the existing AGGREGATE_CSS root token block.
2. Update only the Waterfall reader and preferences selectors with opacity and delayed visibility transitions shown above.
3. Add string assertions to scripts/waterfall-renderer-interaction.test.mjs for both delayed visibility and active-state zero delay.
4. Add matching renderer-contract assertions to entry/src/test/HtmlHomeRenderer.test.ets only if needed to keep the existing Hypium contract explicit.

## Boundaries

- Do NOT change Waterfall markup, data flow, scroll behavior, iframe behavior, or source-selection logic.
- Do NOT animate top, left, right, height, margin, padding, or other layout properties.
- Do NOT add dependencies, timers, keyframes, or host bridge changes.
- Do NOT modify non-Waterfall renderers.
- If the cited selectors have drifted since commit 26710e22, STOP and report instead of improvising.

## Verification

- **Mechanical**:
  - Run node scripts/waterfall-renderer-interaction.test.mjs; expect exit code 0.
  - Run the entry Hypium command used by the repository and read entry/.test/default/intermediates/test/coverage_data/test_result.txt; expect Failure: 0 and Error: 0.
  - Run git diff --check; expect no output.
- **Feel check**:
  - On the 6WS device, open and close Zhihu full text repeatedly. Closing must slide down and fade instead of disappearing.
  - Open and close source preferences repeatedly before the prior transition finishes. Motion must reverse from its current position without restarting.
  - Record or inspect at slow speed and confirm visibility changes only after the 220ms exit.
- **Done when**: both layers enter and exit visibly, rapid reversal stays continuous, and no feed/player gesture changes.
