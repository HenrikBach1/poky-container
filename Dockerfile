# Copyright (C) 2015-2016 Intel Corporation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Since this Dockerfile is used in multiple images, force the builder to
# specify the BASE_DISTRO. This should hopefully prevent accidentally using
# a default, when another distro was desired.
ARG BASE_DISTRO=SPECIFY_ME
ARG BASE_DISTRO="ubuntu-20.04"

FROM crops/yocto:$BASE_DISTRO-base

USER root

ADD https://raw.githubusercontent.com/crops/extsdk-container/master/restrict_useradd.sh  \
        https://raw.githubusercontent.com/crops/extsdk-container/master/restrict_groupadd.sh \
        https://raw.githubusercontent.com/crops/extsdk-container/master/usersetup.py \
        /usr/bin/
COPY distro-entry.sh poky-entry.py poky-launch.sh /usr/bin/
COPY sudoers.usersetup /etc/

# For ubuntu, do not use dash.
RUN which dash &> /dev/null && (\
    echo "dash dash/sh boolean false" | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash) || \
    echo "Skipping dash reconfigure (not applicable)"

# We remove the user because we add a new one of our own.
# The usersetup user is solely for adding a new user that has the same uid,
# as the workspace. 70 is an arbitrary *low* unused uid on debian.
RUN userdel -r yoctouser && \
    mkdir /home/yoctouser && \
    groupadd -g 70 usersetup && \
    useradd -N -m -u 70 -g 70 usersetup && \
    chmod 755 /usr/bin/usersetup.py \
        /usr/bin/poky-entry.py \
        /usr/bin/poky-launch.sh \
        /usr/bin/restrict_groupadd.sh \
        /usr/bin/restrict_useradd.sh && \
    echo "#include /etc/sudoers.usersetup" >> /etc/sudoers

# Add pokyuser to sudoers
USER root
RUN useradd -p NOPASSWD pokyuser
RUN adduser pokyuser sudo
RUN echo '%sudo ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

# # Add usersetup to sudoers
# RUN useradd -p NOPASSWD usersetup
# RUN adduser usersetup sudo
# RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Add TUN for running Qemu: runqemu qemux86-64 x nographic
RUN mkdir -p /dev/net \
    mknod /dev/net/tun c 10 200 \
    chmod 600 /dev/net/tun \
    cat /dev/net/tun

RUN echo "Note:" \
    echo "Test this image with: cat /dev/net/tun" \
    echo "- If you receive the message: 'File descriptor in bad state*' then the TUN/TAP device is ready for use," \
    echo "- If you receive the message: 'No such device*' then the TUN/TAP device was not successfully created." \
    echo "Run this image in a privileged container." 

# For debugging in shell
RUN apt-get install -y iptables nano

USER usersetup
ENV LANG=en_US.UTF-8

ENTRYPOINT ["/usr/bin/distro-entry.sh", "/usr/bin/dumb-init", "--", "/usr/bin/poky-entry.py"]
