# Publishing a Simple Data Set With a Basic Setup
This quick start guide will show you how to combine a [LDIO Workbench](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/) and a [LDES Server](https://informatievlaanderen.github.io/VSDS-LDESServer4J/) to create a basic setup for publishing [linked data](https://en.wikipedia.org/wiki/Linked_data) as a [Linked Data Event Stream (LDES)](https://semiceu.github.io/LinkedDataEventStreams/).

Please see the [introduction](../README.md) for the example data set and pre-requisites, as well as an overview of all examples.

## All the Things We Need
In order to publish your data set as a LDES you will need to setup and configure a few systems. To start with you need a LDES Server. It will accepts, store and serve the data set. Next you will need a workbench which at the least creates version objects from your data set which typically consists of state objects. In addition, as your data set will typically not be linked data, you will have to create a small pipeline in the workbench to transform your custom data model formatted in whatever format that you expose to a linked data model. The LDES server can ingest the resulting linked data model from several [RDF](https://en.wikipedia.org/wiki/Resource_Description_Framework) serializations and serve the event stream in any of those [RDF formats](https://en.wikipedia.org/wiki/Resource_Description_Framework#Serialization_formats).

Let's start by creating a [Docker Compose](https://docs.docker.com/compose/) file containing a LDES server, its [MongoDB](https://www.mongodb.com/) storage container and a LDIO Workbench. First, we start by naming the file `docker-compose.yml` and add the file version and a private network which allows our three systems to interact:

```yaml
version: '2.0'

networks:
  basic-setup:
    name: basic-setup_ldes-network
```

We add the MongoDB system as our first service. We simply use the latest `mongo` image from [Docker Hub](https://hub.docker.com/_/mongo) and expose the default MongoDB port. This allows use to use a tool such as [MongoDB Compass](https://www.mongodb.com/products/tools/compass) to examine the database if needed:

```yaml
services:

  ldes-mongodb:
    container_name: basic-setup_ldes-mongodb
    image: mongo:latest
    ports:
      - 27017:27017
    networks:
      - basic-setup
```

After that we add a LDES Server as a service, point it to its configuration file using volume mapping, expose its port so we can retrieve the event stream and set it to depend on the storage container in order to delay starting the server container until after the storage container:

```yaml
  ldes-server:
    container_name: basic-setup_ldes-server
    image: ldes/ldes-server:2.5.0-SNAPSHOT # you can safely change this to the latest 2.x.y version
    volumes:
      - ./server/application.yml:/application.yml:ro
    ports:
      - 9003:80
    networks:
      - basic-setup
    depends_on:
      - ldes-mongodb
```

Finally, we add a LDIO Workbench as a service. It too needs to have access to its configuration file which we again provide using volume mapping. We also need to expose the workbench listener port so we can feed it with models from our custom data set.

```yaml
  ldio-workbench:
    container_name: basic-setup_ldio-workbench
    image: ldes/ldi-orchestrator:1.11.0-SNAPSHOT # you can safely change this to the latest 1.x.y version
    volumes:
      - ./workbench/application.yml:/ldio/application.yml:ro
    ports:
      - 9004:80
    networks:
      - basic-setup 
```

We end up with [this](./docker-compose.yml) Docker compose file. At this point we cannot start the containers yet as we do refer to the LDES Server and the LDIO Workbench configuration files but we still need to create them.

## Create the LDES Server Configuration File
Let's continue by creating a configuration file for the LDES Server. But before we do we need to think about and decide on a few things:
* in which database do we store the LDES and related information?
* on what sub-path will we serve our LDES?
* on what port will we run our server?

For this tutorial we can pick any name for the database. Let's go for `basic-setup`. As within our private Docker network the containers can be reached by using their service name, the MongoDB connection string becomes `mongodb://ldes-mongodb/basic-setup`. We do not need to specify the default port `27017`.

For the port (`server.port`) and sub-path (`server.servlet.context-path`) on which the LDES Server is available we'll go for `80` respectively `/ldes`.  

> **Note** that we had to specify that indexes should be created automatically by the application (`auto-index-creation: true`).

> **Note** that we also need to specify the external base URL of the LDES so that we can follow the event stream from our local system (`host-name: http://localhost:9003/ldes`) because we set a sub-path (`context-path: /ldes`). Of course if we would change the server's [external port number](./docker-compose.yml#L23) in the Docker compose file, we need to change it here as well.

## Create the LDIO Workbench Configuration File
For the workbench configuration file we can start from the [configuration](../minimal-workbench/config/application.yml) we used for the [minimal workbench tutorial](../minimal-workbench/README.md) but serve the pipelines on a different port (`80`).

As we are now creating an integrated setup we will not send the generated members to the container log using the `ConsoleOut` component, but instead we use the `LdioHttpOut` component. This component allows us to send the member to the LDES server ingest endpoint over HTTP. How do we determine this HTTP ingest endpoint? Because the LDIO Workbench and the LDES Server share the same private network, the workbench can address the server using its service name `ldes-server` as server path `http://ldes-server`. As we have set the sub-path to serve all event streams from `/ldes` we append that to the server path. Finally, as we [define](./definitions/occupancy.ttl) our LDES in the same way as we did in the [minimal server tutorial](../minimal-server/README.md), we need to append the name of the LDES (`/occupancy`). Putting all of this together, in this tutorial the HTTP ingest endpoint for our LDES becomes `http://ldes-server/ldes/occupancy`. The configuration for our output thus becomes:

```yaml
outputs:
  - name: Ldio:HttpOut
    config:
      endpoint: http://ldes-server/ldes/occupancy
      rdf-writer:
        content-type: application/n-quads
```

> **Note** that we can use the `rdf-writer.content-type` setting to change the RDF format used when sending the member to the LDES Server ingest endpoint. By default it is [Turtle](https://en.wikipedia.org/wiki/Turtle_(syntax)) (`text/turtle`) but here we choose [N-quads](https://en.wikipedia.org/wiki/N-Triples#N-Quads) (`application/n-quads`) as this is faster than any other RDF serialization both when writing and parsing.

In our minimal workbench tutorial we assumed that we had linked data and we POST'ed a message formatted as [JSON-LD](https://json-ld.org/) to the workbench. Usually, you will have data in a more traditional (non-linked data) model. Typically there will be an API that you can poll or maybe the source system will notify you of changes using messages. No matter if the interface is pull-driven or push-driven, the data will be format using JSON, XML, CSV or similar. Now, let's assume that on the input side we have a [JSON message](./data/message.json) that is pushed into the workbench pipeline. We need to turn this non-linked data into linked-data. To accomplish this we can attach a [JSON-LD context](./workbench/context.jsonld) to the message. To do so, we need to use a `JsonToLdAdapter` in the `LdioHttpIn` component and configure to use our context. We also need to [map the context](./docker-compose.yml#L33) in the container as follows:

```yaml
volumes:
  - ./workbench/context.jsonld:/ldio/context.jsonld:ro
```

Now we can change the workbench input configuration to:

```yaml
input:
  name: Ldio:HttpIn
  adapter:
    name: Ldio:JsonToLdAdapter
    config:
      core-context: file:///ldio/context.jsonld
```

> **Note** that we have to use the URI notation for the internal container path (`/ldio/context.jsonld`). Alternatively, we could use some pre-existing context somewhere online or refer to it by URL.

For the transformations steps we keep the same configuration for the version object creation and end up with the resulting [configuration file](./workbench/application.yml)

## Bringing it All Together
Now that we have everything set up, let's test the systems. We need to bring all systems up, wait for both the LDIO Workbench and LDES Server to be available, send the LDES and view definitions to the server and finally send the JSON message to the workbench. Then we can retrieve the LDEs, the view and the page containing the actual member.

To run the systems, wait, send definitions and message (execute in a **bash** shell):
```bash
clear

# bring the systems up
docker compose up -d

# wait for the workbench
while ! docker logs $(docker ps -q -f "name=ldio-workbench$") 2> /dev/null | grep 'Started Application in' ; do sleep 1; done

# wait for the server
while ! docker logs $(docker ps -q -f "name=ldes-server$") 2> /dev/null | grep 'Started Application in' ; do sleep 1; done

# define the LDES
curl -X POST -H "content-type: text/turtle" "http://localhost:9003/ldes/admin/api/v1/eventstreams" -d "@./definitions/occupancy.ttl"

# define the view
curl -X POST -H "content-type: text/turtle" "http://localhost:9003/ldes/admin/api/v1/eventstreams/occupancy/views" -d "@./definitions/occupancy.by-page.ttl"

# send the message
curl -X POST -H "Content-Type: application/json" "http://localhost:9004/p+r-pipeline" -d "@./data/message.json"
```

> **Note** that we send the definitions to `http://localhost:9003/ldes` because we have defined `server.servlet.context-path: /ldes`.

> **Note** that we send a JSON message now and therefore specify a header `Content-Type: application/json`.

To verify the LDES, view and data:
```bash
clear

# get the LDES
curl "http://localhost:9003/ldes/occupancy"

# get the view
curl "http://localhost:9003/ldes/occupancy/by-page"

# get the data
curl "http://localhost:9003/ldes/occupancy/by-page?pageNumber=1"
```

> **Note** that we explicitly noted the three steps to get to the data. Typically a system that wants to replicate and synchronize a LDES only needs access to the LDES itself and can discover the view and subsequently the pages of that view by following the links in the LDES and view. To do so, we can use a [LDES Client](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/core/ldi-inputs/ldes-client) but that is a different tutorial.

## The Party is Over, Let's Go Home
You should now know how to publish a simple data set using a LDES Workbench and use a LDES Server to serve this data set using LDES. You learned how to setup a Docker compose file from scratch, how to configure the LDES Server on a different path and port, how to configure a LDIO Workbench to accept non-linked data and send it to the LDES Server. You can now stop all the systems.

To bring the containers down and remove the private network:
```bash
docker compose down
```
