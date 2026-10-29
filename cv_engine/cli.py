#!/usr/bin/env python3
"""
Interactive / CLI test script for ShopGenie Computer Vision Engine.
Usage:
    python3 cv_engine/cv_engine.py [--image path/to/image.jpg] [--esp32-url http://192.168.1.100:81/stream]
"""

import sys
import os
import argparse
import numpy as np

# Ensure cv_engine can be imported
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from cv_engine.cv_engine import (
    get_cv_engine,
    cosine_similarity,
    extract_features,
    detect_loose_or_plain_bag,
    capture_frame_from_esp32_stream
)


def run_standalone_demo():
    print("=" * 70)
    print(" ShopGenie Computer Vision Engine (MobileNetV3 + OpenCV)")
    print("=" * 70)

    engine = get_cv_engine()
    print(f"[*] Engine loaded on device: {engine.device}")
    print(f"[*] Fixed Embedding Dimension: {engine.embedding_dim}")

    # Generate synthetic image samples for testing
    import cv2
    # Sample A: High contrast branded pattern (e.g. bold cereal box packaging)
    branded_img = np.zeros((256, 256, 3), dtype=np.uint8)
    cv2.rectangle(branded_img, (20, 20), (236, 236), (0, 0, 255), -1)
    cv2.putText(branded_img, "TATA TEA", (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 3)
    cv2.putText(branded_img, "PREMIUM", (35, 140), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)
    cv2.rectangle(branded_img, (40, 170), (210, 220), (0, 255, 0), -1)

    # Sample B: Plain white / translucent polythene loose bag with diffuse grains
    loose_img = np.full((256, 256, 3), 225, dtype=np.uint8)
    noise = np.random.normal(0, 4, loose_img.shape).astype(np.int16)
    loose_img = np.clip(loose_img.astype(np.int16) + noise, 0, 255).astype(np.uint8)

    _, branded_bytes = cv2.imencode('.jpg', branded_img)
    _, loose_bytes = cv2.imencode('.jpg', loose_img)

    # 1. Feature extraction
    emb_branded = engine.extract_embedding(branded_bytes.tobytes())
    emb_loose = engine.extract_embedding(loose_bytes.tobytes())
    norm_branded = float(np.linalg.norm(emb_branded))
    norm_loose = float(np.linalg.norm(emb_loose))

    print(f"[1] Branded Image Embedding Length: {len(emb_branded)} (L2 Norm: {norm_branded:.6f})")
    print(f"[2] Loose Image Embedding Length:   {len(emb_loose)} (L2 Norm: {norm_loose:.6f})")

    # 2. Plain bag / loose candidate detection
    is_loose_a = engine.detect_loose_candidate(branded_bytes.tobytes())
    is_loose_b = engine.detect_loose_candidate(loose_bytes.tobytes())
    print(f"[3] Branded Packaging Loose Detected: {is_loose_a} (Expected: False)")
    print(f"[4] Plain Bag Loose Detected:         {is_loose_b} (Expected: True)")

    # 3. Cosine similarity
    sim_self = cosine_similarity(emb_branded, emb_branded)
    sim_diff = cosine_similarity(emb_branded, emb_loose)
    print(f"[5] Self Cosine Similarity (Identical): {sim_self:.4f} (Expected: 1.0000)")
    print(f"[6] Cross Cosine Similarity (Different): {sim_diff:.4f} (Expected: low/moderate)")
    print("=" * 70)
    print(" CV Engine Standalone Demo Completed Successfully.")
    print("=" * 70)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ShopGenie CV Engine CLI")
    parser.add_argument("--image", type=str, help="Path to an image to embed and classify")
    parser.add_argument("--esp32-url", type=str, help="ESP32-CAM stream URL to capture from")
    args = parser.parse_args()

    if args.image:
        engine = get_cv_engine()
        with open(args.image, 'rb') as f:
            data = f.read()
        emb = engine.extract_embedding(data)
        is_loose = engine.detect_loose_candidate(data)
        print(f"Image: {args.image}")
        print(f"Embedding length: {len(emb) if emb else None}")
        print(f"Is loose candidate: {is_loose}")
    elif args.esp32_url:
        engine = get_cv_engine()
        frame, err = engine.capture_frame_from_esp32_stream(args.esp32_url)
        if err:
            print(f"Error capturing from ESP32: {err}")
        else:
            print(f"Successfully captured frame: {len(frame)} bytes")
    else:
        run_standalone_demo()
