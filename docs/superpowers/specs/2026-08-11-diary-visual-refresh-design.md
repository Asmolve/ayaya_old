# Diary Visual Refresh Design

## Goal

Make Diary a polished, responsive Notes workspace while preserving existing selection and editor behaviour.

## Asset Delivery

Serve Notes assets from `/m/notes/assets`, so CSS, importmap, and JavaScript use the Notes nginx route instead of the core `/assets` route.

## Navigation and Calendar

Use a compact Notes brand, rounded Notes/Diary switch, and previous/current/next quarter controls. Render three rounded month cards on desktop and one column on narrow screens. Days have clear hover/focus states, selected ranges use continuous accent fills, weekends are restrained red, and saved entries retain noninteractive indicators.

## Modal Editor

Keep the panel within the viewport with internal scrolling and a large radius. Use unified rounded fields. Constrain the Action Text toolbar inside the editor; at narrow widths it wraps or scrolls horizontally rather than overflowing. Keep Save/Delete inside a responsive footer.

## Verification

Add rendering coverage for the scoped asset prefix and retain existing browser coverage for selection, rich editing, touch, drafts, save, and delete. Verify nginx serves scoped CSS/JS paths.
