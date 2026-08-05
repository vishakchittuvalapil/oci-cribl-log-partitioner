# Architecture Notes

## Final Flow

```text
OCI Logging
  -> Service Connector Hub
  -> OCI Function target
  -> OCI Object Storage
  -> Cribl S3 Collector
```

## Why Not Object Storage as the Connector Target?

Service Connector Hub's Object Storage target accepts a static prefix:

```text
objectNamePrefix
```

It does not support a dynamic path expression equivalent to:

```text
cribl/${time}/${log_type}
```

Because Cribl alignment depends on dynamic folders, the Function must write the Object Storage object itself.

## Cribl Concept Mapping

Cribl S3 destination concept:

```text
Key Prefix + Partitioning Expression + File Name Prefix
```

This Function's object key:

```text
cribl/YYYY/MM/DD/HH/MM/<log_type>/oci-log-<timestamp>-<uuid>.json.gz
```

Mapping:

```text
Key Prefix              -> cribl/YYYY/MM/DD/HH/MM
Partitioning Expression -> <log_type>
File Name Prefix        -> oci-log
Compression             -> gzip
```
