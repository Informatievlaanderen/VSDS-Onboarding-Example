# Setting Up a Minimal LDES Client
> **UPDATED** this tutorial has been changed to define the publish pipeline dynamically and to add a (test) sink system. You can find the previous version [here](https://github.com/Informatievlaanderen/VSDS-Onboarding-Example/tree/v1.0.0/minimal-client).

This tutorial will show you how to setup a minimal LDES CLient in order to replicate and synchronize an existing Linked Data Event Stream (LDES).

Please see the [introduction](../README.md) for the example data set and pre-requisites, as well as an overview of all examples.

## LDES in a Nutshell

If you look at the [Tree specification](https://treecg.github.io/specification/) you will see that an LDES (which derives from this specification) is a _collection of views_. A view is in fact the first node of a tree of nodes containing _members_ of the collection as well as _relations_ to other nodes. Wow, let us take a moment here to reflect about this. So, we have a data collection containing collection members. The size of the collection is potentially very big so a LDES allows us to split the collection in pieces. Each view is in fact a collection of connected nodes which may contain a number of collection members as well as links to other nodes which allow us to traverse the whole connected structure. So, by following all the links in the nodes of a view we can collect all the members of the data collection. Each view is organized in some way: the nodes may together form a list, a tree or a graph. This organization comes into existence by a process we call _fragmentation_: creating a structure of nodes by adding zero or more relations (containing a link to another node) to each node as well as assigning a collection member to one or more nodes.

As said, the [LDES specification](https://semiceu.github.io/LinkedDataEventStreams/) is based on the [Tree specification](https://treecg.github.io/specification/) and provides a way to keep the history of changes of a data collection. The result is a _dynamic data collection_ and the members of a LDES are _version objects_ instead of _state objects_. So, a version object is in essence a state object at some point in time. An LDES allows us to _replicate_ the data collection in addition to _synchronize_ with the changes that occur to this data collection after we have retrieved it. This allows us to keep in sync with the historical state of a system.

## All The Things She Said
Suppose there is a public LDES available out there that you would like to use. We will assume that you know the URL of this LDES. If not, you will need to discover the URL by looking at some metadata catalog such as [Metadata Vlaanderen](https://metadata.vlaanderen.be/).

Once we have the URL of the LDES we can choose one of its views because as stated before each view allows us to retrieve all the members of the LDES by following all the links in the connected nodes. There is no point in following the links in multiple views of an LDES as we end up collecting the same members multiple times.

OK, so we have a LDES URL (e.g. `http://localhost:9003/ldes/occupancy`) and we have selected a view URL by retrieving the LDES itself and selecting one of the `tree:view`s of the `ldes:EventStream`, e.g. `http://localhost:9003/ldes/occupancy/by-page`. Now what? For sure we are not going to extract all the members from each node or get all the links to the other nodes by hand. Are we? There can be thousands or millions of nodes and members! Well, of course not.

Lucky for you we have already done the hard part of creating a LDES Client, which is a freely available component that allows us to, given a LDES or a view, request the view node or any linked node, extract each member from the node and follow the links in each node in order to collect all members and in fact _replicate_ the LDES. In addition, the LDES Client will also look at the node properties which are lokated in the HTTP headers and re-request the nodes that can change over time, both nodes structure and nodes containing members. By doing this we can _synchronize_ the LDES.

The LDES CLient component is packaged as a [LDIO input component](https://github.com/Informatievlaanderen/VSDS-Linked-Data-Interactions/tree/main/ldi-orchestrator/ldio-connectors/ldio-ldes-client) (as well as a [NiFi processor](https://github.com/Informatievlaanderen/VSDS-Linked-Data-Interactions/tree/main/ldi-nifi/ldi-nifi-processors/ldes-client-processor)). The LDIO components are packaged as a docker image ([LDIO workbench](https://hub.docker.com/r/ldes/ldi-orchestrator). These components act as the initial part of a data pipeline and need a sink component which receives the extracted collection members which as you already know are version objects. But if you do not need the history of state changes you need a way to revert these version objects back to their corresponding state object. This process of converting such a _version object_ back to a _state object_ we call _version materialization_. The LDES Client can do that if you configure it to [output state objects](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/ldio/ldio-inputs/ldio-ldes-client#version-materialisation-properties).

No doubt you are thinking by now: 'yeah, yeah, enough with that, just show me how!' OK then, if you insist...

## Get Your Motor Runnin'
For the LDES we can simply use the [parking lot example](../advanced-conversion/README.md). For this LDES we know that there is only one view, i.e. `http://localhost:9003/ldes/occupancy/by-page`. 

Go ahead and run it so that we have a LDES to work with:
```bash
chmod +x ./run-ldes-server.sh
./run-ldes-server.sh
```
Done? Let's continue then.

Now what do we need for our minimal LDES Client example? Really not that much! We obviouly need a workbench (e.g. LDIO) containing one pipeline which starts with a [LDES Client component](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/ldio/ldio-inputs/ldio-ldes-client) and outputs the members to a sink. For the sink we can use a [test message sink](https://github.com/Informatievlaanderen/VSDS-LDES-E2E-message-sink)). You can use any sink for which we have an [output component](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/ldio/ldio-outputs/index). We will be using the HTTP protocol in this tutorial so we can use a [HTTP output component](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/ldio/ldio-outputs/ldio-http-out) to output members to our sink.

So, the input part of our pipeline will look something like this:
```yaml
name: Ldio:LdesClient
config:
  urls: 
    - http://localhost:9003/ldes/occupancy/by-page
```
That's all folks. Short and simple.

Now for the output:
```yaml
name: Ldio:HttpOut
config:
  endpoint: http://localhost:9007/member
```
It is as simple as the input part!

OK, the complete [pipeline](./pipeline.yml) is a bit more elaborate and looks like this:
```yaml
# This is a pipeline for demonstrating a basic LDES client which can replicate and synchronize an existing LDES
name: client-pipeline
description: "Requests all existing members from a public LDES server and keeps following it for changes, sending each member as-is to a sink system"
input:
  name: Ldio:LdesClient
  config:
    urls: 
      - http://localhost:9003/ldes/occupancy/by-page
outputs:
  - name: Ldio:HttpOut
    config:
      endpoint: http://localhost:9007/member
```

The [docker compose](./docker-compose.yml) file isn't all that scary either. We just need a workbench service which looks like this:
```yaml
ldio-workbench:
  image: ldes/ldi-orchestrator:2.12.0
  network_mode: "host"
  environment:
    - SERVER_PORT=9006
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://localhost:9006/actuator/health"]
```
We use a recent [LDIO image](https://hub.docker.com/r/ldes/ldi-orchestrator/tags) from docker hub. We define an environment variable for the LDIO Workbench server port and a health check which allows us to wait that the workbench to be fully initialized and ready to accept pipelines.

Hmmm, what is that line `network_mode: "host"` all about? Well, as stated before, the links in the LDES nodes will be absolute URLs as defined by the LDES Server configuration which in this case is `http://localhost:9003/ldes`. Because we have exposed the LDES Server to the host system (basically your system) you can request the LDES view and all the nodes from your (host) system just fine. However, the `localhost` is a special name which always resolves to IP address 127.0.0.1 as it maps the the loopback adapter of your network card. Essentially, if using its own network, when the LDES Client tries to request a LDES node located on `localhost` it will get back it's loopback address 127.0.0.1 instead of the IP address of the LDES Server. So, the trick we use here is to let the workbench containing our LDES Client share the network of your system (the host) allowing it to resolve to the host network stack and then because of the docker port mapping, your docker will do its magic and forward the HTTP request to the LDES Server container. This is a bit of hocus-pocus that we need in this tutorial because we run our LDES Server locally and do not expose it using a domain name. In real-life you will not have to do this. In fact, if you would use a LDES which is hosted on the web in this tutorial you could comment out or remove the line.

We also define our sink system in the Docker compose file:
```yaml
networks:
  basic-client:
    name: basic-client-network

services:
  ...

  sink-system:
    image: ghcr.io/informatievlaanderen/test-message-sink:latest
    ports:
      - 9007:80
    networks:
      - basic-client
    environment:
      - MEMORY=true
      - MEMBER_TYPE=http://schema.mobivoc.org/#ParkingLot
```
As you can see, we define a private network and put the sink system in that network. We configure the sink system to use an in-memory database for storing the received members and tell it the member type to expect.

Now you can run the example using the following command (in a bash shell):
```bash
clear

# start systems and wait until they are ready
docker compose up -d --wait

# upload our pipeline to start following the LDES
curl -X POST -H "content-type: application/yaml" http://localhost:9006/admin/api/v1/pipeline --data-binary @./pipeline.yml
```

Looking at the server workbench docker log file, you can verify which members are being created:
```bash
docker logs -f $(docker ps -q -f "name=advanced-conversion-ldio-workbench-1")
```
> **Note** use `CTRL-C` to stop following the logs.

Looking at the client workbench, you will see that the LDES Client starts following the LDES view:
```bash
docker logs -f $(docker compose ps -q ldio-workbench)
```
will contain something like this:
```text
2024-04-22T12:59:59.526Z  INFO 1 --- [pool-3-thread-1] l.c.s.StartingTreeNodeFinder             : determineStartingTreeNode for: http://localhost:9003/ldes/occupancy/by-page
2024-04-22T12:59:59.724Z  INFO 1 --- [pool-3-thread-1] l.c.s.StartingTreeNodeFinder             : Parsing response for: http://localhost:9003/ldes/occupancy/by-page
```
> **Note** use `CTRL-C` to stop following the logs.

You can follow the sink to check how many version objects were received:
```bash
while true; do curl http://localhost:9007; echo ""; sleep 15; done
```
You can also check the sink for the [available members](http://localhost:9007/member).

After a little bit, the sink stops receiving members. You have now succesfully _replicated_ the data collection. However, our [parking lot workbench](../advanced-conversion/workbench/application.yml) polls the source system frequently and generates at most 5 new version objects on each run. So, every 2 minutes you can see these new versions appear in the sink. You are now _synchronizing_ the data collection forever, that is, until the LDES Server system is stopped.

> **Note** use `CTRL-C` to stop following the sink count.

## And Now, The End Is Near
To bring all system down:
```bash
docker compose down
chmod +x ./stop-ldes-server.sh
./stop-ldes-server.sh
```
