#
# DO NOT REMOVE COMMENT
# image: metacontroller
#
ARG REGISTRY=''
ARG PROJECT=metacontroller
ARG AUTHZ_CONTROLLER_BUILD_VERSION=latest
FROM ${REGISTRY}${PROJECT}/authz_controller_build:$AUTHZ_CONTROLLER_BUILD_VERSION as metacontroller

COPY . /go/src/k8s.io/metacontroller/
WORKDIR /go/src/k8s.io/metacontroller/
RUN dep ensure && go install

FROM debian:stretch-slim
COPY --from=build /go/bin/metacontroller /usr/bin/
RUN apt-get update && apt-get install --no-install-recommends -y ca-certificates && rm -rf /var/lib/apt/lists/*
CMD ["/usr/bin/metacontroller", "--logtostderr", "-v=4", "--discovery-interval=20s"]
