# Photo Preset Service (MVP)

This is a small backend you can use from a mobile app:

- **Create preset** from 1 reference photo → returns a **portable JSON preset**
- **Apply preset** to any other photo → returns the edited image (PNG)

The preset is intentionally simple (fast, deterministic):

- Convert to **LAB**
- **Histogram match** the **L** channel (tone/contrast)
- **Mean/std match** the **a,b** channels (color)

## Run locally

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r preset_service/requirements.txt
uvicorn preset_service.app:app --reload --host 0.0.0.0 --port 8000
```

## API

### `POST /preset`

Multipart form:

- `image`: file

Response: JSON

```json
{
  "version": "v1",
  "method": "lab_l_hist_ab_mean_std",
  "target_mean": [123.4, 128.1, 130.2],
  "target_std": [52.1, 9.2, 10.0],
  "target_l_cdf": [0.0001, 0.0002, "... 256 values total ...", 1.0]
}
```

### `POST /apply`

Multipart form:

- `image`: file
- `preset_json`: string containing the JSON returned by `/preset`

Response: `image/png`

## How a mobile app uses this

- User selects a photo → upload to `/preset` → save returned JSON as a **named preset**
- User selects another photo → upload to `/apply` with the saved preset JSON → display/save result

