#!/bin/bash

# change directory to advanced conversion example
cd ../advanced-conversion

# start for all systems and wait for them to be available
docker compose up -d --wait

# define the LDES and the view
curl -X POST -H "content-type: text/turtle" "http://localhost:9003/ldes/admin/api/v1/eventstreams" -d "@./definitions/occupancy.ttl"
curl -X POST -H "content-type: text/turtle" "http://localhost:9003/ldes/admin/api/v1/eventstreams/occupancy/views" -d "@./definitions/occupancy.by-page.ttl"

# define our pipelines and start polling for CSV data
curl -X POST -H "content-type: application/yaml" http://localhost:9004/admin/api/v1/pipeline --data-binary @./definitions/park-n-ride-pipeline.yml
curl -X POST -H "content-type: application/yaml" http://localhost:9004/admin/api/v1/pipeline --data-binary @./definitions/csv-pipeline.yml
