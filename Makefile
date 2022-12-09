

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build-image:  ## Build docker image
	docker build -t jsvisa/ethereum-tsdb:$(VERSION) .
	docker tag jsvisa/ethereum-tsdb:$(VERSION) jsvisa/ethereum-tsdb:latest
