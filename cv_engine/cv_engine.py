"""
ShopGenie Phase 2: Computer Vision Engine
==========================================
Architecture:
- Feature Extractor: PyTorch MobileNetV3 (Small, 576-dimensional embedding)
- Normalization: L2-normalized feature vectors for exact cosine similarity dot products
- Similarity Matching: Cosine similarity computation between query vector and catalog database
- Visual Inspector: OpenCV (cv2) based color, edge, and texture entropy inspection for plain-bag/loose commodities
- Video Stream Grabber: ESP32-CAM MJPEG stream & snapshot buffer extractor using socket/HTTP streaming
"""

import io
import os
import sys
import logging
from typing import Tuple, Optional, List, Dict, Any, Union
import numpy as np
import cv2
import torch
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image
import requests

logger = logging.getLogger('shopgenie.cv_engine')
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(name)s: %(message)s')

# Fixed embedding dimension for MobileNetV3-Small feature representation
MOBILENET_V3_SMALL_EMBEDDING_DIM = 576


def cosine_similarity(vec_a: Union[List[float], np.ndarray], vec_b: Union[List[float], np.ndarray]) -> float:
    """
    Computes cosine similarity between two feature vectors.
    Since vectors produced by CVEngine are strictly L2-normalized:
    similarity = dot(vec_a, vec_b)
    """
    if vec_a is None or vec_b is None:
        return 0.0
    a = np.asarray(vec_a, dtype=np.float32)
    b = np.asarray(vec_b, dtype=np.float32)
    if a.shape != b.shape or a.size == 0 or b.size == 0:
        return 0.0

    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0

    dot = float(np.dot(a, b))
    sim = dot / (norm_a * norm_b)
    # Clip to valid cosine range [-1.0, 1.0] to handle tiny floating point inaccuracies
    return float(np.clip(sim, -1.0, 1.0))


