# Setting Up a Minimal LDES Client
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

The LDES CLient component is packaged as a [LDIO input component](https://github.com/Informatievlaanderen/VSDS-Linked-Data-Interactions/tree/main/ldi-orchestrator/ldio-connectors/ldio-ldes-client) as well as a [NiFi processor](https://github.com/Informatievlaanderen/VSDS-Linked-Data-Interactions/tree/main/ldi-nifi/ldi-nifi-processors/ldes-client-processor) and comes as part of their respective docker images ([LDIO workbench](https://hub.docker.com/r/ldes/ldi-orchestrator) and [Nifi workbench](https://hub.docker.com/r/ldes/ldi-workbench-nifi)). Both components act as the initial part of a data pipeline and need sink component which receives the extracted collection members which as you already know are version objects. But if you do not need the history of state changes you need a way to revert these version objects back to their corresponding state object. This process of converting such a _version object_ back to a _state object_ we call _version materialization_, and as it happens we have a component laying around that you can use to do exactly that.

> **Note**: currently the LDES Client outputs a stream of version objects and you need to add a transformation step in your data pipeline to do version materialization. In the future we will likely add the option to immediately output state objects instead, or even default to that with the option to output the version objects in you do need the history. Stay tuned.

No doubt you are thinking by now: 'yeah, yeah, enough with that, just show me how!' OK then, if you insist...

## Get Your Motor Runnin'
For the LDES we can simply use the [parking lot example](../advanced-conversion/README.md). For this LDES we know that there is only one view, i.e. `http://localhost:9003/ldes/occupancy/by-page`. 

Go ahead and open a command shell at the parking lot example and run it so that we have a LDES to work with. Done? Let's continue then.

Now what do we need for our minimal LDES Client example? Really not that much! We obviouly need a workbench (e.g. LDIO) containing one pipeline which starts with a [LDES Client component](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/ldio/ldio-inputs/ldio-ldes-client) and outputs the members to a sink. Unless we want to convert to state objects, we do not need a [Version Materializer](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/ldio/ldio-transformers/ldio-version-materializer) transformer. For the sink we can use a webhook such as https://webhook.site/ or https://public.requestbin.com/ or any other similar online or offline service (e.g. our [message sink](https://github.com/Informatievlaanderen/VSDS-LDES-E2E-message-sink)). You can use any sink for which we have an [output component](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/ldio/ldio-outputs/index). We will be using the HTTP protocol in this tutorial so we can use a [HTTP output component](https://informatievlaanderen.github.io/VSDS-Linked-Data-Interactions/ldio/ldio-outputs/ldio-http-out) to output member to the sink where we can inspect.

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
  endpoint: https://webhook.site/287d6ad6-b339-42fc-8b5e-297714ac688c
```
It is as simple as the input part!

OK, OK, if you look at the [workbench configuration](./application.yml) you will notice that it is a bit more elaborate than the above:
```yaml
- name: client-pipeline
  description: "Requests all existing members from a public LDES server and keeps following it for changes, sending each member as-is to a webhook"
  input:
    name: Ldio:LdesClient
    config:
      urls: 
        - ${LDES_SERVER_URL}
      sourceFormat: application/n-quads
  outputs:
    - name: Ldio:HttpOut
      config:
        endpoint: ${SINK_URL}
        rate-limit:
          enabled: true
          max-requests-per-minute: ${MAX_REQUESTS_PER_MINUTE}
```
But that is because we made it a bit more generic by using environment variables for the LDES Client `url` and the HTTP output `endpoint`. In addition, we added the `sourceFormat: application/n-quads` to request the LDES nodes as N-quads instead of the default format JSON-LD because N-quads can be parsed way faster. Finally we also added the `rate-limit` section because depending on which online sink service you use, you may be limited into how many HTTP requests you can send to it (usually a free sink service is limited to a minimal amout, e.g. 50 requests/minute). But in the end let's be honest: it is not that complicated.

The [docker compose](./docker-compose.yml) file isn't all that scary either. We just need one workbench service which looks like this:
```yaml
ldio-workbench:
  container_name: basic-client_ldio-workbench
  image: ldes/ldi-orchestrator:2.0.0-SNAPSHOT # you can safely change this to the latest 1.x.y version
  environment:
    - LDES_SERVER_URL=${LDES_SERVER_URL:-http://localhost:9003/ldes/occupancy/by-page}
    - SINK_URL=${SINK_URL}
    - MAX_REQUESTS_PER_MINUTE=${MAX_REQUESTS_PER_MINUTE:-50}
  volumes:
    - ./application.yml:/ldio/application.yml:ro
  network_mode: "host"
```
We give the container a name and use a recent [LDIO image](https://hub.docker.com/r/ldes/ldi-orchestrator/tags) from docker hub. We also define and pass the required environment variables and provide defaults for all but the sink URL because you will get a unique URL when you use an online service such as [Webhook](https://webhook.site/) or [Pipedream](https://public.requestbin.com/). We provide the workbench configuration to the container by volume mapping it (read-only).

Hmmm, what is that last line `network_mode: "host"` all about? Well, as stated before, the links in the LDES nodes will be absolute URLs as defined by the `ldes-server.host-name` entry in the [LDES Server configuration file](../advanced-conversion/server/application.yml) which in this case is `http://localhost:9003/ldes`. Because we have exposed the LDES Server to the host system (basically your system) you can request the LDES view and all the nodes from your (host) system just fine. However, the `localhost` is a special name which always resolves to IP address 127.0.0.1 as it maps the the loopback adapter of your network card. Essentially, if using its own network, when the LDES Client tries to request a LDES node located on `localhost` it will get back it's loopback address 127.0.0.1 instead of the IP address of the LDES Server. So, the trick we use here is to let the workbench containing our LDES Client share the network of your system (the host) allowing it to resolve to the host network stack and then because of the docker port mapping, your docker will do its magic and forward the HTTP request to the LDES Server container. This is a bit of hocus-pocus that we need in this tutorial because we run our LDES Server locally and do not expose it using a domain name. In real-life you will not have to do this. In fact, if you would use a LDES which is hosted on the web in this tutorial you could comment out or remove the last line.

OK, and now for the missing link: where can you define the mandatory sink URL? Well, that again is docker magic. When you execute docker compose CLI commands docker looks for and uses a file named `.env` which should contain the required environment variables. Actually you can use any other file but then you have to pass the name and location of that file to the docker CLI command by additing the `--env-file` option, e.g. `--env-file user.env`. We have provided a [.env](./.env) file. You can fill in the sink URL there and run all docker CLI commands as-is or copy this file to some other file (e.g. `user.env`) and pass that file to the docker CLI commands as explained. This is the preferred way to make it explicit that you are providing environment variables which are not provided by default in the docker compose file. So let's do that.

Please open https://webhook.site/ in a browser windows and copy your unique URL. Copy the `.env` file to `user.env` and fill in your unique URL as the sink URL.

> **Note** that it is a good idea to open the sink in a browser tab which does not store cookies, e.g. Firefox's private window, Chrome ingocnito tab, etc. just in case you hit a rate limit while trying to run this tutorial. In case you experience this issue you can simply close this browser window and open a new one. That way you will get a new fresh sink unaware of the previous rate limit issue.

Now you can run the example using the following command (in a bash shell):
```bash
clear
docker compose --env-file user.env up
```
> **Note** that this will start the workbench in the shell and not as a deamon as we did not add the deamon option (`-d`) to the command.

Once started you will see that the LDES Clients starts following the LDES view:
```text
basic-client_ldio-workbench  | 2024-01-23T20:07:16.870Z  INFO 1 --- [           main] b.v.i.ldes.ldio.Application              : Started Application in 6.121 seconds (process running for 6.823)
basic-client_ldio-workbench  | 2024-01-23T20:07:17.304Z  INFO 1 --- [pool-6-thread-1] l.c.s.StartingTreeNodeFinder             : determineStartingTreeNode for: http://localhost:9003/ldes/occupancy/by-page
basic-client_ldio-workbench  | 2024-01-23T20:07:17.685Z  INFO 1 --- [pool-6-thread-1] l.c.s.StartingTreeNodeFinder             : Parsing response for: http://localhost:9003/ldes/occupancy/by-page
```

Almost immediately you should see the members start appearing in the online sink. After a little bit, the sink stops receiving members. You have now succesfully _replicated_ the data collection. However, our [parking lot workbench](../advanced-conversion/workbench/application.yml) polls the source system frequently and generates 5 new version objects (almost) on each run. So, every 2 minutes you can see these new versions appear in the sink. You are now _synchronizing_ the data collection forever, that is, until the LDES Server system is stopped.

## And Now, The End Is Near
Because we did not run the docker container as a deamon, in order to stop the container you need to press `CTRL-C`.

To bring the containers down:
```bash
docker compose rm ldio-workbench --stop --force --volumes
```

Of course, you also need to bring down the [LDES Server and related containers](../advanced-conversion/README.md#every-end-is-a-new-beginning).

Most webhook services will automatically delete the requests after some time but it is best to cleanup yourself. For webhook.site choose the `Delete all requests...` option under the `More` menu and confirm the removal of all requests. You can now close the browser window.
