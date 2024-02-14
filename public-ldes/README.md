# Consuming a Public LDES
This tutorial will show you how to consume an existing public [Linked Data Event Stream (LDES)](https://semiceu.github.io/LinkedDataEventStreams/) using a simple pipeline in the [LDIO Workbench](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/) and sending the LDES members to a custom backend system for further processing or querying.

Please see the [introduction](../README.md) for the pre-requisites, as well as an overview of all examples.

## Easy As Pie
Consuming an LDES is as simple as using and configuring a LDES Client component as part of a pipeline in a LDIO (or NiFi) Workbench. The LDES Client sits at the start of a pipeline and takes care of retrieving the LDES members from the stream. It also keeps polling for changes (based on the `max-age` value in the `cache-control` HTTP headers). The LDES Client internally outputs the members as [RDF](https://en.wikipedia.org/wiki/Resource_Description_Framework) models which can be further processed by the transformers (if any) in the pipeline and finally need to be serialized to one of the RDF serialization formats as part of the output component which of course sits at the end of the pipeline.

So, the minimal pipeline that you need is a LDES Client plus one of the supported output components. In this example we use a HTTP out component and send each member to our custom backend system, which is a small tool that simply accepts the member as-is, searches for an identifier (based on an entity type) and stores it in a database.

> **Note** that in your backend system you may not support version objects and therefore need to add one transformer which converts such a LDES member (version object) back to the original (state) object.

> **Note** that if you only want to keep the latest state in your backend system you will typically look at a timestamp or another property to determine if you already have more recent version of this state because LDES members may arrive in any order in your backend.

In fact, the pipeline configuration is the only thing we need in addition to a docker compose file! So, how does our docker compose file look like? Well, it is as simple as this for the workbench part:
```yaml
workbench:
  container_name: public-ldes_workbench
  image: ldes/ldi-orchestrator:2.0.0-SNAPSHOT # you can safely change this to the latest 1.x.y version
  volumes:
    - ./workbench/application.yml:/ldio/application.yml:ro
  networks:
    - public-ldes-network 
  profiles:
    - delay-started
  environment:
    - LDES_SERVER_URL=https://brugge-ldes.geomobility.eu/observations/by-page
```
> **Note** that we defined a environment variable to specify our exiting, public LDES view but we could have put in the workbench pipeline definition as well. Also note that we start the workbench later to ensure our backend systems are ready to accept the members.

Your backend systems will typically already exist but for this tutorial we use a simple message sink backed by a database, as you can see in the [docker compose](./docker-compose.yml) file.

What about the pipeline? It is trivial as well:
```yaml
- name: client-pipeline
  description: "Replicates & synchronizes an existing LDES view and sends each member to a sink"
  input:
    name: Ldio:LdesClient
    config:
      urls: 
        - ${LDES_SERVER_URL}
      sourceFormat: application/n-triples
  outputs:
    - name: Ldio:HttpOut
      config:
        endpoint: http://sink/member
```
> **Note** that we only specify the LDES url (by means of an environment in the docker compose file), request the LDES fragments using [N-Triples](https://en.wikipedia.org/wiki/N-Triples) which allows for fast parsing and we send the members as-is to the sink using HTTP. That's all folks!

## Ready, Set, Action!
To see our setup in action, you can use the following:
```bash
clear

docker compose up -d
while ! docker logs $(docker ps -q -f "name=sink$") 2> /dev/null | grep 'Sink listening at http://0.0.0.0:80' ; do sleep 1; done

docker compose up workbench -d
while ! docker logs $(docker ps -q -f "name=workbench$") 2> /dev/null | grep 'Started Application in' ; do sleep 1; done
```

You can follow the number of members being replicated using:
```bash
while true; do curl http://localhost:9006; printf "\r"; sleep 1; done
```
> Press `CTRL-C` to stop following the count.

> **Note** that this particular LDES is a historical data set which does not change. It contains almost 670.000 members and takes almost 2 hours to replicate. As it is a historical data set, no synchronization happens after the replication phase.

You can see the (first couple of) available members using:
```bash
curl http://localhost:9006/member
```

If you open the above link (http://localhost:9006/member) in a browser you can click on a member to see the content.
> **Note** that the result is in [Turtle](https://www.w3.org/TR/turtle/) format as we did not specify a `rdf-writer` in the `LdioHttpOut` configuration with a different RDF serialization format. E. g. if we wanted N-Triples we can add change the configuration to:
```yaml
outputs:
- name: Ldio:HttpOut
  config:
    endpoint: http://sink/member
    rdf-writer:
      content-type: application/n-triples
```

## So Long, Folks
You can wait until the full LDES is replicated and than bring all systems down or you can interrupt the LDES client earlier using:
```bash
docker compose rm workbench --stop --force --volumes
docker compose down
```
