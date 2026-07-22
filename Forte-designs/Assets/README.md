# Asset naming

Icon filenames begin with the visual family they belong to:

- `review-icon-*`: 3D illustration inside a solid rounded-rectangle tile. Reserve this family for review and readback screens.
- `plinth-icon-*`: isolated 3D illustration presented on the small marble plinth, with no background tile.
- `object-icon-*`: freestanding 3D illustration with neither a background tile nor the standard marble plinth.
- `chroma-plinth-icon-*`: legacy plinth illustration whose source PNG still contains a visible chroma-key background. Clean the transparency before promoting it to `plinth-icon-*`.

Non-icon artwork keeps a descriptive type prefix, such as `illustration-*`.
