# Publishing a Simple Data Set With a Basic Setup
> **UPDATED** this tutorial has been changed to use Postgres as a data store instead of a MongoDB (which is obsoleted as of [LDES Server version 3.x](https://github.com/Informatievlaanderen/VSDS-LDESServer4J/releases/tag/v3.0.0-alpha)). You can find the previous version [here](https://github.com/Informatievlaanderen/VSDS-Onboarding-Example/tree/v2.0.0/basic-setup).

This quick start guide will show you how to combine a [LDIO Workbench](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/) and a [LDES Server](https://informatievlaanderen.github.io/VSDS-LDESServer4J/) to create a basic setup for publishing [linked data](https://en.wikipedia.org/wiki/Linked_data) as a [Linked Data Event Stream (LDES)](https://semiceu.github.io/LinkedDataEventStreams/).

Please see the [introduction](../README.md) for the example data set and pre-requisites, as well as an overview of all examples.

## All the Things We Need
In order to publish your data set as a LDES you will need to setup and configure a few systems. To start with you need a LDES Server. It will accepts, store and serve the data set. Next you will need a workbench which at the least creates version objects from your data set which typically consists of state objects. In addition, as your data set will typically not be linked data, you will have to create a small pipeline in the workbench to transform your custom data model formatted in whatever format that you expose to a linked data model. The LDES server can ingest the resulting linked data model from several [RDF](https://en.wikipedia.org/wiki/Resource_Description_Framework) serializations and serve the event stream in any of those [RDF formats](https://en.wikipedia.org/wiki/Resource_Description_Framework#Serialization_formats).

Let's start by creating a [Docker Compose](https://docs.docker.com/compose/) file containing a LDES server, its [Postgres](https://www.postgresql.org/) storage container and a LDIO Workbench. First, we start by naming the file `docker-compose.yml` and add the file version and a private network which allows our three systems to interact:

```yaml
networks:
  basic-setup:
    name: basic-setup_ldes-network
```

We add the Postgres system as our first service. We simply use the latest `postgres` image from [Docker Hub](https://hub.docker.com/_/postgres) and expose the default Postgres port. We also pre-define a database naled `basic-setup` and pass in the database credentials using environment variables (found in the [.env file](./.env)):

```yaml
services:

  ldes-postgresdb:
    container_name: basic-setup_ldes-postgresdb
    image: postgres:latest
    environment:
      - POSTGRES_DB=basic-setup
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PWD}
    ports:
      - 5432:5432
    networks:
      - basic-setup
```

After that we add a LDES Server as a service, point it to its configuration file using volume mapping, expose its port so we can retrieve the event stream, set some environment variables (see [later](#ldes-server-environment-settings)) and set it to depend on the storage container in order to delay starting the server container until after the storage container:

```yaml
  ldes-server:
    container_name: basic-setup_ldes-server
    image: ldes/ldes-server:2.14.0
    environment:
      - SERVER_PORT=80
      - SIS_DATA=/tmp
      - SERVLET_CONTEXTPATH=/ldes
      - LDESSERVER_HOSTNAME=http://localhost:9003/ldes
      - SPRING_DATASOURCE_URL=jdbc:postgresql://ldes-postgresdb:5432/basic-setup
      - SPRING_DATASOURCE_USERNAME=${POSTGRES_USER}
      - SPRING_DATASOURCE_PASSWORD=${POSTGRES_PWD}
      - SPRING_BATCH_JDBC_INITIALIZESCHEMA=always
    volumes:
      - ./server/application.yml:/application.yml:ro
    ports:
      - 9003:80
    networks:
      - basic-setup
    depends_on:
      - ldes-postgresdb
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://ldes-server:8080/actuator/health"]
```

Finally, we add a LDIO Workbench as a service. It too needs to have access to its configuration file which we again provide using volume mapping. We also need to expose the workbench listener port so we can feed it with models from our custom data set.

```yaml
  ldio-workbench:
    container_name: basic-setup_ldio-workbench
    image: ldes/ldi-orchestrator:2.5.0-SNAPSHOT
    volumes:
      - ./workbench/application.yml:/ldio/application.yml:ro
    ports:
      - 9004:80
    networks:
      - basic-setup 
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://ldes-server-workbench:8080/actuator/health"]
```

We end up with [this](./docker-compose.yml) Docker compose file. At this point we cannot start the containers yet as we do refer to the LDES Server and the LDIO Workbench configuration files but we still need to create them.

> **Note** that we also add health checks to ensure we can wait until the components are actually fully initialized and ready.

### LDES Server Environment Settings
Let's continue by defining the environment settings for the LDES Server. But before we do we need to think about and decide on a few things:
* in which database do we store the LDES and related information?
* on what sub-path will we serve our LDES?
* on what port will we run our server?

For this tutorial we can pick any name for the database. Let's go for `basic-setup`. As within our private Docker network the containers can be reached by using their service name, the Postgres connection string becomes `jdbc:postgresql://ldes-postgresdb:5432/basic-setup`.

For the port (`SERVER_PORT`) and sub-path (`SERVER_SERVLET_CONTEXTPATH`) on which the LDES Server is available we'll go for `80` respectively `/ldes`.  

> **Note** that we also need to specify the external base URL of the LDES so that we can follow the event stream from our local system (`LDESSERVER_HOSTNAME=http://localhost:9003/ldes`) because we set a sub-path (`SERVER_SERVLET_CONTEXTPATH=/ldes`). Of course if we would change the server's [external port number](./docker-compose.yml#L23) in the Docker compose file, we need to change it here as well.

## Create the LDIO Workbench Configuration File
For the workbench configuration file we can start from the [configuration](../minimal-workbench/config/application.yml) we used for the [minimal workbench tutorial](../minimal-workbench/README.md) but we serve the pipelines on a different port (`80`).

The workbench allows for dynamically creating pipelines so we create a pipeline definition which we will send to the workbench. As we are now creating an integrated setup, we will not send the generated members to the container log using the `ConsoleOut` component, but instead we use the `LdioHttpOut` component. This component allows us to send the member to the LDES server ingest endpoint over HTTP. How do we determine this HTTP ingest endpoint? Because the LDIO Workbench and the LDES Server share the same private network, the workbench can address the server using its service name `ldes-server` as server path `http://ldes-server`. As we have set the sub-path to serve all event streams from `/ldes` we append that to the server path. Finally, as we [define](./definitions/occupancy.ttl) our LDES in the same way as we did in the [minimal server tutorial](../minimal-server/README.md), we need to append the name of the LDES (`/occupancy`). Putting all of this together, in this tutorial the HTTP ingest endpoint for our LDES becomes `http://ldes-server/ldes/occupancy`. The configuration for our output thus becomes:

```yaml
outputs:
  - name: Ldio:HttpOut
    config:
      endpoint: http://ldes-server/ldes/occupancy
      rdf-writer:
        content-type: application/n-triples
```

> **Note** that we can use the `rdf-writer.content-type` setting to change the RDF format used when sending the member to the LDES Server ingest endpoint. By default it is [Turtle](https://en.wikipedia.org/wiki/Turtle_(syntax)) (`text/turtle`) but here we choose [N-triples](https://en.wikipedia.org/wiki/N-Triples) (`application/n-triples`) as this is faster than any other RDF serialization both when writing and parsing.

In our minimal workbench tutorial we assumed that we had linked data and we POST'ed a message formatted as [JSON-LD](https://json-ld.org/) to the workbench. Usually, you will have data in a more traditional (non-linked data) model. Typically there will be an API that you can poll or maybe the source system will notify you of changes using messages. No matter if the interface is pull-driven or push-driven, the data will be format using JSON, XML, CSV or similar. Now, let's assume that on the input side we have a [JSON message](./data/message.json) that is pushed into the workbench pipeline. We need to turn this non-linked data into linked-data. To accomplish this we can attach a JSON-LD context to the message. To do so, we need to use a `JsonToLdAdapter` in the `LdioHttpIn` component and configure it with our context (which we can inline). We end up with the resulting [pipeline definition](./workbench/definitions/pipeline.yml).

## Bringing it All Together
Now that we have everything set up, let's test the systems. We need to bring all systems up, wait for both the LDIO Workbench and LDES Server to be available, send the LDES and view definitions to the server and finally send the JSON message to the workbench. Then we can retrieve the LDEs, the view and the page containing the actual member.

To run the systems, wait, send definitions and message (execute in a **bash** shell):
```bash
clear

# bring the systems up
docker compose up -d --wait

# define the LDES
curl -X POST -H "content-type: text/turtle" "http://localhost:9003/ldes/admin/api/v1/eventstreams" -d "@./definitions/occupancy.ttl"

# define the view
curl -X POST -H "content-type: text/turtle" "http://localhost:9003/ldes/admin/api/v1/eventstreams/occupancy/views" -d "@./definitions/occupancy.by-page.ttl"

# define the pipeline
curl -X POST -H "content-type: application/yaml" http://localhost:9004/admin/api/v1/pipeline --data-binary @./definitions/park-n-ride-pipeline.yml

# send the message
curl -X POST -H "Content-Type: application/json" "http://localhost:9004/park-n-ride-pipeline" -d "@./data/message.json"
```

> **Note** that we send the definitions to `http://localhost:9003/ldes` because we have defined `LDESSERVER_HOSTNAME: /ldes` in the Docker compose file.

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
