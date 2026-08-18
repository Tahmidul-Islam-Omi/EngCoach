# UI Designs

Figma exports for EngCoach. Screens here are **prototypes** — reviewed and discussed before implementation, not copied verbatim.

## Exporting from Figma

Export each frame as **PNG at 2x**. Skip Figma's Dev Mode code export — it produces absolutely-positioned widgets that don't adapt to screen size.

## Naming

Number files in flow order, prefixed by section:

```
docs/ui/
├── grammar/
│   ├── 01_topic_list.png
│   ├── 02_pre_assessment.png
│   ├── 03_lesson.png
│   └── 04_result.png
├── vocabulary/
│   └── 01_...
└── common/
    ├── 01_home.png
    └── 02_registration.png
```

## Design tokens

Fill this in from Figma's inspect panel — screenshots show layout but lose exact values.

```
Colors
  primary:            #
  secondary:          #
  background:         #
  surface / card:     #
  error:              #
  text primary:       #
  text secondary:     #

Typography
  English font:
  Bangla font:
  heading sizes:
  body size:
  caption size:
  weights used:

Spacing scale:        (e.g. 4 / 8 / 16 / 24)
Corner radius:        cards        buttons
```

## Notes per screen

Anything a screenshot can't convey — transitions, empty states, error states, what happens on tap — add here or alongside the image.
