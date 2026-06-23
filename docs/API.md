# API

## Handles

Wrappers own one reference.

- Call `deinit()` exactly once per owner.
- Use `clone()` to create another owner.
- Do not use assignment to clone ownership.

```zig
var paint = try impeller.Paint.init();
var other = paint.clone();

defer other.deinit();
defer paint.deinit();
```

This is invalid:

```zig
var paint = try impeller.Paint.init();
var other = paint;

paint.deinit();
other.deinit(); // double release
```

## Bytes

Borrowed APIs never take ownership.

| API | Bytes |
| --- | --- |
| `FragmentProgram.initBorrowed()` | Borrowed |
| `Texture.initWithBorrowedBytes()` | Borrowed |
| `TypographyContext.registerFontBorrowed()` | Borrowed |

Copy APIs allocate a mapping and transfer cleanup to Impeller after success.

| API | Bytes |
| --- | --- |
| `FragmentProgram.initCopy()` | Copied |
| `Texture.initWithBytesCopy()` | Copied |
| `TypographyContext.registerFontCopy()` | Copied |

Rules:

- Borrowed bytes must outlive Impeller's use of them.
- Copy APIs require an allocator that remains valid until the release callback runs.
- `Mapping.withRelease()` is low-level. Prefer `Mapping.borrowed()` or `OwnedMapping.copy()`.
- Call `OwnedMapping.releaseToImpeller()` only after the receiving Impeller API succeeds.

The copy helpers assume this Impeller contract:

- success: Impeller accepts the mapping and later calls the release callback;
- failure: Impeller does not accept the mapping and does not call the release callback.

The public C header documents the callback baton and asynchronous release behavior, but not the full failure-path contract.

## Draw state

These APIs keep the state required after the call returns:

- `Paint.setColorSource()`
- `Paint.setColorFilter()`
- `Paint.setMaskFilter()`
- `Paint.setImageFilter()`
- `DisplayListBuilder.drawPath()`
- `DisplayListBuilder.drawDisplayList()`
- `ParagraphStyle.setForeground()`
- `ParagraphStyle.setBackground()`

The unit tests cover build-time lifetime behavior. Texture draws still need a real Context/Surface render test.
