FROM fnproject/python:3.11-dev as build-stage

WORKDIR /function
COPY requirements.txt .
RUN pip3 install --target /python/ --no-cache-dir -r requirements.txt
COPY func.py .

FROM fnproject/python:3.11

WORKDIR /function
COPY --from=build-stage /python /python
COPY --from=build-stage /function /function
ENV PYTHONPATH=/python

ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
