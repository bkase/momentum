# Make the ui consistent
**Status:** Done
**Agent PID:** 86469

## Original Todo
This means for the ActiveSessionView, AnalysisResultView, and AwaitingAnalysisView be consistent with the design in PreparationView -- as part of this task we should refactor the styling in PreparationView into a brand asset catalog. Please generate a brand reference using the fonts and colors that are currently in PreparationView as the ground-truth but for anything missing refer to @docs/brand.md .

## Description
We'll update ActiveSessionView, AnalysisResultView, and AwaitingAnalysisView to match PreparationView's sophisticated design system. This involves applying the existing brand colors, typography, spacing, and custom styles to create a cohesive "digital sanctuary" experience across all views. Rather than creating a new asset catalog (which would add unnecessary complexity), we'll leverage the existing Color and Font extensions while ensuring consistent application of the brand guidelines.

## Implementation Plan
- [x] Create shared spacing constants in a new file `MomentumApp/Sources/Extensions/Spacing+Constants.swift`
- [x] Update ActiveSessionView to use brand design system (MomentumApp/Sources/Views/ActiveSessionView.swift)
- [x] Update AnalysisResultView to use brand design system (MomentumApp/Sources/Views/AnalysisResultView.swift)
- [x] Update AwaitingAnalysisView to use brand design system (MomentumApp/Sources/Views/AwaitingAnalysisView.swift)
- [x] Create reusable view modifiers for consistent styling in `MomentumApp/Sources/Extensions/View+Styling.swift`
- [x] Generate brand reference documentation in `docs/brand-reference.md`
- [x] Automated test: Verify all views compile and pass existing tests
- [x] User test: Launch app and visually verify all four views have consistent styling

## Notes
[Implementation notes]