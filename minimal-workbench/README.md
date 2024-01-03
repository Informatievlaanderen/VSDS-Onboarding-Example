# Setting Up a Minimal LDIO Workbench
This quick start guide will show you how to setup a minimal workbench to create version objects from state objects.

Please see the [introduction](../README.md) for the example data set and pre-requisites, as well as an overview of all examples.

## Show Me Your Workbench
The LDES Server allows to ingest version objects but typically the source data represents the state of an object and not a version in time of this state. That is why a data transformation is needed to create such a version object.

Such a data transformation can be standalone or as part of a data transformation pipeline which can be build in various ways with many different data processing systems.

One such a workbench that allows to create data pipelines is [Apache NiFi](https://nifi.apache.org/). This is a mature and solid open-source solution that comes with many features, allows for horizontal scaling and comes with many standard processors for creating and monitoring complex data pipelines. However, it also comes with a steep learning curve and some other drawbacks. 

The Linked Data Interactions Orchestrator ([LDIO](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/) is a simple and more light-weight solution that eases the process of creating more straightforward, linear data transformations while requiring minimal resources and attempting to keep the learning curve as low as possible. It is by no means a silver bullet but experience has learned us that most data publishing use cases can easy be covered with a simple linear pipeline and as such LDIO usually suffies.

LDIO allows to create one or more synchronous linear pipelines that convert linked and non-linked data to version objects that can be ingested by an LDES Server. It is centered around the concept of one input source with an adaptor to convert to linked data, one or more in-memory transformation steps and sending the result to one or more output sinks.

Various input components are available for starting a pipeline such as: accepting HTTP messages both using a push model (HTTP listener) and a pull model (HTTP poller), reading from Kafka, etc.

If the source data is already linked data you can use a simple RDF adaptor which allows to parse various RDF serializations. If the source data is not yet linked data you can use either a JSON-LD adaptor to attach a JSON-LD context to a JSON message or alternatively a RML adaptor, which allows to create linked data from various other message formats, such as JSON, XML, CSV, etc.

On the output side we also provide several possibilities such as POST-ing using HTTP, writing to Kafka, etc.

We provide several transformation components for manipulating linked data but most data transformations can be done using a SPARQL construct transformation step. In addition, we also provide some components for more specific tasks such as enriching the data from some external HTTP source, converting GeoJson to Well Known Text (WKT), etc.

All these components are provided as part of the LDIO workbench which is packaged as a Docker image. The Docker images are available on [Docker Hub](https://hub.docker.com/r/ldes/ldi-orchestrator). The stable releases can be found [here](https://hub.docker.com/r/ldes/ldi-orchestrator/tags).

## Configure Your First Pipeline
The example [docker compose file](./docker-compose.yml) only contains a LDIO service which runs in a private network and uses volume mapping to have its configuration file available in the container. As we will see in a minute, the pipeline starts with a HTTP listener and therefore we need a port mapping to allow the workbench to receive HTTP messages.

The [workbench configuration file](./config/application.yml) starts with specifying the port on which the HTTP listener will accept requests. We have used the default port number 8080 and could have easily omitted it from te configuration. Other than that, we only need to specify the actual pipeline definition.

> **Note** that the workbench can contain more than one pipeline if needed.

The pipeline definition starts with a name and a description. The latter is purely for documentation purposes, but the former is used as the base path on which the HTTP listener receives requests. In our case this is (based on the docker compose port mapping): http://localhost:9004/p+r-pipeline. After that the definition continues with the input component and associated adapter, the transformation steps and the output(s). Let's look at these in more detail.

The input component simply states that it is a HTTP listener which uses a RDF adaptor and as such is expecting Linked Data:
```yaml
input:
  name: be.vlaanderen.informatievlaanderen.ldes.ldio.LdioHttpIn
  adapter:
    name: be.vlaanderen.informatievlaanderen.ldes.ldi.RdfAdapter
```

We need a transformation step to turn the linked data state object which we receive into a version object. We need to specify for which object type we need to change it to a version object. We use this type to retrieve that object's identifier and create the version object ID based on this identifier concatenated with the delimiter and the value of the `date-observed-property`. We also use the identifier to add a property as specified by `versionOf-property` to the version object. Finally, we also use the `date-observed-property` value to add a property as defined by the `generatedAt-property` to the version object. This sounds way more complicated than it actually is as we will show later. 
```yaml
transformers:
  - name: be.vlaanderen.informatievlaanderen.ldes.ldi.VersionObjectCreator
    config:
      member-type: https://example.org/ns/mobility#offStreetParkingGround
      delimiter: "/"
      date-observed-property: <http://www.w3.org/ns/prov#generatedAtTime>
      generatedAt-property: http://www.w3.org/ns/prov#generatedAtTime
      versionOf-property: http://purl.org/dc/terms/isVersionOf
```

> **Note** that we used the `http://www.w3.org/ns/prov#generatedAtTime` property for both creating the version object ID as well as for the `generatedAt-property`. This will prevent creating another property with the same date/time value.  

Finally, the version object is output to the specified sink. For demo purposes we use a component that simply logs the member to the console, which for a Docker container results in its logs.
```yaml
outputs:
  - name: be.vlaanderen.informatievlaanderen.ldes.ldio.LdioConsoleOut 
```

## Launch the Magic
After this long introduction let's get our hands dirty and see the magic in action.

To start the workbench and wait until it is available:
```bash
docker compose up -d
while ! docker logs $(docker ps -q -f "name=ldio-workbench$") 2> /dev/null | grep 'Started Application in' ; do sleep 1; done
```

There is no visual component yet for the LDIO workbench, but you can check its status at http://localhost:9004/actuator/health.

## You've Got Mail
Now that the workbench is up and running we can send a [message](./data/message.jsonld) through the pipeline and see its version object outputted to the workbench logs. We use the following simple JSON-LD message (clipped to the relevant parts):
```json
{
    "@context": {
        "@vocab": "https://example.org/ns/mobility#",
        "urllinkaddress": "@id",
        "type": "@type",
        "lastupdate": {
            "@id": "http://www.w3.org/ns/prov#generatedAtTime",
            "@type": "http://www.w3.org/2001/XMLSchema#dateTime"
        }
    },
    "lastupdate": "2023-11-30T21:45:15+01:00",
    "type": "offStreetParkingGround",
    "urllinkaddress": "https://stad.gent/nl/mobiliteit-openbare-werken/parkeren/park-and-ride-pr/pr-gentbrugge-arsenaal",
    ...
}
``` 

> **Note**: do not worry if you do not understand every detail in the context part. Its main purpose is to add meaning to the state object properties.

To send the message into the pipeline:
```bash
curl -X POST -H "Content-Type: application/ld+json" "http://localhost:9004/p+r-pipeline" -d "@./data/message.jsonld"
```

Since it is a small and straight forward message the workbench log will almost immediately contain the version object. 

To watch the version object appear in the workbench log
```bash
docker logs -n 30 $(docker ps -q -f "name=ldio-workbench$")
```

You should see the following (clipped to the relevant parts):
```text
@prefix mobility:         <https://example.org/ns/mobility#> .
@prefix park-and-ride-pr: <https://stad.gent/nl/mobiliteit-openbare-werken/parkeren/park-and-ride-pr/> .
@prefix prov:             <http://www.w3.org/ns/prov#> .
@prefix rdf:              <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix terms:            <http://purl.org/dc/terms/> .

<https://stad.gent/nl/mobiliteit-openbare-werken/parkeren/park-and-ride-pr/pr-gentbrugge-arsenaal/2023-11-30T21:45:15+01:00>
        rdf:type                      mobility:offStreetParkingGround ;
        terms:isVersionOf             park-and-ride-pr:pr-gentbrugge-arsenaal ;
        prov:generatedAtTime          "2023-11-30T21:45:15+01:00"^^<http://www.w3.org/2001/XMLSchema#dateTime> ;
...
```

If you compare the generated member in the container log with the example that we process, you will notice that the state object ID (`park-and-ride-pr:pr-gentbrugge-arsenaal` or `http://stad.gent/nl/mobiliteit-openbare-werken/parkeren/park-and-ride-pr/pr-gentbrugge-arsenaal` in full) is a property (`terms:isVersionOf` or `http://purl.org/dc/terms/isVersionOf` in full) of the version object and the version ID (`https://stad.gent/nl/mobiliteit-openbare-werken/parkeren/park-and-ride-pr/pr-gentbrugge-arsenaal/2023-11-30T21:45:15+01:00`) is a combination of that state object ID, the delimiter (`/`) and the `prov:generatedAtTime` property (`2023-11-30T21:45:15+01:00`).


## That's All Folks
You now know how to configure a basic LDIO workbench which takes in RDF messages containing a single state object and turn it into a version object that can be ingested as a LDES member.

To bring the containers down and remove the private network:
```bash
docker compose down
```
