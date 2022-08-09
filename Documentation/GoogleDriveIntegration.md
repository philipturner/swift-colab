# Google Drive Integration

> This documentation page is a work in progress.

Easiest to do this before executing install script

Why this doesn't work in Swift - summarize the threads talking about this issue, link to them

- https://github.com/google/swift-jupyter/issues/100
- https://forums.fast.ai/t/python-textfield-output-not-working/51000/14

```swift
from google.colab import drive
drive.mount("/content")
```

> This Python code renders with Swift syntax coloring. This is awkward, but it's how the code will appear in the Google Colab IDE.

TODO: Change ColabSupportHistory link to direct here

TODO: Warn to not connect a Google Drive containing sensitive or important data. Your data could be deleted permanently.

TODO: How to make a scratch Google Drive that caches build products between tutorials.

UPDATE: You no longer need Python mode to mount a Google Drive.