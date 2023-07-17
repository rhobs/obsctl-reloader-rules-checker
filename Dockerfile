FROM registry.ci.openshift.org/openshift/release:golang-1.19 as builder

WORKDIR /work

COPY . .

RUN make build

FROM registry.access.redhat.com/ubi8/ubi:latest

WORKDIR /install

COPY hack/install-yamllint-tool.sh .

RUN yum install python3.11 -y
RUN python3 -m ensurepip --upgrade
RUN ./install-yamllint-tool.sh

COPY --from=builder /work/bin/* /usr/bin/

WORKDIR /work
COPY .yamllint /
ENTRYPOINT ["/usr/bin/obsctl-reloader-rules-checker"]