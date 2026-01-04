from __future__ import annotations

import io
import json
from typing import Any

import cv2
import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from PIL import Image

from preset_service.preset import PresetV1, apply_preset_to_bgr, create_preset_from_bgr

app = FastAPI(title="Photo Preset Service", version="0.1.0")

# For Flutter Web (and local dev UIs), we need CORS enabled.
# This is permissive by design for MVP/local testing.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _load_image_to_bgr_u8(file_bytes: bytes) -> np.ndarray:
    # Pillow handles more formats than OpenCV's imdecode.
    try:
        img = Image.open(io.BytesIO(file_bytes)).convert("RGB")
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"Invalid image: {e}") from e
    rgb = np.asarray(img, dtype=np.uint8)
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    return bgr


def _encode_bgr_u8_to_png(bgr_u8: np.ndarray) -> bytes:
    ok, buf = cv2.imencode(".png", bgr_u8)
    if not ok:
        raise HTTPException(status_code=500, detail="Failed to encode output image")
    return bytes(buf)


@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True}


@app.post("/preset")
async def create_preset(image: UploadFile = File(...)) -> JSONResponse:
    file_bytes = await image.read()
    bgr = _load_image_to_bgr_u8(file_bytes)
    preset = create_preset_from_bgr(bgr)
    return JSONResponse(preset.to_dict())


@app.post("/apply")
async def apply_preset(
    image: UploadFile = File(...),
    preset_json: str = Form(...),
) -> Response:
    try:
        preset_dict = json.loads(preset_json)
        preset = PresetV1.from_dict(preset_dict)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"Invalid preset_json: {e}") from e

    file_bytes = await image.read()
    bgr = _load_image_to_bgr_u8(file_bytes)
    out_bgr = apply_preset_to_bgr(bgr, preset)
    out_png = _encode_bgr_u8_to_png(out_bgr)
    return Response(content=out_png, media_type="image/png")

