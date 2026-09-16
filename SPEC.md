# Calendar widget specification

The goal of this specification is to develop a self-contained widget
that can display calendar events in one of three different layouts:

1. Single column layout: Here the events of a single day are displayed.
2. 5 column layout: Here the events of the weekdays Monday to Friday are shown.
3. 7 column layout: Here the events of the entire week are shown.

## Design

The design should display events as boxes that are overlayed to the respective column.
Each column should be separated into cells of a configurable time increment, i.e. 1h, 30min, 15min.
Left of each cell, the start time of the cell should be displayed. The widget should try to fill all
available space.

### Events

Events should be drawn as boxes with rounded corners in a solid color. The left border should be a 4px wide
border of the event's color, only lighter. In the box's top-left corner the event name should be displayed.

The boxes should be laid out according to their actual time, i.e. for an event that is not multi-day, the box's top
edge should correspond to the cell that matches it's start time and the bottom edge should match the end time.

For multi-day events, the box should wrap around into the next column.

If an event is an all-day event, then it should be placed as a small box below the day numbers in the header bar
and span all columns that are relevant. In this case, no time is needed and the box should only contain the even name.

Each event box should show the timezone in parentheses if the event's timezone differs from the user's timezone.

The color of the event should be configurable from within the DTO.

Every event should be clickable, causing a callback to be called with the clicked event as input. This should be accomplished
using an InkSplash or similar.

### Body

Across all columns, there should be a line that indicates the current time.

The user should be able to drag across one or multiple rows, where there is not an event yet, to create an event. This
should be accomplished such that the user is shown a preview of the event and a callback that is called when the user
has stopped dragging. This transient event should not disappear until the callback is done. The callback should be async,
take in the start and end date, and let the user themselves add the event to the event list.

If the user double-clicks a cell, the creation callback should be called as well, with the start and end dates
defined by the cell's start and end time. The same transient behaviour should apply here as well.

### Header

The current day should be highlighted in the header.

Similarly to the drag functionality in the body, this should also be possible in the header for multi-day all-day events.
For this case, the DTO passed to the callback should include a parameter that indicates whether the event is all-day event
(like here) or not (in the body case).

Similarly to the body, if the user double-clicks a day in the header (similar to dragging), the creation callback should
be called. Same behaviour as with body.

## Tests

The widget code should be covered by tests!