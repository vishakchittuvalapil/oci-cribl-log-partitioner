import gzip
import io
import json
import os
import re
import uuid
from collections import defaultdict
from datetime import datetime, timezone

import oci
from fdk import response


def handler(ctx, data: io.BytesIO = None):
    mode = os.environ.get("FUNCTION_MODE", "target_writer").lower()
    log_type_map = load_log_type_map()
    raw = data.getvalue() if data else b"[]"
    records = normalize_records(raw)

    if mode in ("task", "task_transform", "task_ndjson"):
        return task_response(ctx, records, log_type_map)

    bucket_name = os.environ["BUCKET_NAME"]
    object_prefix = os.environ.get("OBJECT_PREFIX", "cribl").strip("/")
    include_minute = os.environ.get("INCLUDE_MINUTE", "true").lower() == "true"

    signer = oci.auth.signers.get_resource_principals_signer()
    object_storage = oci.object_storage.ObjectStorageClient(config={}, signer=signer)

    namespace = os.environ.get("NAMESPACE")
    if not namespace:
        namespace = object_storage.get_namespace().data

    grouped_records = defaultdict(list)

    for record in records:
        log_time = get_log_datetime(record)
        sourcetype = detect_sourcetype(record, log_type_map)

        if include_minute:
            time_folder = log_time.strftime("%Y/%m/%d/%H/%M")
        else:
            time_folder = log_time.strftime("%Y/%m/%d/%H")

        folder = f"{object_prefix}/{time_folder}/{sourcetype}"
        grouped_records[folder].append(record)

    uploaded_objects = []

    for folder, items in grouped_records.items():
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        object_name = f"{folder}/oci-log-{timestamp}-{uuid.uuid4().hex}.json.gz"

        payload = "\n".join(
            json.dumps(item, separators=(",", ":"), default=str) for item in items
        )
        if payload:
            payload += "\n"

        compressed_payload = gzip.compress(payload.encode("utf-8"))

        object_storage.put_object(
            namespace,
            bucket_name,
            object_name,
            compressed_payload,
            content_type="application/x-gzip",
        )

        uploaded_objects.append(object_name)

    return response.Response(
        ctx,
        response_data=json.dumps(
            {
                "records_received": len(records),
                "objects_uploaded": uploaded_objects,
            }
        ),
        headers={"Content-Type": "application/json"},
    )


def task_response(ctx, records, log_type_map):
    transformed_records = [
        enrich_record_for_cribl(record, log_type_map) for record in records
    ]

    output_format = os.environ.get("TASK_OUTPUT_FORMAT", "json").lower()
    if output_format == "ndjson":
        payload = "\n".join(
            json.dumps(item, separators=(",", ":"), default=str)
            for item in transformed_records
        )
        if payload:
            payload += "\n"

        return response.Response(
            ctx,
            response_data=payload,
            headers={"Content-Type": "application/octet-stream"},
        )

    return response.Response(
        ctx,
        response_data=json.dumps(
            transformed_records, separators=(",", ":"), default=str
        ),
        headers={"Content-Type": "application/json"},
    )


def enrich_record_for_cribl(record, log_type_map):
    enriched = json.loads(json.dumps(record, default=str))
    log_time = get_log_datetime(record)
    log_type = detect_sourcetype(record, log_type_map)
    object_prefix = os.environ.get("OBJECT_PREFIX", "cribl").strip("/")
    include_minute = os.environ.get("INCLUDE_MINUTE", "true").lower() == "true"

    if include_minute:
        time_folder = log_time.strftime("%Y/%m/%d/%H/%M")
    else:
        time_folder = log_time.strftime("%Y/%m/%d/%H")

    cribl_metadata = enriched.get("cribl")
    if not isinstance(cribl_metadata, dict):
        cribl_metadata = {}

    cribl_metadata.update(
        {
            "log_type": log_type,
            "event_time": log_time.isoformat().replace("+00:00", "Z"),
            "partition_path": f"{object_prefix}/{time_folder}/{log_type}",
        }
    )

    enriched["cribl"] = cribl_metadata
    enriched["log_type"] = log_type
    return enriched


def normalize_records(raw):
    if not raw.strip():
        return []

    payload = json.loads(raw.decode("utf-8"))

    if isinstance(payload, list):
        return payload

    if isinstance(payload, dict):
        for key in ["records", "logs", "data"]:
            value = payload.get(key)
            if isinstance(value, list):
                return value
        return [payload]

    return []


def load_log_type_map():
    raw_map = os.environ.get("LOG_TYPE_MAP", "{}").strip()
    if not raw_map:
        return {}

    try:
        return json.loads(raw_map)
    except Exception:
        return {}


def detect_sourcetype(record, log_type_map):
    log_id = get_log_id(record)
    if log_id and log_id in log_type_map:
        return sanitize_path_part(log_type_map[log_id])

    log_content = record.get("logContent", {})
    event_type = (
        log_content.get("type")
        or record.get("type")
        or get_nested(record, ["data", "type"])
        or ""
    )
    source = log_content.get("source") or record.get("source") or ""

    text = f"{event_type} {source}".lower()

    if "vcn" in text and "flow" in text:
        return "oci-vcn-flow"
    if "objectstorage" in text or "object-storage" in text or "object_storage" in text:
        return "oci-object-storage"
    if "audit" in text:
        return "oci-audit"
    if "cloudguard" in text or "cloud-guard" in text:
        return "oci-cloud-guard"
    if "loadbalancer" in text or "load-balancer" in text:
        return "oci-load-balancer"

    return "oci-generic"


def get_log_id(record):
    return (
        get_nested(record, ["logContent", "oracle", "logid"])
        or get_nested(record, ["logContent", "oracle", "logId"])
        or get_nested(record, ["oracle", "logid"])
        or record.get("logid")
        or record.get("logId")
    )


def get_log_datetime(record):
    for field in ["datetime", "time", "eventTime"]:
        value = record.get(field)
        if value:
            return parse_datetime(value)

    for path in [
        ["logContent", "time"],
        ["logContent", "datetime"],
        ["logContent", "oracle", "ingestedtime"],
        ["logContent", "data", "time"],
        ["logContent", "data", "datetime"],
        ["logContent", "data", "startTime"],
    ]:
        value = get_nested(record, path)
        if value:
            return parse_datetime(value)

    return datetime.now(timezone.utc)


def parse_datetime(value):
    if isinstance(value, (int, float)):
        if value > 9999999999:
            value = value / 1000
        return datetime.fromtimestamp(value, timezone.utc)

    value = str(value).strip()

    if value.endswith("Z"):
        value = value[:-1] + "+00:00"

    value = re.sub(r"(\.\d{6})\d+([+-]\d{2}:\d{2})$", r"\1\2", value)
    dt = datetime.fromisoformat(value)

    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)

    return dt.astimezone(timezone.utc)


def get_nested(data, path):
    current = data

    for key in path:
        if not isinstance(current, dict):
            return None
        current = current.get(key)

    return current


def sanitize_path_part(value):
    value = str(value).strip().lower()
    value = re.sub(r"[^a-z0-9._-]+", "-", value)
    value = value.strip("-._")
    return value or "oci-generic"
