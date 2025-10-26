FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    sudo python3 python3-pip build-essential cmake ca-certificates libssl-dev git \
    && apt-get clean

# Create workspace
WORKDIR /
#COPY . .
RUN git clone https://github.com/p4lang/open-p4studio.git

WORKDIR /open-p4studio
RUN ./p4studio/p4studio profile apply --jobs 12 ./p4studio/profiles/docker.yaml

# Set environment variablesb 
ENV SDE=/open-p4studio
ENV SDE_INSTALL=/open-p4studio/install

# Create the symlink
RUN ln -s $SDE_INSTALL/bin/p4c $SDE_INSTALL/bin/bf-p4c || true

CMD ["/bin/bash"]
