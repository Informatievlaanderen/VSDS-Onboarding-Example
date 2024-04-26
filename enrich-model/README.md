# Enrich A Model
This tutorial will show you how to use a LDIO workbench to combine two linked data models in a pipeline.

Please see the [introduction](../README.md) for the pre-requisites, as well as an overview of all examples.

## Everybody’s Saying We Are the Perfect Combination
Imagine that you need to extend your data collection with some information that can be found in some external data source. You can use a workbench pipeline for this. Depending on the type of API available in the external data source we have some components available to help you. At this moment we support data sources that provide a [SPARQL](https://en.wikipedia.org/wiki/SPARQL) endpoint or have a HTTP based API.

In this tutorial we will assume that the external data source contains linked data that can be accessed using SPARQL. In that case we can use a [SPARQL federated query](https://www.w3.org/TR/sparql11-federated-query/) to select the missing information. To demonstrate this we will use a [graph database](https://en.wikipedia.org/wiki/Graph_database) containing some car related data, a workbench to hold and execute our pipeline processing car owners and a downstream sink system that will receive the enriched data model combining your car owner with information about the owned car(s).

## Let’s Chop It Up and Get to a Solution
Let us start by creating a [Docker compose file](./docker-compose.yml) which contains the required systems. Most of the configuration is the same as usual: we need a container name, define which docker image to use, tell the container which network to use and, if needed, we provide a health check to know when a system is fully available.

As said, we need a graph database in addition to a workbench and a sink system, all linked together with a custom docker network:

```yaml
networks:
  enrich-model:
    name: enrich-model-network
```

Because we will be processing very little data, it suffices to use an in-memory graph database. For this we choose the [RDF4J Server and Workbench](https://rdf4j.org/documentation/tools/server-workbench/):
```yaml
services:

  graph-database:
    container_name: enrich-model_graph-database
    image: eclipse/rdf4j-workbench:latest
    ports:
      - 9008:8080
    networks:
      - enrich-model
    healthcheck:
      test: ["CMD", "curl", "-f", "-s", "-H", "'application/sparql-results+xml'", "http://graph-database:8080/rdf4j-server/repositories"]
```
> **Note** that we expose the SPARQL endpoint port so we can manage and seed the database.

The workbench configuration is trivial as well:
```yaml
  ldio-workbench:
    container_name: enrich-model_ldio-workbench
    image: ldes/ldi-orchestrator:2.5.1-SNAPSHOT
    environment:
      - SERVER_PORT=80
      - LOGGING_LEVEL_ROOT=INFO
    ports:
      - 9006:80
    networks:
      - enrich-model
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://ldio-workbench/actuator/health"]
```
> **Note** that we fully configure our workbench by providing environment variables and therefore do not need to map a configuration file. We also map the workbench port so we can feed it with our data.

Finally, we need to configure our sink system:
```yaml
  sink-system:
    container_name: enrich-model_sink-system
    image: ghcr.io/informatievlaanderen/test-message-sink:latest
    ports:
      - 9007:80
    networks:
      - enrich-model
    environment:
      - MEMORY=true
      - MEMBER_TYPE=http://schema.org/Person
```
> **Note** that we use an in-memory sink expecting to receive our enriched data model of type `schema:Person`.

### You Got a Fast Car
Now that we have an empty graph database system we first need to create a repository (database) to hold our [car models](./data/cars.json) and put the data in it. To create the repository we simply send the [repository definition](./definitions/cars-repository.ttl) to the graph database API. 

To seed the car models we create a simple pipeline reading our JSON data, converting it to linked data and send it to our graph database:
```yaml
name: cars-pipeline # endpoint name for accepting our car models
input:
  name: Ldio:HttpIn # accept an array of car models
  adapter:
    name: Ldio:JsonToLdAdapter # convert to linked data
    config:
      context: |
        {
          "@context": {
            "@base": "http://example.com/cars/",
            "@vocab": "http://schema.org/",
            "id": "@id",
            "type": "@type",
            "max-speed": { "@id": "maxSpeed", "@type": "http://www.w3.org/2001/XMLSchema#integer" }
          }
        }
outputs:
  - name: Ldio:RepositoryMaterialiser # store in our graph database
    config:
      sparql-host: http://graph-database:8080/rdf4j-server
      repository-id: cars
      batch-size: 10
      batch-timeout: 1000
```

Let us have a closer look. We start by receiving a JSON message containing our [car models](./data/cars.json) collection. Because the message contains a JSON array, the `Ldio:JsonToLdAdapter` will automatically feed the pipeline with one item at the time, e.g.
```json
{
  "id": "reliant-robin",
  "type": "car",
  "brand": "Reliant",
  "model": "Robin",
  "max-speed": 136
}
```
In order to convert this model to linked data we use the following [JSON-LD context](https://www.w3.org/TR/json-ld11/#the-context):
```json
{
  "@context": {
    "@base": "http://example.com/cars/",
    "@vocab": "http://schema.org/",
    "id": "@id",
    "type": "@type",
    "max-speed": { "@id": "maxSpeed", "@type": "http://www.w3.org/2001/XMLSchema#integer" }
  }
}
```
Basically, we define a prefix for all identities which are relative URIs (`http://example.com/cars/`), we add a vocabulary (`http://schema.org/`) to prefix any property and type (e.g. `"@type": "car"`) which is not an absolute uri (e.g. `brand`). In addition, we map the identity and type predicates and we rename the `max-speed` property to `maxSpeed` and indicate it is an integer (`xsd:integer`). Applying this context to the example above, this results in (converted to [turtle](https://www.w3.org/TR/turtle/) for readability):
```text
@prefix schema: <http://schema.org/> .

<http://example.com/cars/reliant-robin>
  a schema:car ;
  schema:brand "Reliant" ;
  schema:maxSpeed 136 ;
  schema:model "Robin" .
```

After the car data is converted to linked data we send it to our graph database.

> **Note** that for the output to our graph database we set the `batch-size` and the `batch-timeout` (in milliseconds) because we want insert all our car models all at once (to minimize overhead and maximize throughput). The pipeline will try to buffer up to `batch-size` items and wait for `batch-timeout` time before sending the buffered items to the graph database.

### It’s a Kind of Magic
Now that we have seeded the graph database with our car models we are ready to create a pipeline that will accept our [person data](./data/person.json) and enrich it with the car model data. To turn our person model into linked data we can use the following JSON-LD context:
```json
{
  "@context": {
    "@base": "http://example.com/people/",
    "@vocab": "http://schema.org/",
    "id": "@id",
    "type": "@type",
    "job-title": "jobTitle",
    "cars": { 
      "@context": {"@base": "http://example.com/cars/"},
      "@id": "hasCar", 
      "@type": "@id"
    }
  }
}
```
Again we add a prefix for relative identities (`@base`) and a vocabulary (`@vocab`) for relative predicates & types as well as rename several predicates. The interesting part is the `cars` array: besides renaming it (to `hasCar`) we indicate that the items in the array are URIs (`"@type": "@id"`) and we add a different prefix for these identities (`"@base": "http://example.com/cars/"`). Applying this to our example person gives (in turtle):
```text
@prefix schema: <http://schema.org/> .

<http://example.com/people/SpideyBoy>
  schema:hasCar <http://example.com/cars/ferrari-f40>, <http://example.com/cars/volvo-xc40> ;
  schema:jobTitle "Spidey Boy" ;
  schema:name "Peter Parker" ;
  a schema:Person .
```

Now that we have our person as linked data, we can add the car information using a `Ldio:SparqlConstructTransformer`. We need to indicate that the triples should be added (`infer: true`) to the input model (our person) instead of replacing it. We use the following SPARQL to add the car details:
```text
PREFIX schema: <http://schema.org/>
CONSTRUCT {
  ?cs ?cp ?co .
}
WHERE { 
  ?ps schema:hasCar ?cs .
  SERVICE <http://graph-database:8080/rdf4j-server/repositories/cars> { ?cs ?cp ?co . }
}
```
What is this magic? Well, we select all triples containing a relation (`schema:hasCar`) between the person (i.e. person subject `?ps`) and a car (i.e. car subject `?cs`). For each car (`?cs`) we execute a SPARQL federated query (`SERVICE <endpoint> { ... }`) to select all its triples (`?cs ?cp ?co .` where `?cs` is the URI of the car) from our graph database (`http://graph-database:8080/rdf4j-server/repositories/cars`). That's it. Clean and simple!

Now that we have combine the person with the car data we forward it to our sink system. You can find the complete pipeline [here](./definitions/people-pipeline.yml).

## And I’m Picking Up the Pieces
We have the solution in place now and can launch the systems, configure them and seed the cars collection:
```bash
clear

# start all systems
docker compose up -d --wait

# configure graph repository
curl -X PUT http://localhost:9008/rdf4j-server/repositories/cars -H "Content-Type: text/turtle" --data-binary @./definitions/cars-repository.ttl

# upload our cars and people pipelines
curl -X POST http://localhost:9006/admin/api/v1/pipeline -H "content-type: application/yaml" --data-binary @./definitions/cars-pipeline.yml
curl -X POST http://localhost:9006/admin/api/v1/pipeline -H "content-type: application/yaml" --data-binary @./definitions/people-pipeline.yml

# seed the cars collection
curl -X POST http://localhost:9006/cars-pipeline -H "Content-Type: application/json" --data-binary @./data/cars.json
```

Ready to combine a person model with the car details? Simply send the test message to our people pipeline and check the result in the sink system:
```bash
# send some data
curl -X POST http://localhost:9006/people-pipeline -H "content-type: application/json" --data-binary @./data/person.json

# check enriched data
curl http://localhost:9007/member?id=http%3A%2F%2Fexample.com%2Fpeople%2FSpideyBoy
```

The result looks like this:
```text
@prefix :       <http://schema.org/> .
@prefix cars:   <http://example.com/cars/> .
@prefix rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix schema: <http://schema.org/> .

cars:volvo-xc40  rdf:type  schema:car;
        schema:brand     "Volvo";
        schema:maxSpeed  180;
        schema:model     "XC40" .

<http://example.com/people/SpideyBoy>
        rdf:type         schema:Person;
        schema:hasCar    cars:ferrari-f40 , cars:volvo-xc40;
        schema:jobTitle  "Spidey Boy";
        schema:name      "Peter Parker" .

cars:ferrari-f40  rdf:type  schema:car;
        schema:brand     "Ferrari";
        schema:maxSpeed  315;
        schema:model     "F40" .
```

## The End is Near
To bring all systems down:
```bash
docker compose down
```
