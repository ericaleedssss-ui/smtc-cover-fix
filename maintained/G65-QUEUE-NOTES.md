# G65 playback queue

G64's queue Loader was inside `baseVisual`. Its local z=245 could not cross
that ancestor, so Main.qml's later full-page inputLayer took mouse events.
Move the Loader to the window's root input stack, retaining glass background
sampling from baseVisual. The local Qt 6.12 test reproduces the old interception
and verifies the corrected stack using actual window mouse events.

Queue rows include bounded cover URLs, duration and provenance. Known directory
origins are captured when creating a queue; unknown origins show the actual
provider rather than guessing a playlist. Cover/title clicks play; hover exposes
collection and removal. The list layer applies the existing blur/fade shader,
with fades active only where content continues above/below. WheelHandler keeps
wheel and touchpad deltas in the list, away from the page input surface.

Collection reuses the existing playlist picker, authenticated mutation flow,
validation and API route. Row/all selection is captured independently from
music.current and protected by account generation. NetEase bulk collection uses
one deduplicated mutation; failure leaves the picker open. Current playback is
retained by clear-upcoming and protected from single-row removal, as before.

## Verification

- `python scripts/test-g65-queue.py /path/to/applied/upstream`: actual QML
  mouse/hover/wheel events at 720p/1080p scale, first/second/final pages,
  metadata refresh preserving scroll, dark/empty/FM states. This is an action
  spy, not a live NetEase server or compiled C++ test.
- Qt 6.12 qmlcachegen compilation and existing fade shader qsb compilation.
- Clean G53 -> G65 application, repository boundary and Qt project checks.
- Added compiled Windows UI checks: real-window click -> current track/index,
  actual queue removal/clear, playlist fixture writes of selected/all IDs,
  rejected writes, stale indices, source navigation, close and paging.
  These run in GitHub Actions; Windows and authenticated service behavior
  require that build and subsequent real-device validation.

The retained G64 QML snapshot is only used while earlier versioned patch
assertions execute. G65 replaces it with the current maintained component.
