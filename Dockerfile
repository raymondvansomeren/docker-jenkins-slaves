FROM osrf/ros:melodic-desktop-full-stretch
MAINTAINER Rody Middelkoop <rody.middelkoop@gmail.com>

# Add locales after locale-gen as needed
# Upgrade packages on image
# Preparations for sshd
RUN apt-get -q update && \
    DEBIAN_FRONTEND="noninteractive" apt-get -q upgrade -y -o Dpkg::Options::="--force-confnew" --no-install-recommends &&\
    DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew"  --no-install-recommends openssh-server locales gnupg2 dirmngr &&\
    /usr/sbin/locale-gen en_US.UTF-8 &&\
    apt-get -q autoremove &&\
    apt-get -q clean -y && rm -rf /var/lib/apt/lists/* && rm -f /var/cache/apt/*.bin &&\
    sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd &&\
    mkdir -p /var/run/sshd

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN \
  apt-get -q update && \
  apt-get install -y wget && \
  echo "deb http://ppa.launchpad.net/linuxuprising/java/ubuntu bionic main" | tee /etc/apt/sources.list.d/linuxuprising-java.list && \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 73C3DB2A && \
  apt-get -q update && \
  echo oracle-java11-installer shared/accepted-oracle-license-v1-2 select true | /usr/bin/debconf-set-selections && \
  apt-get update && \
  apt-get install -y oracle-java11-installer oracle-java11-set-default && \
  rm -rf /var/lib/apt/lists/* && \/bin/bash -c '{ cd /tmp; rm -rf cppcheck-build cppcheck-1.81; curl -L http://github.com/danmar/cppcheck/releases/download/1.81/cppcheck-1.81.tar.gz | tar xz; mkdir cppcheck-build; cd cppcheck-build; cmake ../cppcheck-1.81/ -DCMAKE_BUILD_TYPE=Release -DHAVE_RULES=OFF; make; make install; cd; rm -rf /tmp/cppcheck-build /tmp/cppcheck-1.81;}' && \
  rm -rf /var/cache/oracle-jdk11-installer


# Define working directory.
WORKDIR /data

RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

RUN echo "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-5.0 main" >> /etc/apt/sources.list

RUN echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu xenial main" >> /etc/apt/sources.list

RUN /bin/echo -e -----BEGIN PGP PUBLIC KEY BLOCK-----\\n\\n\
mI0ESuBvRwEEAMi4cDba7xlKaaoXjO1n1HX8RKrkW+HEIl79nSOSJyvzysajs7zU\\n\
ow/OzCQp9NswqrDmNuH1+lPTTRNAGtK8r2ouq2rnXT1mTl23dpgHZ9spseR73s4Z\\n\
BGw/ag4bpU5dNUStvfmHhIjVCuiSpNn7cyy1JSSvSs3N2mxteKjXLBf7ABEBAAG0\\n\
GkxhdW5jaHBhZCBUb29sY2hhaW4gYnVpbGRziLYEEwECACAFAkrgb0cCGwMGCwkI\\n\
BwMCBBUCCAMEFgIDAQIeAQIXgAAKCRAek3eiup7yfzGKA/4xzUqNACSlB+k+DxFF\\n\
HqkwKa/ziFiAlkLQyyhm+iqz80htRZr7Ls/ZRYZl0aSU56/hLe0V+TviJ1s8qdN2\\n\
lamkKdXIAFfavA04nOnTzyIBJ82EAUT3Nh45skMxo4z4iZMNmsyaQpNl/m/lNtOL\\n\
hR64v5ZybofB2EWkMxUzX8D/FQ==\\n\
=LcUQ\\n\
-----END PGP PUBLIC KEY BLOCK-----\\n | apt-key add -

# Set user jenkins to the image
RUN useradd -m -d /home/jenkins -s /bin/bash jenkins &&\
    echo "jenkins:jenkins" | chpasswd

RUN echo ". /opt/ros/lunar/setup.bash" >> ~jenkins/.bashrc

RUN apt-get update && apt-get install -y git apt-utils libsdl2-dev qtbase5-dev

# Sonar Scanner
RUN apt-get update && apt-get install -y unzip wget bzip2 && wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-2.8.zip --quiet && unzip sonar-scanner-2.8.zip -d /opt && rm sonar-scanner-2.8.zip

COPY "sonar-scanner.properties" /opt/sonar-scanner-2.8/conf

# Get some ROS and development programs
RUN DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew"  --no-install-recommends \
python-rosinstall python-rosinstall-generator python-wstool g++-7 doxygen clang-5.0 clang-tidy-5.0 clang-format-5.0 plantuml valgrind rsync lftp lcov

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 100 --slave /usr/bin/g++ g++ /usr/bin/g++-7
RUN /bin/bash -c '{ cd /tmp; rm -rf cppcheck-build cppcheck-1.81; curl -L http://github.com/danmar/cppcheck/releases/download/1.81/cppcheck-1.81.tar.gz | tar xz; mkdir cppcheck-build; cd cppcheck-build; cmake ../cppcheck-1.81/ -DCMAKE_BUILD_TYPE=Release -DHAVE_RULES=OFF; make; make install; cd; rm -rf /tmp/cppcheck-build /tmp/cppcheck-1.81;}'

# Install Boost libraries for OSM
RUN wget http://downloads.sourceforge.net/project/boost/boost/1.65.1/boost_1_65_1.tar.gz \
  && tar xfz boost_1_65_1.tar.gz \
  && rm boost_1_65_1.tar.gz \
  && cd boost_1_65_1 \
  && ./bootstrap.sh --prefix=/usr/local --with-libraries=program_options,filesystem,system,thread,date_time,iostreams,serialization,regex \
  && ./b2 --with-test --with-date_time --with-program_options --with-filesystem --with-system --with-thread --with-iostreams --with-regex  install \
  && rm -rf boost_1_65_1

# Install newest CMake for ROS Boost support
RUN wget https://github.com/Kitware/CMake/releases/download/v3.13.3/cmake-3.13.3-Linux-x86_64.sh && \
 sh cmake-3.13.3-Linux-x86_64.sh --skip-license --prefix=/usr/local

# Install WxWidget libraries for OSM
RUN wget https://github.com/wxWidgets/wxWidgets/releases/download/v3.1.0/wxWidgets-3.1.0.tar.bz2 && \
  tar xvjf wxWidgets-3.1.0.tar.bz2 -C /opt && \
  cd /opt/wxWidgets-3.1.0 && ./configure && make && make install

RUN apt-get update && apt-get install -y automake autoconf libtool m4 vim libboost-all-dev

# Install libfreenect2 (Kinect library) for WoR
RUN apt-get install -y  build-essential cmake pkg-config libusb-1.0-0-dev libturbojpeg0-dev libglfw3-dev beignet-dev libva-dev libjpeg-dev libopenni2-dev opencl-headers && \
git clone https://github.com/OpenKinect/libfreenect2.git && \
cd libfreenect2 && \
mkdir build && \
cd build && \
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/freenect2 && \
make && \
make install

# Install libFranka
RUN git clone https://github.com/frankaemika/libfranka.git /opt/libfranka && \
cd /opt/libfranka && \
rm -rf common && \
git clone https://github.com/frankaemika/libfranka-common.git common && \
.ci/libonly.sh

# Install nodeJS for WoR
RUN apt-get install -y sudo && \
curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash - && \
apt-get install -y nodejs

# Install CGAL for WoR
RUN apt-get update && apt-get install -y libcgal-dev libcgal-qt5-dev

# Standard SSH port
EXPOSE 22

# Default command
CMD ["/usr/sbin/sshd", "-D"]
