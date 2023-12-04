# Onboarding Example - a Practical Guide to Publishing and Consuming a LDES
This sample project describes step by step how to publish data as [LDES](https://semiceu.github.io/LinkedDataEventStreams/) and how that [linked data](https://en.wikipedia.org/wiki/Linked_data) can be consumed.

## Example Data Set
We start from a continuous feed of data containing the real time occupancy of park & ride locations in Ghent found [here](https://data.stad.gent/explore/dataset/real-time-bezetting-pr-gent/information/). The data is updated every couple of minutes. We will use this data set as an example because it allows us to showcase what LDES is made for: replicating a (historical) data set and synchronize updates on a continuous basis. In addition, the data set also contains geographical information which will allow us to showcase the ability to retrieve a subset of data based on geography in addition to the time axis. Because the dataset grows very rapidly, we will show how to keep storage under control. For simplicity we will start with a simple linked data model and migrate it to an official linked data vocabulary to allow ingesting another data set from the same domain found [here](https://data.stad.gent/explore/dataset/bezetting-parkeergarages-real-time/information/?sort=-occupation) in the same LDES.

## Pre-requisites
To follow along and play with the examples you will need some knowledge of [Docker](https://www.docker.com/), [Docker Compose](https://docs.docker.com/compose/) and [git](https://git-scm.com/). You will need an editor such as [VSCodium](https://vscodium.com/) (or [VS Code](https://code.visualstudio.com/) if you really insist). And obviously, you need an open mind and feel like diving into the wonderful world of linked data and RDF.

## Where to start?
We suggest you look at the examples in the following order, but of course, feel free to skip parts if you are already familiar with some topics.

* [Setting up a minimal LDES server](./minimal-server/README.md)
* [Setting up a minimal Workbench](./minimal-workbench/README.md)
* [Publishing a simple data set with a basic setup](./basic-setup/README.md)
