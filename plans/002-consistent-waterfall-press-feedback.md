# 002 — Unify Waterfall press feedback

- **Status**: DONE
- **Commit**: 26710e22
- **Severity**: MEDIUM
- **Category**: Physicality and origin
- **Estimated scope**: 2 files, about 20 lines

## Problem

The newly added full-screen control has no transition, active feedback, pointer cursor, or focus-visible treatment. The full-text and reader-close buttons receive scale(0.96) from a shared active rule but have no base transform transition, so the scale snaps instead of feeling pressed.

entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets:843 — current

    .waterfall-video-fullscreen-toggle {
      position: absolute; z-index: 7; top: max(100px, calc(74px + env(safe-area-inset-top))); right: 28px;
      min-height: 40px; border: 0; border-radius: 999px; background: rgba(20, 24, 28, 0.78); color: #fff;
      padding: 0 14px; font-size: 12px; font-weight: 760;
    }

entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets:902 — current

    .waterfall-cinema-card a, .waterfall-read-button {
      display: inline-flex; min-height: 44px; align-items: center; justify-content: center; width: fit-content;
      border: 1px solid #2f4e6f; border-radius: 999px; background: #2f4e6f; color: #fff;
      padding: 0 16px; font-size: 13px; font-weight: 780; text-decoration: none; cursor: pointer;
    }

entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets:923 — current

    .waterfall-reader-head button {
      min-width: 56px; min-height: 44px; border: 1px solid var(--line-strong); border-radius: 999px; background: var(--panel-strong); color: var(--ink);
      font-size: 12px; font-weight: 760;
    }

## Target

Use one crisp press response for these three controls:

    transition: transform 140ms var(--ease-out), background-color 180ms ease;

Increase the full-screen control to the existing 44px minimum touch target and add cursor: pointer. Use scale(0.97), not scale(0.96), for the full-screen, full-text, source-link, and reader-close controls:

    .waterfall-video-fullscreen-toggle:active,
    .waterfall-cinema-card a:active,
    .waterfall-read-button:active,
    .waterfall-reader-head button:active {
      transform: scale(0.97);
    }

Add the full-screen control to the existing focus-visible outline selector. Do not change toolbar/source-preference button feedback.

## Repo conventions to follow

- The exact --ease-out value is added by plan 001 and matches HtmlHotelHomeRenderer.ets:22.
- A2uiButtonView.ets already uses 120ms EaseOut for native button feedback; 140ms is the existing ArkWeb button budget in this renderer.
- Existing controls use 44px minimum height and a 2px accent outline with 3px offset.

## Steps

1. Add min-height: 44px, cursor: pointer, and the exact transition to .waterfall-video-fullscreen-toggle.
2. Add the same transition to .waterfall-cinema-card a, .waterfall-read-button, and .waterfall-reader-head button.
3. Remove the read and reader-close selectors from the shared scale(0.96) rule, then add the exact scale(0.97) rule shown above.
4. Add .waterfall-video-fullscreen-toggle:focus-visible to the existing focus-visible selector.
5. Add focused CSS contract assertions to scripts/waterfall-renderer-interaction.test.mjs and, if needed, entry/src/test/HtmlHomeRenderer.test.ets.

## Boundaries

- Do NOT animate the video iframe, full-screen card geometry, progress bar, or card scrolling.
- Do NOT change button labels, event listeners, markup structure, source-link behavior, or accessibility names.
- Do NOT add hover scale on touch devices.
- Do NOT add dependencies.
- If plan 001 has not added --ease-out or the cited selectors drifted since commit 26710e22, STOP and report.

## Verification

- **Mechanical**:
  - Run node scripts/waterfall-renderer-interaction.test.mjs; expect exit code 0.
  - Run the entry Hypium suite and read test_result.txt; expect Failure: 0 and Error: 0.
  - Run git diff --check; expect no output.
- **Feel check**:
  - On the 6WS device, press and hold 全屏, 退出全屏, 阅读全文, 查看来源, and 关闭.
  - Every control must compress subtly and recover without a snap; video controls must remain draggable.
  - Use keyboard focus in an ArkWeb debugging environment if available and confirm the full-screen control receives the same visible focus ring.
- **Done when**: all selected controls share the same responsive press feel and player gestures remain unaffected.
