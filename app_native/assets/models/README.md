Place the offline face embedding model here.

Expected default path:

```text
assets/models/face_embedding.tflite
```

Recommended model contract:

```text
Input:  112 x 112 face crop, RGB, normalized to [-1, 1]
Output: 512-dimensional embedding
```

The app can also handle TFLite input layouts shaped like `1x112x112x3`
or `1x3x112x112`. After changing model families, re-enroll all faces.

Required liveness model:

```text
assets/models/minifasnet.tflite
assets/models/minifasnet_contract.json
```

Use a Silent-Face-Anti-Spoofing MiniFASNet TFLite model whose output class
index matches `minifasnet_contract.json`. Attendance is blocked when the model
or contract is missing/invalid because anti-spoofing must also work offline.

Default contract:

```json
{
  "outputLength": 2,
  "classOrder": ["spoof", "real"],
  "realClassIndex": 1,
  "threshold": 0.8
}
```

If your model outputs `[real, spoof]`, change `realClassIndex` to `0`.
