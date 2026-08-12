# 003 — Preserve feedback with reduced motion

- **Status**: DONE
- **Commit**: 26710e22
- **Severity**: MEDIUM
- **Category**: Accessibility
- **Estimated scope**: 2 files, about 25 lines

## Problem

The aggregate renderer globally forces every transition to 0.001ms and the Waterfall-specific rule then sets several transitions to none. This removes spatial motion, but it also removes opacity and color feedback that communicates presses and layer state.

entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets:718 — current

    @media (prefers-reduced-motion: reduce) {
      *, *::before, *::after {
        animation-duration: 0.001ms !important;
        animation-iteration-count: 1 !important;
        scroll-behavior: auto !important;
        transition-duration: 0.001ms !important;
      }
    }

entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets:1028 — current

    @media (prefers-reduced-motion: reduce) {
      .waterfall-entry button, .waterfall-toolbar button, .waterfall-preferences button,
      .waterfall-preferences label, .waterfall-empty button, .waterfall-reader { transition: none; }
      .waterfall-preferences { transition: none; }
      .waterfall-entry button:active, .waterfall-toolbar button:active, .waterfall-preferences button:active,
      .waterfall-preferences label:active, .waterfall-empty button:active { transform: none; }
    }

## Target

Do not alter the existing global aggregate rule in this plan. Override only Waterfall after that rule:

- Reader and preferences: remove movement with transform: none; retain a 140ms opacity transition and delayed visibility.
- Selected buttons from plan 002: remove scale movement; retain 140ms opacity/background-color feedback.
- Keep scroll-behavior: auto.

Exact reduced-motion layer pattern:

    .waterfall-reader,
    .waterfall-preferences {
      transform: none;
      transition:
        opacity 140ms var(--ease-out),
        visibility 0s linear 140ms !important;
    }
    .waterfall-reader.active,
    .waterfall-preferences.active {
      transition-delay: 0s !important;
    }

Exact reduced-motion press pattern:

    .waterfall-video-fullscreen-toggle,
    .waterfall-cinema-card a,
    .waterfall-read-button,
    .waterfall-reader-head button {
      transition: opacity 140ms var(--ease-out), background-color 140ms ease !important;
    }
    .waterfall-video-fullscreen-toggle:active,
    .waterfall-cinema-card a:active,
    .waterfall-read-button:active,
    .waterfall-reader-head button:active {
      transform: none;
      opacity: 0.82;
    }

Use !important only where required to override the earlier wildcard transition-duration declaration.

## Repo conventions to follow

- Keep this override inside the existing Waterfall prefers-reduced-motion block.
- Continue using the existing scroll-behavior: auto rule.
- Use the exact --ease-out token introduced by plan 001.
- Reduced motion keeps communicative opacity/color feedback and removes position/scale movement.

## Steps

1. Replace only the Waterfall-specific transition: none declarations with the layer and press patterns above.
2. Preserve transform: none for all existing Waterfall buttons and labels that currently suppress movement.
3. Add the plan-002 controls to the transform suppression list.
4. Add string assertions proving reduced motion keeps opacity transitions and removes transform movement.
5. Do not modify the aggregate-wide wildcard rule in this plan.

## Boundaries

- Do NOT change operating-system settings detection or add JavaScript media-query listeners.
- Do NOT restore drawer translation or button scale under reduced motion.
- Do NOT change non-Waterfall components.
- Do NOT use !important outside the reduced-motion override.
- If plans 001 and 002 are not applied or the selectors drifted since commit 26710e22, STOP and report.

## Verification

- **Mechanical**:
  - Run node scripts/waterfall-renderer-interaction.test.mjs; expect exit code 0.
  - Run the entry Hypium suite and read test_result.txt; expect Failure: 0 and Error: 0.
  - Run git diff --check; expect no output.
- **Feel check**:
  - Enable reduced motion on the 6WS device.
  - Open and close full text and source preferences. Neither layer may translate; each must still fade for 140ms.
  - Press the selected controls. They must not scale but must visibly change opacity.
  - Disable reduced motion and confirm the standard 180–220ms movement returns.
- **Done when**: reduced-motion users retain clear state and press feedback without translation or scale movement.
