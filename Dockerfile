FROM ubuntu:18.04 as builder
MAINTAINER Daniel Guerra

# Install packages

ENV DEBIAN_FRONTEND noninteractive
RUN sed -i "s/# deb-src/deb-src/g" /etc/apt/sources.list
RUN apt-get -y update
RUN apt-get -yy upgrade
ENV BUILD_DEPS="git autoconf pkg-config libssl-dev libpam0g-dev \
  libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
  bison libxml2-dev dpkg-dev libcap-dev"
RUN apt-get -yy install  sudo apt-utils software-properties-common $BUILD_DEPS


# Build xrdp

WORKDIR /tmp
RUN apt-get source pulseaudio
RUN apt-get build-dep -yy pulseaudio
WORKDIR /tmp/pulseaudio-11.1
RUN dpkg-buildpackage -rfakeroot -uc -b
WORKDIR /tmp
RUN git clone --branch devel --recursive https://github.com/neutrinolabs/xrdp.git
WORKDIR /tmp/xrdp
RUN ./bootstrap
RUN ./configure
RUN make
RUN make install
WORKDIR /tmp
RUN  apt -yy install libpulse-dev
RUN git clone --recursive https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
WORKDIR /tmp/pulseaudio-module-xrdp
RUN ./bootstrap && ./configure PULSE_DIR=/tmp/pulseaudio-11.1
RUN make
RUN mkdir -p /tmp/so
RUN cp src/.libs/*.so /tmp/so

FROM ubuntu:18.04
ARG ADDITIONAL_PACKAGES=""
ENV ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES}
ENV DEBIAN_FRONTEND noninteractive
RUN apt update && apt install -y software-properties-common
RUN add-apt-repository "deb http://archive.canonical.com/ $(lsb_release -sc) partner" && apt update
RUN apt -y full-upgrade && apt install -y \
  adobe-flashplugin \
  browser-plugin-freshplayer-pepperflash \
  ca-certificates \
  crudini \
  firefox \
  less \
  locales \
  openssh-server \
  pulseaudio \
  sudo \
  supervisor \
  uuid-runtime \
  vim \
  vlc \
  wget \
  xauth \
  xautolock \
  xfce4 \
  xfce4-clipman-plugin \
  xfce4-cpugraph-plugin \
  xfce4-netload-plugin \
  xfce4-screenshooter \
  xfce4-taskmanager \
  xfce4-terminal \
  xfce4-xkb-plugin \
  xorgxrdp \
  xprintidle \
  xrdp \
  $ADDITIONAL_PACKAGES && \
  apt-get remove -yy xscreensaver && \
  apt-get autoremove -yy && \
  rm -rf /var/cache/apt /var/lib/apt/lists && \
  mkdir -p /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-sink.so /var/lib/xrdp-pulseaudio-installer
ADD bin /usr/bin
ADD etc /etc
ADD autostart /etc/xdg/autostart
#ADD pulse /usr/lib/pulse-10.0/modules/

# Add Wine
# For Ubuntu 20
# RUN dpkg --add-architecture i386
# RUN wget -qO- https://dl.winehq.org/wine-builds/Release.key | sudo apt-key add -
# RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv F987672F
# RUN apt-add-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ bionic main'  && apt-get update -y
# RUN apt-get install -y --install-recommends winehq-stable
# For Ubuntu 18.4
RUN dpkg --add-architecture i386
RUN apt update -y
RUN wget -qO- https://dl.winehq.org/wine-builds/winehq.key | sudo apt-key add -
RUN apt install -y software-properties-common
RUN apt-add-repository 'deb http://dl.winehq.org/wine-builds/ubuntu/ bionic main'
RUN wget -qO- https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_18.04/Release.key | sudo apt-key add -
RUN sh -c 'echo "deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_18.04/ ./" > /etc/apt/sources.list.d/obs.list'
RUN apt update -y
RUN apt-get install -y --install-recommends winehq-stable


# Configure
RUN mkdir /var/run/dbus && \
  cp /etc/X11/xrdp/xorg.conf /etc/X11 && \
  sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config && \
  sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini && \
  locale-gen en_US.UTF-8 && \
  echo "xfce4-session" > /etc/skel/.Xclients && \
  cp -r /etc/ssh /ssh_orig && \
  rm -rf /etc/ssh/* && \
  rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem

# Docker config
VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]
