# Video Recording

Capture browser automation sessions as video for debugging, documentation, or verification. Produces WebM (VP8/VP9 codec).

## Basic Recording

```bash
# Start recording
playwright-cli video-start

# Perform actions
playwright-cli open https://example.com
playwright-cli snapshot
playwright-cli click e1
playwright-cli fill e2 "test input"

# Stop and save
playwright-cli video-stop --filename=demo.webm
```

`video-stop` takes no positional argument; a bare path errors with `too many arguments`. Without `--filename`, the clip is saved as `.playwright-cli/video-<timestamp>.webm` under the working directory. With a named session, pass `-s=<name>` to both commands.

## Quality

The recorder runs at 25 fps (VP8, live encode capped near 1 Mbps). Under continuous animation it delivers 25 distinct frames per second; slower-changing pages show fewer distinct frames only because the page repaints less often. `video-start` takes no size and scales the viewport down to 800 px on its longest side, which blurs UI text. For legible text, record at viewport size from `run-code`:

```bash
playwright-cli run-code "async page => {
  await page.video().start({ size: page.viewportSize() });
  // ... actions ...
  await page.video().stop({ path: 'recordings/flow.webm' });
}"
```

## Best Practices

### 1. Use Descriptive Filenames

```bash
# Include context in filename
playwright-cli video-stop --filename=recordings/login-flow-2024-01-15.webm
playwright-cli video-stop --filename=recordings/checkout-test-run-42.webm
```

### 2. End on the proving state

Stop only after the state the clip is meant to show is on screen. Take a screenshot right before `video-stop` so there is an inspectable stand-in for the last frame.

## Tracing vs Video

| Feature | Video | Tracing |
|---------|-------|---------|
| Output | WebM file | Trace file (viewable in Trace Viewer) |
| Shows | Visual recording | DOM snapshots, network, console, actions |
| Use case | Demos, documentation | Debugging, analysis |
| Size | Larger | Smaller |

## Limitations

- Recording adds slight overhead to automation
- Large recordings can consume significant disk space
- GitHub plays `.webm` inline, so no conversion is needed.
- Recording at `deviceScaleFactor: 2` doesn't sharpen video: frames are captured in CSS pixels, and a larger `size` only adds gray padding.
