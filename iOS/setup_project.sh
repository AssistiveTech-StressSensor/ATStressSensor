#!/bin/bash

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path/StressSensorApp"

if [ ! -d ThirdPartyLibraries ]; then
	mkdir ./ThirdPartyLibraries
fi
cd ./ThirdPartyLibraries

if [ ! -f .lock ]; then
	rm -r ./*
	wget https://carlorapisarda.me/mirror/assistivetech/ThirdPartyLibraries.tgz
	tar -x -f ./ThirdPartyLibraries.tgz
	rm ./ThirdPartyLibraries.tgz
	touch .lock
fi

ls -la "$parent_path/StressSensorApp/ThirdPartyLibraries"


cd "$parent_path/StressSensorApp/StressSensorApp"

if [ ! -d Credentials ]; then
	mkdir ./Credentials
fi
cd ./Credentials

if [ ! -f .lock ]; then
	rm -r ./*
	cp ../../../DummyCredentials/* ./.
	touch .lock
fi

ls -la "$parent_path/StressSensorApp/StressSensorApp/Credentials"
