from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import cv2
import numpy as np


@dataclass(frozen=True)
class PresetV1:
    """
    A simple, portable "look preset" derived from one reference photo.

    Method:
    - Histogram match L (tone) channel in LAB to the reference photo.
    - Mean/std match a,b (chrominance) channels in LAB to the reference photo.
    """

    version: str
    method: str
    # Target LAB stats from the reference image (OpenCV LAB: L,a,b in [0,255])
    target_mean: list[float]  # [L, a, b]
    target_std: list[float]  # [L, a, b]
    # Target CDF for L channel histogram matching
    target_l_cdf: list[float]  # length 256, monotonically non-decreasing, last ~1.0

    @staticmethod
    def from_dict(d: dict[str, Any]) -> "PresetV1":
        if d.get("version") != "v1":
            raise ValueError("Unsupported preset version")
        if d.get("method") != "lab_l_hist_ab_mean_std":
            raise ValueError("Unsupported preset method")
        return PresetV1(
            version="v1",
            method="lab_l_hist_ab_mean_std",
            target_mean=list(map(float, d["target_mean"])),
            target_std=list(map(float, d["target_std"])),
            target_l_cdf=list(map(float, d["target_l_cdf"])),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "version": self.version,
            "method": self.method,
            "target_mean": self.target_mean,
            "target_std": self.target_std,
            "target_l_cdf": self.target_l_cdf,
        }


def _bgr_to_lab_u8(bgr_u8: np.ndarray) -> np.ndarray:
    if bgr_u8.dtype != np.uint8 or bgr_u8.ndim != 3 or bgr_u8.shape[2] != 3:
        raise ValueError("Expected uint8 BGR image with shape (H,W,3)")
    return cv2.cvtColor(bgr_u8, cv2.COLOR_BGR2LAB)


def _lab_u8_to_bgr_u8(lab_u8: np.ndarray) -> np.ndarray:
    if lab_u8.dtype != np.uint8 or lab_u8.ndim != 3 or lab_u8.shape[2] != 3:
        raise ValueError("Expected uint8 LAB image with shape (H,W,3)")
    return cv2.cvtColor(lab_u8, cv2.COLOR_LAB2BGR)


def _cdf_256_from_channel_u8(ch_u8: np.ndarray) -> np.ndarray:
    hist = cv2.calcHist([ch_u8], [0], None, [256], [0, 256]).astype(np.float64).reshape(-1)
    total = float(hist.sum())
    if total <= 0:
        # Degenerate image; return identity-ish.
        return np.linspace(0.0, 1.0, 256, dtype=np.float64)
    cdf = np.cumsum(hist) / total
    # Ensure strictly within [0,1] and monotonic.
    cdf = np.clip(cdf, 0.0, 1.0)
    cdf[0] = max(0.0, cdf[0])
    cdf[-1] = 1.0
    return cdf


def _hist_match_map_u8(source_cdf: np.ndarray, target_cdf: np.ndarray) -> np.ndarray:
    """
    Build a 256-entry mapping table such that:
      out = map[in]
    where CDF(out) approximately matches target CDF.
    """
    mapping = np.zeros((256,), dtype=np.uint8)
    t = 0
    for s in range(256):
        while t < 255 and target_cdf[t] < source_cdf[s]:
            t += 1
        mapping[s] = t
    return mapping


def _safe_std(x: np.ndarray) -> float:
    s = float(x.std())
    return s if s > 1e-6 else 1e-6


def create_preset_from_bgr(bgr_u8: np.ndarray) -> PresetV1:
    lab = _bgr_to_lab_u8(bgr_u8)
    l, a, b = cv2.split(lab)

    mean = [float(l.mean()), float(a.mean()), float(b.mean())]
    std = [_safe_std(l), _safe_std(a), _safe_std(b)]
    l_cdf = _cdf_256_from_channel_u8(l)

    return PresetV1(
        version="v1",
        method="lab_l_hist_ab_mean_std",
        target_mean=mean,
        target_std=std,
        target_l_cdf=l_cdf.astype(np.float64).tolist(),
    )


def apply_preset_to_bgr(bgr_u8: np.ndarray, preset: PresetV1) -> np.ndarray:
    lab = _bgr_to_lab_u8(bgr_u8)
    l_u8, a_u8, b_u8 = cv2.split(lab)

    # 1) Tone match: histogram match L to target CDF.
    src_cdf = _cdf_256_from_channel_u8(l_u8)
    tgt_cdf = np.asarray(preset.target_l_cdf, dtype=np.float64)
    if tgt_cdf.shape != (256,):
        raise ValueError("preset.target_l_cdf must be length 256")
    l_map = _hist_match_map_u8(src_cdf, tgt_cdf)
    l_u8 = cv2.LUT(l_u8, l_map)

    # 2) Color match (a,b only): mean/std match to target.
    a = a_u8.astype(np.float32)
    b = b_u8.astype(np.float32)
    a_mean, b_mean = float(a.mean()), float(b.mean())
    a_std, b_std = _safe_std(a), _safe_std(b)

    tgt_a_mean, tgt_b_mean = float(preset.target_mean[1]), float(preset.target_mean[2])
    tgt_a_std, tgt_b_std = float(preset.target_std[1]), float(preset.target_std[2])

    a = (a - a_mean) * (tgt_a_std / a_std) + tgt_a_mean
    b = (b - b_mean) * (tgt_b_std / b_std) + tgt_b_mean

    a_u8 = np.clip(np.round(a), 0, 255).astype(np.uint8)
    b_u8 = np.clip(np.round(b), 0, 255).astype(np.uint8)

    out_lab = cv2.merge([l_u8, a_u8, b_u8])
    out_bgr = _lab_u8_to_bgr_u8(out_lab)
    return out_bgr