class CVEngine:
    """
    Production Computer Vision Engine for ShopGenie retail checkout and stock enrollment.
    Extracts L2-normalized visual embeddings using MobileNetV3 and detects plain transparent/loose bags.
    """

    def __init__(self, use_pretrained: bool = True, device: Optional[str] = None):
        self.device = torch.device(device if device else ("cuda" if torch.cuda.is_available() else "cpu"))
        logger.info(f"Initializing CVEngine on device: {self.device}")

        # 1. Load MobileNetV3 model
        if use_pretrained:
            weights = models.MobileNet_V3_Small_Weights.DEFAULT
            self.model = models.mobilenet_v3_small(weights=weights)
        else:
            self.model = models.mobilenet_v3_small(weights=None)

        # 2. Configure model to output the 576-dimensional pooled feature vector
        # The classifier of MobileNetV3-Small is:
        # Sequential(
        #   (0): Linear(in_features=576, out_features=1024, bias=True)
        #   (1): Hardswish()
        #   (2): Dropout(...)
        #   (3): Linear(in_features=1024, out_features=1000)
        # )
        # By replacing classifier with Identity(), we obtain the pooled 576-dim feature representation.
        self.model.classifier = torch.nn.Identity()
        self.model.eval()
        self.model.to(self.device)

        # 3. Standard PyTorch ImageNet input transformation pipeline
        self.transform = transforms.Compose([
            transforms.Resize((224, 224), interpolation=transforms.InterpolationMode.BILINEAR),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406],
                std=[0.229, 0.224, 0.225]
            )
        ])

        self.embedding_dim = MOBILENET_V3_SMALL_EMBEDDING_DIM
        logger.info(f"CVEngine initialized successfully. Fixed Embedding Dim: {self.embedding_dim}")

    def decode_image_bytes(self, image_bytes: bytes) -> Optional[np.ndarray]:
        """
        Safely decodes raw image bytes into an OpenCV BGR numpy array.
        """
        if not image_bytes or len(image_bytes) < 10:
            return None
        np_arr = np.frombuffer(image_bytes, np.uint8)
        img_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        return img_bgr

    def extract_embedding(self, image_input: Union[bytes, np.ndarray, Image.Image]) -> Optional[List[float]]:
        """
        Extracts an L2-normalized 576-dimensional embedding vector for an input image.
        Accepts:
        - raw image bytes (JPEG / PNG / WebP)
        - OpenCV numpy ndarray (BGR or RGB)
        - PIL Image
        """
        try:
            if isinstance(image_input, bytes):
                pil_img = Image.open(io.BytesIO(image_input)).convert('RGB')
            elif isinstance(image_input, np.ndarray):
                # Check channel count and convert BGR (cv2 default) to RGB
                if len(image_input.shape) == 2:
                    rgb = cv2.cvtColor(image_input, cv2.COLOR_GRAY2RGB)
                elif image_input.shape[2] == 4:
                    rgb = cv2.cvtColor(image_input, cv2.COLOR_BGRA2RGB)
                else:
                    rgb = cv2.cvtColor(image_input, cv2.COLOR_BGR2RGB)
                pil_img = Image.fromarray(rgb)
            elif isinstance(image_input, Image.Image):
                pil_img = image_input.convert('RGB')
            else:
                logger.error(f"Unsupported image input type: {type(image_input)}")
                return None

            tensor = self.transform(pil_img).unsqueeze(0).to(self.device)

            with torch.no_grad():
                raw_features = self.model(tensor)  # Shape: [1, 576]
                # Apply L2 normalization across the embedding vector
                l2_norm = torch.norm(raw_features, p=2, dim=1, keepdim=True)
                # Avoid division by zero
                normalized_features = raw_features / (l2_norm + 1e-12)

            embedding = normalized_features.squeeze(0).cpu().numpy().tolist()
            return [float(x) for x in embedding]

        except Exception as e:
            logger.error(f"Error extracting embedding: {e}")
            return None

    def detect_loose_candidate(self, image_input: Union[bytes, np.ndarray]) -> bool:
        """
        Computer Vision heuristics to identify loose, unbranded commodities in plain plastic bags.
        
        Kirana Store Characteristics:
        1. Loose commodities (Rice, Sugar, Dal, Atta, Salt) are packaged in clear, transparent,
           or semi-translucent polythene bags without high-contrast branded typography, bold logos,
           or multicolored packaging graphics.
        2. Color saturation distribution: Plain polythene bags have low color variance or uniform
           monochromatic grain compared to vivid commercial consumer goods packaging (e.g., Maggi, Lay's).
        3. Edge Density & Texture Entropy:
           - Branded items feature dense, sharp text and barcode edges (high Canny edge density).
           - Loose grains/powders have low edge gradient entropy or diffuse, repetitive textures.
        """
        try:
            if isinstance(image_input, bytes):
                img_bgr = self.decode_image_bytes(image_input)
            elif isinstance(image_input, np.ndarray):
                img_bgr = image_input
            else:
                return False

            if img_bgr is None or img_bgr.size == 0:
                return False

            # Resize to standard analysis size for consistent threshold evaluation
            analysis_img = cv2.resize(img_bgr, (256, 256))

            # 1. Convert to HSV to analyze color saturation and vibrancy
            hsv = cv2.cvtColor(analysis_img, cv2.COLOR_BGR2HSV)
            sat = hsv[:, :, 1]
            mean_sat = float(np.mean(sat))
            std_sat = float(np.std(sat))

            # 2. Convert to Grayscale for Edge and Contour Analysis
            gray = cv2.cvtColor(analysis_img, cv2.COLOR_BGR2GRAY)

            # Canny edge detection for high-contrast logo / packaging lines
            edges = cv2.Canny(gray, 60, 160)
            edge_density = float(np.count_nonzero(edges)) / float(edges.size)

            # Laplacian variance (sharpness / textual contrast metric)
            laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())

            # 3. Transparent / White polythene brightness distribution
            val = hsv[:, :, 2]
            high_brightness_ratio = float(np.count_nonzero(val > 180)) / float(val.size)

            # Kirana loose plastic bag characteristics:
            # - Very low color saturation (mean saturation < 65, std < 50) because bags of sugar/salt/dal/rice
            #   are mostly white/translucent plastic or dull monochrome grains.
            # - Low textual sharpness (Laplacian variance < 400), unlike crisp printed branded packaging.
            # - Very low edge density (edge_density < 0.035).
            is_low_edge = edge_density < 0.035
            is_low_contrast = laplacian_var < 400.0
            is_plain_monochrome = mean_sat < 65.0 and std_sat < 50.0

            # Loose commodity decision: Must be low contrast or monochromatic without rich commercial packaging saturation
            if is_plain_monochrome and (is_low_edge or is_low_contrast):
                return True

            if is_low_edge and is_low_contrast and mean_sat < 100.0:
                return True

            return False

        except Exception as e:
            logger.warning(f"Failed loose candidate visual heuristic: {e}")
            return False

    def match_branded_product(
        self,
        query_embedding: List[float],
        catalog_items: List[Dict[str, Any]],
        similarity_threshold: float = 0.78
    ) -> Tuple[Optional[Dict[str, Any]], float]:
        """
        Finds the closest matching product in the shopkeeper's registered catalog using cosine similarity.
        
        Parameters:
        - query_embedding: L2-normalized 576-dim vector of the query frame
        - catalog_items: List of dicts, each with 'id', 'name', 'feature_vector', etc.
        - similarity_threshold: Minimum cosine similarity required to confirm a match
        
        Returns:
        - (best_match_item, best_similarity_score)
        """
        if not query_embedding or not catalog_items:
            return None, 0.0

        best_item = None
        best_sim = -1.0

        for item in catalog_items:
            feat = item.get('feature_vector')
            if not feat:
                continue

            sim = cosine_similarity(query_embedding, feat)
            if sim > best_sim:
                best_sim = sim
                best_item = item

        if best_item and best_sim >= similarity_threshold:
            return best_item, best_sim

        return None, max(0.0, best_sim)

    def capture_frame_from_esp32_stream(
        self,
        stream_url: str,
        timeout_sec: int = 5
    ) -> Tuple[Optional[bytes], Optional[str]]:
        """
        Captures a single raw JPEG frame from an ESP32-CAM Wi-Fi video stream or snapshot URL.
        
        Supports:
        1. Snapshot endpoint: http://<ip>/capture
        2. MJPEG video stream: http://<ip>:81/stream
        """
        if not stream_url:
            return None, "ESP32-CAM URL not specified."

        try:
            # Check snapshot endpoint first if specified
            if not stream_url.endswith('/stream'):
                resp = requests.get(stream_url, timeout=timeout_sec)
                if resp.status_code == 200 and len(resp.content) > 100:
                    return resp.content, None

            # Connect to continuous MJPEG HTTP stream and read until the first complete JPEG frame
            resp = requests.get(stream_url, stream=True, timeout=timeout_sec)
            if resp.status_code != 200:
                return None, f"ESP32-CAM returned HTTP {resp.status_code}"

            buffer = bytes()
            # Read in chunks and locate JPEG SOI (\xff\xd8) and EOI (\xff\xd9) markers
            for chunk in resp.iter_content(chunk_size=4096):
                buffer += chunk
                start = buffer.find(b'\xff\xd8')
                end = buffer.find(b'\xff\xd9')
                if start != -1 and end != -1 and end > start:
                    jpeg_bytes = buffer[start:end + 2]
                    return jpeg_bytes, None

            return None, "Could not extract a valid JPEG frame from the MJPEG stream."

        except requests.exceptions.Timeout:
            return None, f"Connection timed out contacting ESP32-CAM at {stream_url}"
        except requests.exceptions.RequestException as e:
            return None, f"Network error connecting to ESP32-CAM: {e}"
        except Exception as e:
            return None, f"Unexpected error during ESP32 frame capture: {e}"


