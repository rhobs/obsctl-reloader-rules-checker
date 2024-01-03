FROM registry.ci.openshift.org/openshift/release:golang-1.21 as builder

WORKDIR /work

COPY . .
RUN hack/use-goreleaser-build.sh

RUN make build

FROM registry.access.redhat.com/ubi8/ubi:latest

WORKDIR /install

COPY hack/install-yamllint-tool.sh .

RUN yum install python3.11 -y
RUN python3 -m ensurepip --upgrade
RUN ./install-yamllint-tool.sh

COPY --from=builder /go/bin/promtool /usr/bin/
COPY --from=builder /go/bin/pint /usr/bin/
COPY --from=builder /work/bin/obsctl-reloader-rules-checker /usr/bin/

WORKDIR /work
COPY .yamllint /
ENTRYPOINT ["/usr/bin/obsctl-reloader-rules-checker"]
