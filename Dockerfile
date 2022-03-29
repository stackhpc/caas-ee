#####
# Dockerfile for the CaaS Ansible Execution Environment
#
# This is primarily for use with AWX but can also be used with ansible-runner standalone
#
# It was *mostly* generated using ansible-builder, but with the ADD/COPY statements
# modified to use the files in place
#####

ARG EE_BASE_IMAGE=quay.io/ansible/ansible-runner:stable-2.12-devel
ARG EE_BUILDER_IMAGE=quay.io/ansible/ansible-builder:latest

FROM $EE_BASE_IMAGE as galaxy
ARG ANSIBLE_GALAXY_CLI_COLLECTION_OPTS=
USER root

WORKDIR /build
COPY requirements.yml .

RUN ansible-galaxy role install \
      -r requirements.yml \
      --roles-path /usr/share/ansible/roles
RUN ansible-galaxy collection install \
      $ANSIBLE_GALAXY_CLI_COLLECTION_OPTS \
      -r requirements.yml \
      --collections-path /usr/share/ansible/collections

FROM $EE_BUILDER_IMAGE as builder

COPY --from=galaxy /usr/share/ansible /usr/share/ansible

COPY requirements.txt .
COPY bindep.txt .
RUN ansible-builder introspect \
      --sanitize \
      --user-pip=requirements.txt \
      --user-bindep=bindep.txt \
      --write-bindep=/tmp/src/bindep.txt \
      --write-pip=/tmp/src/requirements.txt
RUN assemble

FROM $EE_BASE_IMAGE
USER root

COPY --from=galaxy /usr/share/ansible /usr/share/ansible

COPY --from=builder /output/ /output/
RUN /output/install-from-bindep && rm -rf /output/wheels

RUN alternatives --set python /usr/bin/python3
COPY --from=quay.io/ansible/receptor:devel /usr/bin/receptor /usr/bin/receptor
RUN mkdir -p /var/run/receptor

USER 1000
CMD ["ansible-runner", "worker", "--private-data-dir=/runner"]
