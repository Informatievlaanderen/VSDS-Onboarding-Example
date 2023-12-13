# Onboarding Example - a Practical Guide to Publishing and Consuming a LDES
This sample project describes step by step how to publish data as [LDES](https://semiceu.github.io/LinkedDataEventStreams/) and how that [linked data](https://en.wikipedia.org/wiki/Linked_data) can be consumed.

## Example Data Set
We start from a continuous feed of data containing the real time occupancy of park & ride locations in Ghent found [here](https://data.stad.gent/explore/dataset/real-time-bezetting-pr-gent/information/). The data is updated every couple of minutes. We will use this data set as an example because it allows us to showcase what LDES is made for: replicating a (historical) data set and synchronize updates on a continuous basis. In addition, the data set also contains geographical information which will allow us to showcase the ability to retrieve a subset of data based on geography in addition to the time axis. Because the dataset grows very rapidly, we will show how to keep storage under control. For simplicity we will start with a simple linked data model and migrate it to an official linked data vocabulary to allow ingesting another data set from the same domain found [here](https://data.stad.gent/explore/dataset/bezetting-parkeergarages-real-time/information/?sort=-occupation) in the same LDES.

## Prerequisites
To follow along and play with the examples you will need some knowledge of [Docker](https://www.docker.com/), [Docker Compose](https://docs.docker.com/compose/) and [git](https://git-scm.com/). You will also need an editor such as [VSCodium](https://vscodium.com/) (or [VS Code](https://code.visualstudio.com/) if you really insist). And obviously, you need an open mind and feel like diving into the wonderful world of linked data and RDF.

### Git
To download and use this repository you will need to install [Git](https://git-scm.com/downloads).

### Bash
In order to run the commands in the tutorials you will to run them in a bash shell. On Windows, you need to use the [Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/about). This is also needed for Docker (see later). On MacOS, you can use the standard Z shell (zsh). Finally, on Linux, the bash shell is available by default.

### Visual Studio Code
You can use any editor or development environment that you like to look at the source files. However, Visual Studio Code and its open source alternative VSCodium offer a few nice features, such as previewing this and other markdown files as well as to manage [Docker](https://code.visualstudio.com/docs/containers/overview) and [Git](https://code.visualstudio.com/docs/sourcecontrol/overview) from within the environent.

### Docker
To try the examples yourself, you will also need to install [Docker Desktop](https://www.docker.com/products/docker-desktop/) on your [Windows](https://docs.docker.com/desktop/install/windows-install/) or [MacOS](https://docs.docker.com/desktop/install/mac-install/). If you have a Linux system, you can either use the [desktop](https://docs.docker.com/desktop/install/linux-install/) or the [server](https://docs.docker.com/engine/install/) version.

## Where to start?
We suggest you look at the examples in the following order, but of course, feel free to skip parts if you are already familiar with some topics.

* [Setting up a minimal LDES server](./minimal-server/README.md)
* [Setting up a minimal LDIO Workbench](./minimal-workbench/README.md)
* [Publishing a simple data set with a basic setup](./basic-setup/README.md)
* [Publishing as a standard open linked data model](./advanced-conversion/README.md)

We will cover many more topics in the (near) future, so stay tuned to get answers to the following questions:
* as a Data Publisher, how do I keep my storage and bandwidth costs under control?
* as a Data Publisher, how do I make my LDES discoverable?
* as a Data Client, how do I consume an LDES?
* as a Data Broker, how do I offer different views on an LDES?
* as a Data Publisher, how do I offer a non-free data set as a LDES?
* ...
