# Enrich A Model
This tutorial will show you how to use a LDIO workbench to combine two linked data models in a pipeline.

Please see the [introduction](../README.md) for the pre-requisites, as well as an overview of all examples.

## TODO: test setup title
> TODO: describe graph databases, linked data enrich concept

## TODO: solutions title
> TODO: describe repository & pipelines config

## TODO: teardown title
> TODO: describe steps (launch, configure & seed)
```bash
clear

# start all systems
docker compose up -d --wait

# configure graph repository, upload our cars pipeline and seed the cars collection
curl -X PUT -H "Content-Type: text/turtle" http://localhost:9008/rdf4j-server/repositories/cars --data-binary @./definitions/cars-repository.ttl
curl -X POST -H "content-type: application/yaml" http://localhost:9006/admin/api/v1/pipeline --data-binary @./definitions/cars-pipeline.yml
curl -X POST -H "Content-Type: text/turtle" http://localhost:9006/cars-pipeline --data-binary @./data/cars.ttl

# upload our person pipeline
curl -X POST -H "content-type: application/yaml" http://localhost:9006/admin/api/v1/pipeline --data-binary @./definitions/people-pipeline.yml
```

> TODO: describe enrich person with car info
```bash
# send some data
curl -X POST -H "Content-Type: text/turtle" http://localhost:9006/people-pipeline --data-binary @./data/person.ttl
```

> TODO: describe check result
```bash
# check enriched data
curl http://localhost:9007/member?id=http%3A%2F%2Fexample.com%2Fpeople%2FSpideyBoy
```

## TODO: teardown title
To bring all system down:
```bash
docker compose down
```
