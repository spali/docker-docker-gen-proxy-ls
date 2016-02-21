NAME = spali/docker-gen-proxy-ls
VERSION = latest

.PHONY: all build

all: build

build:
	docker build -t $(NAME):$(VERSION) --rm .

