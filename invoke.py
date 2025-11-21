import click
import base64
import io
import requests
import subprocess
import pickle
import json
import numpy as np
mod_names = ["evo2mod1", "evo2mod2", "evo2mod3"]
def decode_numpy_from_base64(encoded_str):
    """Decode a base64-encoded NumPy array."""
    binary = base64.b64decode(encoded_str)
    buf = io.BytesIO(binary)
    return np.load(buf, allow_pickle=False)


def encode_numpy_to_base64(array):
    """Encode a NumPy array into base64."""
    buf = io.BytesIO()
    np.save(buf, array)
    buf.seek(0)
    return base64.b64encode(buf.read()).decode("utf-8")


def get_evo2mod1_test_data():
    import evo2mod1_inputs
    return evo2mod1_inputs.evo2mod1_test_data


def get_evo2mod2_test_data():
    import evo2mod2_inputs
    return evo2mod2_inputs.evo2mod2_test_data


def get_evo2mod3_test_data():
    import evo2mod3_inputs
    return evo2mod3_inputs.evo2mod3_test_data


def print_response(json_response, decode):
    print("===== RESPONSE =====")
    print(json_response)
    print("===== RESPONSE HEADERS =====")
    print(json_response.headers)
    dict_resp = json_response.json()
    print("===== RESPONSE JSON =====")
    print(dict_resp)
    if decode:
        decoded = {}
        for k, v in dict_resp.items():
            decoded[k] = decode_numpy_from_base64(v)
        print("===== RESPONSE DECODED =====")
        print(decoded)


def get_headers(service_account_json_file, url):
    # JWT=$(./generate_jwt.sh pentest-sa.json $URL)
    result = subprocess.run(f"./generate_jwt.sh {service_account_json_file} {url}", shell=True, check=True, capture_output=True)
    jwt = result.stdout.decode('utf8').strip()
    headers = {"Authorization": f"Bearer {jwt}"}
    return headers


def get_data(data_file, mod):
    payload = None
    if data_file is None:
        if mod == "evo2mod1":
            raw_inputs = get_evo2mod1_test_data()
        elif mod == "evo2mod2":
            raw_inputs = get_evo2mod2_test_data()
        elif mod == "evo2mod3":
            raw_inputs = get_evo2mod3_test_data()
        else:
            raise Exception(f"mod={mod} must be in {mod_names}")
    elif data_file.endswith("pkl"):
        with open(data_file, 'rb') as f:
            raw_inputs = pickle.load(f)
    elif data_file.endswith("json"):
        with open(data_file, 'r') as f:
            payload = json.load(f)
    else:
        raise Exception("data-file={data_file} only supports extensions ['pkl', 'json']")
    if payload is None:
        payload = {}
        for k, v in raw_inputs.items():
            if isinstance(v, np.ndarray):
                payload[k] = encode_numpy_to_base64(v)
            else:
                payload[k] = v
    return payload

def request(url, headers, data=None):
    print("===== REQUEST =====")
    print(f"url={url}")
    print("===== REQUEST HEADERS =====")
    print(f"headers={headers}")
    if data is not None:
        print("===== REQUEST DATA =====")
        print(f"data={data}")
        resp = requests.post(url, headers=headers, json=data)
        decode = True
    else:
        resp = requests.get(url, headers=headers)
        decode = False
    print_response(resp, decode)


@click.command()
@click.option('--base-url', help='Base URL to invoke', required=True)
@click.option('--service-account-json-file', help='The json file for the service account', required=True)
@click.option('--mod', help='One of ["evo2mod1", "evo2mod2", "evo2mod3"]', required=False, default=None)
@click.option('--data-file', help='The inputs file can be in pkl or json form', required=False, default=None)
def main(base_url, service_account_json_file, mod, data_file):
    if mod is None:
        headers = get_headers(service_account_json_file, base_url)
        request(base_url, headers)
    elif mod in mod_names:
        url = f"{base_url}/{mod}"
        headers = get_headers(service_account_json_file, url)
        data = get_data(data_file, mod)
        request(url, headers, data)
    else:
        raise Exception(f"mod={mod} must be in {mod_names}")


if __name__ == "__main__":
    main()

