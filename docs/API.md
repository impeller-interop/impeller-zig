# API

A quick reference for the Zig wrapper. The Zig source remains the source of truth.

## Contents

- [Rules](#rules)
  - [Handles](#handles)
  - [Bytes](#bytes)
  - [Draw state](#draw-state)
- [Raw C API](#raw-c-api)
- [Module layout](#module-layout)
- [Public types](#public-types)
  - [Error values](#error-values)
- [Value namespaces](#value-namespaces)
- [Top-level helpers](#top-level-helpers)
- [Types and methods](#types-and-methods)
  - [Mapping](#mapping)
  - [OwnedMapping](#ownedmapping)
  - [Context](#context)
  - [Surface](#surface)
  - [VulkanSwapchain](#vulkanswapchain)
  - [Paint](#paint)
  - [ColorFilter](#colorfilter)
  - [ColorSource](#colorsource)
  - [MaskFilter](#maskfilter)
  - [ImageFilter](#imagefilter)
  - [FragmentProgram](#fragmentprogram)
  - [Texture](#texture)
  - [Path](#path)
  - [PathBuilder](#pathbuilder)
  - [DisplayList](#displaylist)
  - [DisplayListBuilder](#displaylistbuilder)
  - [TypographyContext](#typographycontext)
  - [ParagraphStyle](#paragraphstyle)
  - [ParagraphBuilder](#paragraphbuilder)
  - [Paragraph](#paragraph)
  - [LineMetrics](#linemetrics)
  - [GlyphInfo](#glyphinfo)

## Rules

### Handles

Wrappers own one reference.

- Call `deinit()` exactly once per owner.
- Use `clone()` to create another owner.
- Assignment does not retain.

```zig
var paint = try impeller.Paint.init();
var other = paint.clone();

defer other.deinit();
defer paint.deinit();
```

Invalid:

```zig
var paint = try impeller.Paint.init();
var other = paint;

paint.deinit();
other.deinit(); // double release
```

### Bytes

| API family | Ownership |
| --- | --- |
| `initBorrowed`, `initWithBorrowedBytes`, `registerFontBorrowed` | Caller keeps bytes alive. |
| `initCopy`, `initWithBytesCopy`, `registerFontCopy` | Wrapper copies bytes and transfers cleanup to Impeller after success. |
| `Mapping.withRelease()` | Low-level callback-backed mapping. Prefer borrowed or copy APIs. |

Copy APIs require an allocator that remains valid until the release callback runs.

`OwnedMapping.releaseToImpeller()` must only be called after the receiving Impeller API succeeds.

The copy helpers assume this Impeller contract:

- success: Impeller accepts the mapping and later calls the release callback;
- failure: Impeller does not accept the mapping and does not call the release callback.

The public C header documents the callback baton and asynchronous release behavior, but not the full failure-path contract.

### Draw state

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

## Raw C API

Raw translated C bindings are available from the `impeller.c` namespace. This is not a
source file; it is the module produced from `impeller.h` during the build.

Prefer the Zig wrappers in the top-level `impeller` namespace for normal use. The raw namespace is an escape hatch for APIs that have not been wrapped yet or for integration code that already works in C terms.

## Module layout

| Module | Purpose |
| --- | --- |
| `impeller.geometry` | `Point`, `Rect`, `Matrix`, `RoundingRadii`, and geometry helpers. |
| `impeller.color` | `Color`, color spaces, and `srgb()`. |
| `impeller.context` | `Context` and graphics backend context creation. |
| `impeller.texture` | `Texture`, texture descriptors, pixel formats, and sampling. |
| `impeller.paint` | Paint state, blend modes, filters, color sources, and fragment programs. |
| `impeller.path` | `Path`, `PathBuilder`, and fill rules. |
| `impeller.display_list` | `DisplayList`, `DisplayListBuilder`, and clip operations. |
| `impeller.surface` | `Surface` and Vulkan swapchain wrappers. |
| `impeller.text` | Typography, paragraphs, glyph metrics, and text style values. |

The top-level `impeller` namespace re-exports the common names for concise call sites:

```zig
var paint = try impeller.Paint.init();
defer paint.deinit();

paint.setColor(impeller.srgb(1.0, 0.2, 0.1, 1.0));
```

## Public types

| Name | Kind | Purpose |
| --- | --- | --- |
| `Error` | error set | Wrapper errors returned by fallible constructors and operations. |
| `version` | constant | Header API version passed to context creation. |
| `version_variant` | constant | Packed version variant component. |
| `version_major` | constant | Packed version major component. |
| `version_minor` | constant | Packed version minor component. |
| `version_patch` | constant | Packed version patch component. |
| `ColorSpace` | enum | Color space identifiers. |
| `PixelFormat` | enum | Texture pixel format identifiers. |
| `TextureSampling` | enum | Texture sampling modes. |
| `FillType` | enum | Path fill rules. |
| `ClipOperation` | enum | Clip combination operations. |
| `BlendMode` | enum | Paint blending modes. |
| `DrawStyle` | enum | Paint fill/stroke mode. |
| `StrokeCap` | enum | Stroke endpoint style. |
| `StrokeJoin` | enum | Stroke join style. |
| `TileMode` | enum | Gradient/image tiling mode. |
| `BlurStyle` | enum | Mask blur style. |
| `FontWeight` | enum | Text font weight. |
| `FontStyle` | enum | Text font style. |
| `TextAlignment` | enum | Paragraph horizontal alignment. |
| `TextDirection` | enum | Text direction. |
| `TextDecorationType` | packed struct | Underline/overline/strike decoration flags. |
| `TextDecorationStyle` | enum | Decoration stroke style. |
| `Point` | extern struct | 2D point. |
| `Size` | extern struct | Floating-point size. |
| `ISize` | extern struct | Integer pixel size. |
| `Range` | extern struct | UTF-16 code unit range. |
| `Rect` | extern struct | Rectangle. |
| `Matrix` | extern struct | 4x4 transform matrix. |
| `ColorMatrix` | extern struct | 4x5 color matrix. |
| `RoundingRadii` | extern struct | Rounded rectangle corner radii. |
| `VulkanInfo` | extern struct | Vulkan handles owned by a context. |
| `VulkanSettings` | C struct | Vulkan context creation settings. |
| `TextDecoration` | extern struct | Text decoration parameters. |
| `Color` | extern struct | RGBA color with color space. |
| `TextureDescriptor` | extern struct | Texture format, size, and mip count. |
| `Callback` | callback | Generic Impeller callback. |
| `ProcAddressCallback` | callback | OpenGL procedure resolver. |
| `VulkanProcAddressCallback` | callback | Vulkan procedure resolver. |
| `ImageFilterHandle` | raw handle | Raw image filter handle for sampler arrays. |
| `TextureHandle` | raw handle | Raw texture handle for sampler arrays. |

### Error values

| Value | Purpose |
| --- | --- |
| `OutOfMemory` | Allocation failed. |
| `VersionMismatch` | Header version does not match linked runtime. |
| `CreateContextFailed` | Context creation failed. |
| `CreatePaintFailed` | Paint creation failed. |
| `CreateColorSourceFailed` | Color source creation failed. |
| `CreateColorFilterFailed` | Color filter creation failed. |
| `CreateMaskFilterFailed` | Mask filter creation failed. |
| `CreateImageFilterFailed` | Image filter creation failed. |
| `CreateTextureFailed` | Texture creation failed. |
| `CreateFragmentProgramFailed` | Fragment program creation failed. |
| `CreateDisplayListBuilderFailed` | Display list builder creation failed. |
| `CreateDisplayListFailed` | Display list creation failed. |
| `CreatePathBuilderFailed` | Path builder creation failed. |
| `CreatePathFailed` | Path creation failed. |
| `CreateTypographyContextFailed` | Typography context creation failed. |
| `RegisterFontFailed` | Font registration failed. |
| `CreateParagraphStyleFailed` | Paragraph style creation failed. |
| `CreateParagraphBuilderFailed` | Paragraph builder creation failed. |
| `CreateParagraphFailed` | Paragraph creation failed. |
| `CreateLineMetricsFailed` | Line metrics creation failed. |
| `CreateGlyphInfoFailed` | Glyph info creation failed. |
| `CreateVulkanSwapchainFailed` | Vulkan swapchain creation failed. |
| `AcquireSurfaceFailed` | Swapchain surface acquisition failed. |
| `DrawFailed` | Surface draw failed. |
| `PresentFailed` | Surface present failed. |

## Value namespaces

| Namespace | Type | Values |
| --- | --- | --- |
| `color_spaces` | `ColorSpace` | `srgb`, `extended_srgb`, `display_p3` |
| `pixel_formats` | `PixelFormat` | `rgba8888` |
| `texture_samplings` | `TextureSampling` | `nearest_neighbor`, `linear` |
| `fill_types` | `FillType` | `non_zero`, `odd` |
| `clip_operations` | `ClipOperation` | `difference`, `intersect` |
| `blend_modes` | `BlendMode` | `clear`, `source`, `destination`, `source_over`, `destination_over`, `source_in`, `destination_in`, `source_out`, `destination_out`, `source_atop`, `destination_atop`, `xor`, `plus`, `modulate`, `screen`, `overlay`, `darken`, `lighten`, `color_dodge`, `color_burn`, `hard_light`, `soft_light`, `difference`, `exclusion`, `multiply`, `hue`, `saturation`, `color`, `luminosity` |
| `draw_styles` | `DrawStyle` | `fill`, `stroke`, `stroke_and_fill` |
| `stroke_caps` | `StrokeCap` | `butt`, `round`, `square` |
| `stroke_joins` | `StrokeJoin` | `miter`, `round`, `bevel` |
| `tile_modes` | `TileMode` | `clamp`, `repeat`, `mirror`, `decal` |
| `blur_styles` | `BlurStyle` | `normal`, `solid`, `outer`, `inner` |
| `font_weights` | `FontWeight` | `thin`, `extra_light`, `light`, `normal`, `medium`, `semi_bold`, `bold`, `extra_bold`, `black`, `w100`, `w200`, `w300`, `w400`, `w500`, `w600`, `w700`, `w800`, `w900` |
| `font_styles` | `FontStyle` | `normal`, `italic` |
| `text_alignments` | `TextAlignment` | `left`, `right`, `center`, `justify`, `start`, `end` |
| `text_directions` | `TextDirection` | `rtl`, `ltr` |
| `text_decoration_types` | `TextDecorationType` | `none`, `underline`, `overline`, `line_through` |
| `text_decoration_styles` | `TextDecorationStyle` | `solid`, `double`, `dotted`, `dashed`, `wavy` |

## Top-level helpers

| API | Purpose |
| --- | --- |
| `srgb()` | Create an sRGB `Color`. |
| `runtimeVersion()` | Return the linked Impeller runtime version. |
| `makeVersion()` | Pack version components. |
| `versionVariant()` | Extract the variant component. |
| `versionMajor()` | Extract the major component. |
| `versionMinor()` | Extract the minor component. |
| `versionPatch()` | Extract the patch component. |
| `checkVersion()` | Check header/runtime version compatibility. |
| `rect()` | Create a `Rect`. |
| `point()` | Create a `Point`. |
| `uniformRadii()` | Create equal rounded-rectangle radii. |
| `colorMatrix()` | Create a `ColorMatrix`. |
| `pixelSize()` | Create an `ISize`. |
| `textureDescriptor()` | Create a `TextureDescriptor`. |

## Types and methods

### Mapping

| API | Purpose |
| --- | --- |
| `Mapping` | Non-owning or callback-backed byte mapping. |
| `borrowed()` | Borrow bytes. |
| `withRelease()` | Build a low-level callback-backed mapping. |

### OwnedMapping

| API | Purpose |
| --- | --- |
| `OwnedMapping` | Own copied mapping bytes until cleanup is transferred or deinitialized. |
| `copy()` | Copy bytes into allocator-backed storage. |
| `deinit()` | Release copied bytes when not transferred. |
| `releaseToImpeller()` | Transfer cleanup after a successful receiving API call. |

### Context

| API | Purpose |
| --- | --- |
| `Context` | Rendering context. |
| `initVulkan()` | Create a Vulkan context. |
| `initMetal()` | Create a Metal context. |
| `initOpenGLES()` | Create an OpenGL ES context. |
| `clone()` | Retain a context owner. |
| `deinit()` | Release a context owner. |
| `raw()` | Return the raw context handle. |
| `vulkanInfo()` | Read Vulkan handles from a Vulkan context. |

### Surface

| API | Purpose |
| --- | --- |
| `Surface` | Render target. |
| `wrapFBO()` | Wrap an OpenGL framebuffer object. |
| `wrapMetalDrawable()` | Wrap a Metal drawable. |
| `clone()` | Retain a surface owner. |
| `deinit()` | Release a surface owner. |
| `raw()` | Return the raw surface handle. |
| `draw()` | Draw a display list. |
| `present()` | Present the surface. |

### VulkanSwapchain

| API | Purpose |
| --- | --- |
| `VulkanSwapchain` | Vulkan swapchain wrapper. |
| `init()` | Create a Vulkan swapchain; transfers `VkSurfaceKHR` ownership. |
| `clone()` | Retain a swapchain owner. |
| `deinit()` | Release a swapchain owner. |
| `raw()` | Return the raw swapchain handle. |
| `acquireNextSurface()` | Acquire the next renderable surface. |

### Paint

| API | Purpose |
| --- | --- |
| `Paint` | Draw state used by display list commands. |
| `init()` | Create a paint with defaults. |
| `clone()` | Retain a paint owner. |
| `deinit()` | Release a paint owner. |
| `raw()` | Return the raw paint handle. |
| `setColor()` | Set solid color. |
| `setBlendMode()` | Set blend mode. |
| `setDrawStyle()` | Set fill/stroke mode. |
| `setStrokeCap()` | Set stroke cap. |
| `setStrokeJoin()` | Set stroke join. |
| `setStrokeWidth()` | Set stroke width. |
| `setStrokeMiter()` | Set stroke miter limit. |
| `setColorSource()` | Set shader/color source. |
| `setColorFilter()` | Set color filter. |
| `setMaskFilter()` | Set mask filter. |
| `setImageFilter()` | Set image filter. |

### ColorFilter

| API | Purpose |
| --- | --- |
| `ColorFilter` | Color transform applied during painting. |
| `initBlend()` | Create blend color filter. |
| `initColorMatrix()` | Create matrix color filter. |
| `clone()` | Retain a color filter owner. |
| `deinit()` | Release a color filter owner. |
| `raw()` | Return the raw color filter handle. |

### ColorSource

| API | Purpose |
| --- | --- |
| `ColorSource` | Shader/color source. |
| `initLinearGradient()` | Create linear gradient. |
| `initRadialGradient()` | Create radial gradient. |
| `initConicalGradient()` | Create conical gradient. |
| `initSweepGradient()` | Create sweep gradient. |
| `initImage()` | Create image-backed color source. |
| `initFragmentProgram()` | Create fragment-program color source from raw sampler/data pointers. |
| `initFragmentProgramSlices()` | Create fragment-program color source from Zig slices. |
| `clone()` | Retain a color source owner. |
| `deinit()` | Release a color source owner. |
| `raw()` | Return the raw color source handle. |

### MaskFilter

| API | Purpose |
| --- | --- |
| `MaskFilter` | Mask filter. |
| `initBlur()` | Create blur mask filter. |
| `clone()` | Retain a mask filter owner. |
| `deinit()` | Release a mask filter owner. |
| `raw()` | Return the raw mask filter handle. |

### ImageFilter

| API | Purpose |
| --- | --- |
| `ImageFilter` | Image filter. |
| `initBlur()` | Create blur image filter. |
| `initDilate()` | Create dilate image filter. |
| `initErode()` | Create erode image filter. |
| `initMatrix()` | Create matrix image filter. |
| `initFragmentProgram()` | Create fragment-program image filter from raw sampler/data pointers. |
| `initFragmentProgramSlices()` | Create fragment-program image filter from Zig slices. |
| `initCompose()` | Compose image filters. |
| `clone()` | Retain an image filter owner. |
| `deinit()` | Release an image filter owner. |
| `raw()` | Return the raw image filter handle. |

### FragmentProgram

| API | Purpose |
| --- | --- |
| `FragmentProgram` | Compiled `impellerc` fragment program. |
| `initMapping()` | Create from caller-managed mapping. |
| `initBorrowed()` | Create from borrowed compiled bytes. |
| `initCopy()` | Create from copied compiled bytes. |
| `clone()` | Retain a fragment program owner. |
| `deinit()` | Release a fragment program owner. |
| `raw()` | Return the raw fragment program handle. |

### Texture

| API | Purpose |
| --- | --- |
| `Texture` | GPU texture. |
| `initWithMapping()` | Create from caller-managed pixel mapping. |
| `initWithBorrowedBytes()` | Create from borrowed tightly packed, decompressed bytes. |
| `initWithBytesCopy()` | Create from copied tightly packed, decompressed bytes. |
| `initWithOpenGLTextureHandle()` | Adopt an existing OpenGL texture handle. |
| `clone()` | Retain a texture owner. |
| `deinit()` | Release a texture owner. |
| `raw()` | Return the raw texture handle. |
| `getOpenGLHandle()` | Return the backing OpenGL texture name when available. |

### Path

| API | Purpose |
| --- | --- |
| `Path` | Immutable path. |
| `clone()` | Retain a path owner. |
| `deinit()` | Release a path owner. |
| `getBounds()` | Return conservative bounds. |
| `raw()` | Return the raw path handle. |

### PathBuilder

| API | Purpose |
| --- | --- |
| `PathBuilder` | Mutable path builder. |
| `init()` | Create a path builder. |
| `clone()` | Retain a path builder owner. |
| `deinit()` | Release a path builder owner. |
| `raw()` | Return the raw path builder handle. |
| `moveTo()` | Move current point. |
| `lineTo()` | Add line segment. |
| `quadraticCurveTo()` | Add quadratic curve. |
| `cubicCurveTo()` | Add cubic curve. |
| `addRect()` | Add rectangle. |
| `addArc()` | Add arc. |
| `addOval()` | Add oval. |
| `addRoundedRect()` | Add rounded rectangle. |
| `close()` | Close current contour. |
| `copyPath()` | Copy path without resetting builder. |
| `takePath()` | Take path and reset builder. |

### DisplayList

| API | Purpose |
| --- | --- |
| `DisplayList` | Immutable drawing command list. |
| `clone()` | Retain a display list owner. |
| `deinit()` | Release a display list owner. |
| `raw()` | Return the raw display list handle. |

### DisplayListBuilder

| API | Purpose |
| --- | --- |
| `DisplayListBuilder` | Mutable display list builder. |
| `init()` | Create builder with optional cull rect. |
| `clone()` | Retain a builder owner. |
| `deinit()` | Release a builder owner. |
| `raw()` | Return the raw builder handle. |
| `build()` | Build display list and reset builder. |
| `drawLine()` | Draw line. |
| `drawDashedLine()` | Draw dashed line. |
| `drawRect()` | Draw rectangle. |
| `drawOval()` | Draw oval. |
| `drawRoundedRect()` | Draw rounded rectangle. |
| `drawRoundedRectDifference()` | Draw rounded-rectangle difference. |
| `drawPath()` | Draw path. |
| `drawShadow()` | Draw material shadow. |
| `drawDisplayList()` | Flatten child display list. |
| `drawTexture()` | Draw texture at point. |
| `drawTextureRect()` | Draw texture rectangle. |
| `drawPaint()` | Fill current clip with paint. |
| `drawParagraph()` | Draw laid-out paragraph. |
| `save()` | Save clip/transform state. |
| `saveLayer()` | Save layer with optional paint/backdrop. |
| `getSaveCount()` | Return save stack depth. |
| `restoreToCount()` | Restore to save count. |
| `restore()` | Restore last save. |
| `clipRect()` | Clip to rectangle. |
| `clipOval()` | Clip to oval. |
| `clipRoundedRect()` | Clip to rounded rectangle. |
| `clipPath()` | Clip to path. |
| `scale()` | Apply scale transform. |
| `rotate()` | Apply rotation transform. |
| `translate()` | Apply translation transform. |
| `transform()` | Append transform. |
| `setTransform()` | Replace transform. |
| `getTransform()` | Return current transform. |
| `resetTransform()` | Reset transform to identity. |

### TypographyContext

| API | Purpose |
| --- | --- |
| `TypographyContext` | Font and text layout context. |
| `init()` | Create typography context. |
| `clone()` | Retain typography context owner. |
| `deinit()` | Release typography context owner. |
| `raw()` | Return raw typography context handle. |
| `registerFontMapping()` | Register font from caller-managed mapping. |
| `registerFontMappingPtr()` | Register font from caller-managed mapping with a C string alias pointer. |
| `registerFontBorrowed()` | Register font from borrowed bytes. |
| `registerFontBorrowedPtr()` | Register font from borrowed bytes with a C string alias pointer. |
| `registerFontCopy()` | Register font from copied bytes. |
| `registerFontCopyPtr()` | Register font from copied bytes with a C string alias pointer. |

### ParagraphStyle

| API | Purpose |
| --- | --- |
| `ParagraphStyle` | Paragraph style. |
| `init()` | Create paragraph style. |
| `clone()` | Retain paragraph style owner. |
| `deinit()` | Release paragraph style owner. |
| `raw()` | Return raw paragraph style handle. |
| `setForeground()` | Set glyph foreground paint. |
| `setBackground()` | Set glyph background paint. |
| `setFontWeight()` | Set font weight. |
| `setFontStyle()` | Set font style. |
| `setFontFamily()` | Set font family. |
| `setFontFamilyPtr()` | Set font family from a C string pointer. |
| `setFontSize()` | Set font size. |
| `setHeight()` | Set line height multiplier. |
| `setTextAlignment()` | Set horizontal alignment. |
| `setTextDirection()` | Set text direction. |
| `setTextDecoration()` | Set decoration. |
| `setMaxLines()` | Set max visible lines. |
| `setLocale()` | Set locale. |
| `setLocalePtr()` | Set locale from a C string pointer. |
| `setEllipsis()` | Set truncation ellipsis. |
| `setEllipsisPtr()` | Set truncation ellipsis from a C string pointer. |

### ParagraphBuilder

| API | Purpose |
| --- | --- |
| `ParagraphBuilder` | Paragraph builder. |
| `init()` | Create builder from typography context. |
| `clone()` | Retain paragraph builder owner. |
| `deinit()` | Release paragraph builder owner. |
| `raw()` | Return raw paragraph builder handle. |
| `pushStyle()` | Push style. |
| `popStyle()` | Pop style. |
| `addText()` | Add UTF-8 text. |
| `build()` | Layout text and return paragraph. |

### Paragraph

| API | Purpose |
| --- | --- |
| `Paragraph` | Immutable laid-out paragraph. |
| `clone()` | Retain paragraph owner. |
| `deinit()` | Release paragraph owner. |
| `raw()` | Return raw paragraph handle. |
| `getMaxWidth()` | Return layout width. |
| `getHeight()` | Return paragraph height. |
| `getLongestLineWidth()` | Return longest visible line width. |
| `getMinIntrinsicWidth()` | Return min intrinsic width. |
| `getMaxIntrinsicWidth()` | Return max intrinsic width. |
| `getIdeographicBaseline()` | Return ideographic baseline. |
| `getAlphabeticBaseline()` | Return alphabetic baseline. |
| `getLineCount()` | Return visible line count. |
| `getWordBoundary()` | Return word UTF-16 range. |
| `getLineMetrics()` | Return line metrics. |
| `createGlyphInfoAtCodeUnitIndex()` | Return glyph info near UTF-16 index. |
| `createGlyphInfoAtParagraphCoordinates()` | Return glyph info near coordinates. |

### LineMetrics

| API | Purpose |
| --- | --- |
| `LineMetrics` | Per-line paragraph metrics. |
| `clone()` | Retain line metrics owner. |
| `deinit()` | Release line metrics owner. |
| `raw()` | Return raw line metrics handle. |
| `getUnscaledAscent()` | Return unscaled ascent. |
| `getAscent()` | Return ascent. |
| `getDescent()` | Return descent. |
| `getBaseline()` | Return baseline. |
| `isHardbreak()` | Return hard-break flag. |
| `getWidth()` | Return line width. |
| `getHeight()` | Return line height. |
| `getLeft()` | Return left x coordinate. |
| `getCodeUnitStartIndex()` | Return UTF-16 start index. |
| `getCodeUnitEndIndex()` | Return UTF-16 end index. |
| `getCodeUnitEndIndexExcludingWhitespace()` | Return end index excluding trailing whitespace. |
| `getCodeUnitEndIndexIncludingNewline()` | Return end index including newline. |

### GlyphInfo

| API | Purpose |
| --- | --- |
| `GlyphInfo` | Glyph and grapheme cluster info. |
| `clone()` | Retain glyph info owner. |
| `deinit()` | Release glyph info owner. |
| `raw()` | Return raw glyph info handle. |
| `getGraphemeClusterCodeUnitRangeBegin()` | Return grapheme cluster start index. |
| `getGraphemeClusterCodeUnitRangeEnd()` | Return grapheme cluster end index. |
| `getGraphemeClusterBounds()` | Return grapheme cluster bounds. |
| `isEllipsis()` | Return ellipsis flag. |
| `getTextDirection()` | Return run text direction. |
