Place the offline ArcFace embedding model here.

Expected default path:

```text
assets/models/arcface.tflite
```

Recommended model contract:

```text
Input:  112 x 112 face crop, RGB, normalized to [-1, 1]
Output: 512-dimensional embedding
```

The app can also handle TFLite input layouts shaped like `1x112x112x3`
or `1x3x112x112`. After changing model families, re-enroll all faces.
