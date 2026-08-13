# Public Persona Design System

## Visual atmosphere

A quiet personal dossier: warm, editorial, and self-possessed. The page should feel like a carefully typeset profile assembled for one person, not an analytics dashboard or an AI-generated card grid. Information density is moderate, with one strong identity moment and deliberate whitespace between sections.

Design dials: variance 6, motion 3, density 4.

## Color system

Reuse the existing A2UI semantic palette.

- Page canvas: `COLOR_PANEL` / `#F8F5F0`
- Primary surfaces: `COLOR_CARD` / `#FFFFFF`
- Primary ink: `COLOR_INK` / `#211B17`
- Body copy: `COLOR_TEXT` / `#493F38`
- Secondary copy: `COLOR_MUTED` / `#7A6E64`
- Single accent: `COLOR_ACCENT` / `#995F4C`
- Accent wash: `COLOR_ACCENT_SOFT` / `#EFE2DC`
- Dividers: `COLOR_LINE` / `#E7DFD6`
- Destructive actions: existing error tokens only

Do not introduce gradients, AI purple, pure black, or additional feature colors.

## Typography

Use the HarmonyOS system family already inherited by the application.

- Profile name: 24–28 fp, bold, compact line height
- One-line summary: 14–15 fp, regular, 21–23 fp line height
- Section eyebrow: 11–12 fp, medium, muted or accent
- Section title: 16–18 fp, medium/bold
- Body/list rows: 13–14 fp, regular, 20–22 fp line height
- Metadata and usernames: 11–12 fp, muted

Hierarchy comes from size, weight, and spacing. Avoid uppercase display copy, decorative serif imports, or code-styled body text outside the Markdown editor.

## Component styling

### Profile hero

Use one white surface with 16 vp radius and a subtle existing border. Keep the avatar singular and prominent. Align identity text to the left of the visual center rather than stacking every element symmetrically. MBTI is a small accent control, not a headline badge.

Place the profile actions beneath the identity row as one optically centered vertical group: MBTI first, then the quieter “重新认识我” action. Do not merely stack them against the card's left edge.

### Profile sections

Use a small number of grouped surfaces. Identity is the strongest section. Expertise and interests can share a two-column row where width permits and fall into one column on narrow screens. Communication, focus, and personality use thin dividers instead of nested cards.

### Confirmed accounts

Each row shows the actual account avatar when present, then platform, display name, and `@username`. A platform logo is only a fallback. Rows use separators and generous touch height rather than individual floating cards.

### Markdown editor

The normal state shows only a centered text action, “查看 persona.md”, without a surrounding settings-style card. The expanded editor owns its header: `persona.md` on the left, with “收起” and “编辑” or “保存” together on the right. The expanded state uses the existing `TextArea` and current validation error message. Raw Markdown is never the default profile presentation.

## Layout principles

- 16 vp page gutter and 12–16 vp section rhythm
- One dominant hero followed by narrative content; avoid equal-weight dashboard tiles
- Preserve one primary avatar at the top
- Keep destructive deletion visually separate at the bottom
- Let content determine height; do not trap the rich profile inside a fixed-height inner scroll

## Motion principles

- Existing 120–220 ms ease-out tokens only
- Press feedback may use a restrained 0.97 scale or opacity shift
- Editor reveal may fade/translate by at most 6 vp
- No perpetual motion, bouncing, animated decoration, or `transition: all` equivalent
- Preserve meaningful state changes when reduced motion is preferred; omit spatial movement where supported

## Anti-patterns

- Raw Markdown as the default page
- A grid of equally weighted rounded cards
- Excessive pills or badges for every attribute
- Multiple accent colors or gradients
- Platform logos replacing available account avatars
- Evidence/explanation copy beside MBTI
- Model-generated HTML or a second persisted persona representation
