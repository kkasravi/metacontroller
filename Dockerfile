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
RUN dep ensure && go build -gcflags "all=-N -l" -a -o /go/bin/metacontroller .
RUN cp /go/bin/metacontroller /usr/bin
CMD ["/usr/bin/metacontroller"]
