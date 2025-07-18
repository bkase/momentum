# Momentum Brand Reference

This document serves as a comprehensive reference for the Momentum app's visual design system. All UI elements should adhere to these guidelines to maintain a consistent "digital sanctuary" aesthetic.

## Design Philosophy

Momentum embodies an **Educational Zen** aesthetic that creates a digital sanctuary for deep work. The design emphasizes:
- Warm, organic colors reminiscent of high-quality paper
- Classical serif typography for a literary, timeless quality
- Generous whitespace for visual breathing room
- Subtle, confirmatory animations
- Centered, symmetric layouts

## Color Palette

### Primary Colors
- **Canvas Background** (`canvasBackground`): `#F9F7F4` - Warm off-white, like aged paper
- **Accent Gold** (`accentGold`): `#C79A2A` - Muted, sophisticated gold for key actions and highlights
- **Border Neutral** (`borderNeutral`): `#E3DDD1` - Soft, low-contrast neutral for borders

### Text Colors
- **Primary Text** (`textPrimary`): `#111111` - Soft black for main content
- **Secondary Text** (`textSecondary`): `#6D4F1C` - Desaturated brown-gold for labels and secondary content
- **Tertiary Text** (`textTertiary`): `#999999` - Gray for de-emphasized content

### Interactive States
- **Hover Fill** (`hoverFill`): `#FDF9F1` - Soft cream for hover states
- **White**: `#FFFFFF` - Input backgrounds and cards
- **Red**: System red for errors and warnings

## Typography

### Fonts
- **Headings & CTAs**: New York (serif) - Literary, timeless quality
  - Title: 28pt regular (`momentumTitle`)
  - Button text: 18pt italic
- **Body & UI Text**: SF Pro (system sans-serif) - Modern clarity
  - Body: 14-16pt regular
  - Labels: 11pt semibold with 2pt letter spacing
  - Captions: 12pt regular

### Font Styles (defined in Font+Extensions.swift)
- `.momentumTitle`: New York 28pt for main headings
- `.sectionLabel`: System 11pt semibold, uppercase, 2pt letter spacing
- System fonts for body text with appropriate sizes

## Spacing System

### Container Layout
- **Width**: 320px fixed (`momentumContainerWidth`)
- **Padding**:
  - Top: 24px (`momentumContainerPaddingTop`)
  - Horizontal: 20px (`momentumContainerPaddingHorizontal`)
  - Bottom: 24px (`momentumContainerPaddingBottom`)

### Section Spacing
- Between sections: 24px (`momentumSectionSpacing`)
- Title to content: 24px (`momentumTitleBottomPadding`)
- Button section padding: 24px (`momentumButtonSectionTopPadding`)

### Component Spacing
- Small: 4px (`momentumSpacingSmall`)
- Medium: 8px (`momentumSpacingMedium`)
- Large: 12px (`momentumSpacingLarge`)
- Extra Large: 24px (`momentumSpacingXLarge`)

### Component-Specific Padding
- Text fields: 16px horizontal, 12px vertical
- Duration fields: 8px horizontal, 4px vertical
- Checklist rows: 14px horizontal, 10px vertical
- Buttons: 24px horizontal, 14px vertical

## Visual Elements

### Borders & Corners
- **Main corner radius**: 3px (`momentumCornerRadiusMain`)
- **Small corner radius**: 2px (`momentumCornerRadiusSmall`)
- **Focused border width**: 2px (`momentumBorderWidthFocused`)
- **Neutral border width**: 1px (`momentumBorderWidthNeutral`)

### Shadows
- **Focus shadow**: Black 15% opacity, 2px radius
- **Hover shadow**: Black 15% opacity, 4px radius
- **Shadow opacity**: 0.15 (`momentumShadowOpacity`)

### Animation
- **Quick transitions**: 0.15s (`momentumAnimationDurationQuick`)
- **Standard transitions**: 0.3s (`momentumAnimationDurationStandard`)
- **Easing**: `easeOut` for all animations
- **Transitions**: Gentle cross-fades using `.transition(.opacity)`

## Component Styles

### Buttons

#### Primary Button (SanctuaryButtonStyle)
- Serif italic text
- White background, gold accent on hover
- 2px gold border
- Hover lift effect with shadow
- Disabled: 30% opacity

#### Secondary Button
- Sans-serif text
- Transparent background, white on hover
- 1px neutral border
- Subtle hover state

### Text Fields (IntentionTextFieldStyle)
- White background
- 1px neutral border, 2px gold on focus
- 16px horizontal padding, 12px vertical
- Focus shadow effect

### Checkboxes (ChecklistToggleStyle)
- Custom square design
- Gold border on hover/checked
- Checkmark fills when complete
- Scale animation on press

## View Modifiers

The following view modifiers are available in `View+Styling.swift`:

- `.momentumContainer()` - Standard container layout
- `.momentumTitleStyle()` - Title typography and spacing
- `.momentumSectionLabel()` - Section label styling
- `.momentumBodyText()` - Body text with proper line spacing
- `.momentumSecondaryText()` - Secondary text styling
- `.momentumCard()` - Bordered content card
- `.momentumSection()` - Section wrapper with spacing

## Implementation Guidelines

1. **Always use semantic color names** from `Color+Extensions.swift`
2. **Apply consistent spacing** using constants from `UIConstants.swift`
3. **Use custom button styles** instead of system styles
4. **Maintain visual hierarchy** with proper typography scales
5. **Keep layouts centered and symmetric**
6. **Avoid jarring transitions** - use subtle, confirmatory animations
7. **Test all interactive states** (normal, hover, pressed, disabled)

## Examples

### Standard View Structure
```swift
VStack(spacing: 0) {
    Text("Title")
        .momentumTitleStyle()
    
    VStack(spacing: .momentumSectionSpacing) {
        // Content sections
    }
    
    Button("Action") {}
        .buttonStyle(.sanctuary)
        .padding(.top, .momentumButtonSectionTopPadding)
}
.momentumContainer()
```

### Section with Label
```swift
VStack(alignment: .leading, spacing: .momentumSpacingMedium) {
    Text("SECTION LABEL")
        .momentumSectionLabel()
    
    Text("Content")
        .momentumBodyText()
}
```

This design system creates a cohesive, calming interface that stands apart from typical productivity apps, offering users a true digital sanctuary for deep work.