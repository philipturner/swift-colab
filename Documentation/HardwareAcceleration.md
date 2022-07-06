# Hardware Acceleration

> This documentation page is a work in progress.

Connecting to accelerators does not actually erase the runtime - look at `Runtime > Manage sessions`.

S4TF SwiftPM test suite in Python mode notebook:
- CPU: 19 seconds -> ??? seconds with new test suite
- GPU: 46 seconds
- TPU: 20 seconds (likely that every op just went on CPU)
