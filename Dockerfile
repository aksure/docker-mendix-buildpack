# Dockerfile to create a Mendix Docker image based on either the source code or
# Mendix Deployment Archive (aka mda file)
#
# Author: Mendix Digital Ecosystems, digitalecosystems@mendix.com
# Version: 1.5
FROM balenalib/raspberry-pi-debian-openjdk:latest
#This version does a full build originating from the Ubuntu Docker images
LABEL Author="Mendix Digital Ecosystems"
LABEL maintainer="digitalecosystems@mendix.com"

# Set the locale
RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LC_ALL en_US.UTF-8 

# When doing a full build: install dependencies & remove package lists
RUN apt-get -q -y update && \
 DEBIAN_FRONTEND=noninteractive apt-get upgrade -q -y && \
 DEBIAN_FRONTEND=noninteractive apt-get install -q -y python3 wget curl libgdiplus libpq5 && \
 rm -rf /var/lib/apt/lists/*

# Build-time variables
ARG BUILD_PATH=project
ARG DD_API_KEY

# Checkout CF Build-pack here
RUN mkdir -p buildpack/.local && \
   (wget -qO- https://github.com/mxclyde/cf-mendix-buildpack/archive/pi.tar.gz \
   | tar xvz -C buildpack --strip-components 1)

# Copy python scripts which execute the buildpack (exporting the VCAP variables)
COPY scripts/compilation /buildpack

# Add the buildpack modules
ENV PYTHONPATH "/buildpack/lib/"

# Create the build destination
RUN mkdir build cache
COPY $BUILD_PATH build

# Compile the application source code and remove temp files
WORKDIR /buildpack
RUN chmod +x /buildpack/compilation
RUN "/buildpack/compilation" /build /cache && \
  rm -fr /cache /tmp/javasdk /tmp/opt

# Expose nginx port
ENV PORT 80
EXPOSE $PORT

RUN mkdir -p "/.java/.userPrefs/com/mendix/core"
RUN mkdir -p "/root/.java/.userPrefs/com/mendix/core"
RUN ln -s "/.java/.userPrefs/com/mendix/core/prefs.xml" "/root/.java/.userPrefs/com/mendix/core/prefs.xml"

# Start up application
COPY scripts/ /build
WORKDIR /build
RUN chmod u+x startup
ENV INITSYSTEM=on
ENTRYPOINT ["/build/startup","/buildpack/start.py"]
