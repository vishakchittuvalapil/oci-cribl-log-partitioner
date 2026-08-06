FROM fnproject/python:3.11-dev as build-stage

WORKDIR /function
COPY requirements.txt .
RUN set -eux; \
    pip3 install --target /python/ --no-cache-dir --no-compile -r requirements.txt; \
    for path in /python/oci/*; do \
        name="$(basename "$path")"; \
        case "$name" in \
            auth|object_storage|dns|pagination|retry|circuit_breaker|fips|developer_tool_configuration|_vendor) ;; \
            *) if [ -d "$path" ]; then rm -rf "$path"; fi ;; \
        esac; \
    done; \
    find /python -type d -name "__pycache__" -prune -exec rm -rf {} +; \
    find /python -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete
COPY func.py .

FROM fnproject/python:3.11

WORKDIR /function
COPY --from=build-stage /python /python
COPY --from=build-stage /function /function
RUN chmod -R o+r /python /function
ENV PYTHONPATH=/function:/python

ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
