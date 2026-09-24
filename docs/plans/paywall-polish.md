# Paywall Polish (Lite)

Mode: Lite

## Goal
- Solid green Continue button (Figma `#00920c`, no gradient)
- Badges above card border; selected badge matches green border + black text
- Fix Restore/Terms/Privacy footer alignment
- Gray xmark close top-left after 3s

## Log
- [x] Swift: Continue, badges, close
- [x] XIB: close position, legal stack, badge constraints
- [x] Build check
- [x] Hero top/bottom Figma overlays (120pt / 81pt)
- [x] Badge above dedicated border (not `layer.border`)
- [x] Settle layout before appear (no visible jump)
- [x] Dynamic light/dark colors via resolvedColor
- [x] Legal links above home indicator, centered group
- [x] Continue always-on shine; skeleton overlay pinned, labels keep layout
- [x] Scroll pinned to root.bottom; legal links via contentInset.bottom