# Global singleton instance for high-performance in-memory reuse
_CV_ENGINE_INSTANCE: Optional[CVEngine] = None


def get_cv_engine() -> CVEngine:
    """Returns the singleton CVEngine instance, initializing it lazily if needed."""
    global _CV_ENGINE_INSTANCE
    if _CV_ENGINE_INSTANCE is None:
        _CV_ENGINE_INSTANCE = CVEngine(use_pretrained=True)
    return _CV_ENGINE_INSTANCE


def extract_features_and_detect_loose(image_bytes: bytes) -> Tuple[Optional[List[float]], bool]:
    """
    Standard interface invoked by Django VisionService:
    1. Extracts L2-normalized 576-dimensional MobileNetV3 feature vector.
    2. Identifies if the item is a loose / plain-bag candidate.
    """
    engine = get_cv_engine()
    embedding = engine.extract_embedding(image_bytes)
    is_loose = engine.detect_loose_candidate(image_bytes)
    return embedding, is_loose


def extract_features(image_input: Union[bytes, np.ndarray, Image.Image]) -> Optional[List[float]]:
    """Convenience helper to extract embedding vector."""
    return get_cv_engine().extract_embedding(image_input)


def detect_loose_or_plain_bag(image_input: Union[bytes, np.ndarray]) -> bool:
    """Convenience helper to test plain bag / loose candidate detection."""
    return get_cv_engine().detect_loose_candidate(image_input)


def capture_frame_from_esp32_stream(stream_url: str, timeout_sec: int = 5) -> Tuple[Optional[bytes], Optional[str]]:
    """Convenience helper to grab a frame from ESP32-CAM stream."""
    return get_cv_engine().capture_frame_from_esp32_stream(stream_url, timeout_sec=timeout_sec)
