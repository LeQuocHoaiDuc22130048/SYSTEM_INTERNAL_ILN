"""Convert a trained TensorFlow ArcFace model to Flutter's TFLite asset.

Usage:
  python tools/convert_arcface_to_tflite.py --saved-model path/to/saved_model
  python tools/convert_arcface_to_tflite.py --keras-model path/to/model.keras

The model must be a trained embedding model, not the ArcFace training head.
Expected inference contract:
  input:  float32 RGB face crop, shape [1, 112, 112, 3] or [1, 3, 112, 112]
  output: 512-D embedding, usually shape [1, 512]
"""

from __future__ import annotations

import argparse
from pathlib import Path

import tensorflow as tf


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--saved-model", type=Path)
    source.add_argument("--keras-model", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("assets/models/arcface.tflite"),
    )
    parser.add_argument(
        "--float16",
        action="store_true",
        help="Use float16 weight quantization to reduce model size.",
    )
    return parser.parse_args()


def converter_from_args(args: argparse.Namespace) -> tf.lite.TFLiteConverter:
    if args.saved_model is not None:
        return tf.lite.TFLiteConverter.from_saved_model(str(args.saved_model))

    model = tf.keras.models.load_model(str(args.keras_model), compile=False)
    return tf.lite.TFLiteConverter.from_keras_model(model)


def main() -> None:
    args = parse_args()
    converter = converter_from_args(args)
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]

    if args.float16:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(tflite_model)
    print(f"Wrote {args.output} ({len(tflite_model):,} bytes)")


if __name__ == "__main__":
    main()
