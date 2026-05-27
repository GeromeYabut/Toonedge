---
name: Utility-Premium Reader
colors:
  surface: '#12131a'
  surface-dim: '#12131a'
  surface-bright: '#383940'
  surface-container-lowest: '#0c0e14'
  surface-container-low: '#1a1b22'
  surface-container: '#1e1f26'
  surface-container-high: '#282a31'
  surface-container-highest: '#33343c'
  on-surface: '#e2e1eb'
  on-surface-variant: '#ccc3d8'
  inverse-surface: '#e2e1eb'
  inverse-on-surface: '#2f3037'
  outline: '#958da1'
  outline-variant: '#4a4455'
  surface-tint: '#d2bbff'
  primary: '#d2bbff'
  on-primary: '#3f008e'
  primary-container: '#7c3aed'
  on-primary-container: '#ede0ff'
  inverse-primary: '#732ee4'
  secondary: '#c8c6c5'
  on-secondary: '#303030'
  secondary-container: '#474746'
  on-secondary-container: '#b7b5b4'
  tertiary: '#c8c6c5'
  on-tertiary: '#313030'
  tertiary-container: '#676666'
  on-tertiary-container: '#e7e5e4'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#eaddff'
  primary-fixed-dim: '#d2bbff'
  on-primary-fixed: '#25005a'
  on-primary-fixed-variant: '#5a00c6'
  secondary-fixed: '#e4e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e5e2e1'
  tertiary-fixed-dim: '#c8c6c5'
  on-tertiary-fixed: '#1c1b1b'
  on-tertiary-fixed-variant: '#474746'
  background: '#12131a'
  on-background: '#e2e1eb'
  surface-variant: '#33343c'
typography:
  display:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  h1:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: -0.01em
  h2:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: '1.4'
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: '0'
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: '0'
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1'
    letterSpacing: 0.02em
  label-xs:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '600'
    lineHeight: '1'
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  container-margin: 20px
  gutter: 16px
---

## Brand & Style

The design system is centered on the concept of "Immersive Utility." It serves a dual purpose: acting as a high-performance tool for managing vast libraries while disappearing entirely during the reading experience. The aesthetic is strictly minimal, eschewing decorative trends like heavy blurs or neon glows in favor of clinical precision and high-contrast legibility.

The target audience consists of power users who value speed and organization. The UI should evoke a sense of professional-grade software—reliable, fast, and sophisticated. By combining a "true black" foundation with a single vibrant accent, the system achieves a premium feel that reduces eye strain during long-form consumption.

## Colors

This design system utilizes a "Deep Dark" palette optimized for OLED displays and low-light reading. The foundation is `#0A0A0A`, providing a true-black backdrop that makes content pop. 

- **Primary Accent:** Violet-Indigo (`#7C3AED`) is used sparingly for interactive states, progress indicators, and primary call-to-actions.
- **Surface Hierarchy:** Layering is achieved through varying shades of neutral grays. Tertiary surfaces (`#1A1A1A`) and secondary surfaces (`#262626`) define the structure without the need for shadows.
- **Contrast:** Text contrast is prioritized, with primary data in pure white and secondary metadata in a muted neutral gray to manage visual noise.

## Typography

The design system relies exclusively on **Inter** to maintain a systematic, utilitarian appearance. The typographic scale is tightly controlled to ensure that even data-dense screens remain legible.

- **Weight as Hierarchy:** Use semi-bold and bold weights to distinguish titles from metadata rather than relying on color alone.
- **Micro-Copy:** Label styles (XS and SM) are essential for status indicators (e.g., "Ongoing," "Read," "New") and should often utilize increased letter spacing for clarity at small sizes.
- **Reading Focus:** Body text is optimized for long-form reading with a generous 1.6 line-height to prevent eye fatigue.

## Layout & Spacing

This design system employs an 8px rhythmic grid. Layouts should feel spacious but structured, favoring alignment over decoration.

- **Grid Strategy:** A fluid 12-column grid is used for dashboard views, while reading views utilize a single-column centered layout with wide "safe-zone" margins.
- **The Search-First Hero:** The top of the primary interface is anchored by a high-prominence search bar that spans the full container width, emphasizing utility.
- **Vertical Rhythm:** Consistent 16px or 24px padding between list items ensures that scanability remains high even when the library grows significantly.

## Elevation & Depth

In alignment with the minimal and high-utility goals, this design system rejects traditional ambient shadows. Depth is communicated through **Tonal Layering** and **Crisp Borders**.

- **Tonal Tiers:** Components sit on surfaces that are slightly lighter than the background (e.g., a `#121212` card on a `#0A0A0A` background).
- **Stroke-Defined Hierarchy:** Elements are separated by 1px solid borders (`#262626`). This "ghost border" technique provides clear containment without adding the visual weight or "fuzziness" of shadows.
- **Active States:** Elevation "lift" is represented by changing the border color to the primary accent (`#7C3AED`) rather than increasing shadow depth.

## Shapes

The shape language is "Soft-Technical." Elements use a subtle 4px (0.25rem) corner radius to soften the high-contrast interface while maintaining a disciplined, crisp appearance.

- **Buttons & Inputs:** Use the standard `rounded` (4px) setting for a consistent tool-like feel.
- **Status Indicators:** Small chips and status dots should use `rounded-lg` (8px) to differentiate them from structural layout containers.
- **Cover Art:** Manga/Manhwa thumbnails should maintain the standard 4px radius to ensure they feel integrated into the system's grid.

## Components

### Search-First Hero Bar
A wide, persistent input field at the top of the interface. It features a `#1A1A1A` background, a 1px border, and uses the primary accent color only for the cursor and active focus state.

### Systematic List Items
Used for library management. Each item must include:
- A high-aspect-ratio thumbnail (4px radius).
- A primary title (White, Semi-bold).
- A status indicator (e.g., a small Indigo dot for "New" or a gray checkmark for "Read").
- Metadata labels for "Chapter X of Y" in a smaller, muted font.

### Buttons
- **Primary:** Solid `#7C3AED` with white text. No gradients.
- **Secondary:** Transparent background with a 1px `#262626` border.
- **Ghost:** No border or background; text-only, used for secondary actions like "Clear History."

### Detection Banners
Unobtrusive, slim bars that appear at the top of the viewport. Use a dark gray background (`#1A1A1A`) with a subtle indigo left-border accent. These should not overlap content but rather push the layout down to maintain the "utility-first" philosophy.

### Reading Controls
Floating, semi-transparent (`80% opacity`) dark bars that appear only on hover/tap. These should avoid blurs, using solid `#0A0A0A` to maintain high contrast for navigation icons.