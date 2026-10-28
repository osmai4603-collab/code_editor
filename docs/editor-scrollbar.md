# Editor scrollbars

The editor surface uses custom vertical and horizontal scrollbars over its text
area. The vertical scrollbar follows the text field's scroll position, while
the line-number gutter is kept in sync. The horizontal scrollbar controls the
single-line-wide text viewport so long code lines can be reached without
wrapping.

`EditorAreaWidget` defaults to `EditorScrollbarVisibility.auto`. Pass
`EditorScrollbarVisibility.visible` to keep both scrollbar thumbs visible, or
`EditorScrollbarVisibility.hidden` to remove them. In automatic mode, a
scrollbar appears while its track is hovered or briefly after scrolling.
Dragging the thumb moves proportionally through the content; clicking the track
moves by one viewport page.

Scrollbar colors are provided by `EditorThemeData`:

- `editorScrollbarTrack`
- `editorScrollbarThumb`
- `editorScrollbarThumbHover`
- `editorScrollbarThumbActive`

Native Flutter scrollbars are disabled within the editor surface so only these
custom tracks are shown. Both tracks are confined to the editor text area; the
vertical track does not reserve a separate minimap column.
