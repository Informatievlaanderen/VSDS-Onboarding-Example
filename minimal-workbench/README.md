# Setting Up a Minimal Workbench
This quick start guide will show you how to setup a minimal Workbench to create version objects from state objects.

Please see the [introduction](../README.md) for the example data set and pre-requisites, as well as an overview of all examples.

## Show Me Your Workbench
* workbench purpose, etc.
* LDIO vs NiFi
* docker hub

## Configure Your First Pipeline
* describe the docker compose & application config file

## Launch the Magic
```bash
docker compose up -d
while ! docker logs $(docker ps -q -f "name=ldio-workbench$") 2> /dev/null | grep 'Started Application in' ; do sleep 1; done
```

## You've Got Mail
```bash
curl -X POST -H "Content-Type: application/ld+json" "http://localhost:9004/pipeline" -d "@./data/messages.jsonld"
```

## That's All Folks
You now know how to configure a basic LDIO workbench which takes in RDF messages containing a single state object and turn it into a version object that can be ingested as a LDES member.

To bring the containers down and remove the private network:
```bash
docker compose down
```
