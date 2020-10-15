FROM mcr.microsoft.com/playwright:bionic
# No interactive frontend during docker build
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    BIN_UTILS="/usr/bin"

#================
# Binary scripts
#================
COPY bin/* ${BIN_UTILS}/
COPY **/bin/* ${BIN_UTILS}/
COPY host-scripts/* /host-scripts/

RUN apt -qqy update \
  && apt -qqy install \
    libltdl7 \
    netcat-openbsd \
    pwgen \
    bc \
    unzip \
    bzip2 \
    apt-utils \
    net-tools \
    socat \
    jq \
    sudo \
    psmisc \
    iproute2 \
    iputils-ping \
    dbus-x11 \
    wget \
    curl \
    gnupg2 \
  && apt -qyy autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean

#==============================
# Locale and encoding settings
#==============================
ENV LANG_WHICH en
ENV LANG_WHERE US
ENV ENCODING UTF-8
ENV LANGUAGE ${LANG_WHICH}_${LANG_WHERE}.${ENCODING}
ENV LANG ${LANGUAGE}
RUN apt -qqy update \
  && apt -qqy --no-install-recommends install \
    language-pack-en \
    tzdata \
    locales \
  && locale-gen ${LANGUAGE} \
  && dpkg-reconfigure --frontend noninteractive locales \
  && apt -qyy autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean

#===================
# Timezone settings
#===================
ENV TZ="Europe/Berlin"
# Apply TimeZone
RUN echo "Setting time zone to '${TZ}'" \
  && echo "${TZ}" > /etc/timezone \
  && dpkg-reconfigure --frontend noninteractive tzdata

#========================================
# Add normal user with passwordless sudo
#========================================
RUN useradd seluser \
         --shell /bin/bash  \
         --create-home \
  && usermod -a -G sudo seluser \
  && gpasswd -a seluser video \
  && echo 'seluser:secret' | chpasswd \
  && useradd extrauser \
         --shell /bin/bash  \
  && usermod -a -G sudo extrauser \
  && gpasswd -a extrauser video \
  && gpasswd -a extrauser seluser \
  && echo 'extrauser:secret' | chpasswd \
  && echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers

#===================================================
# Run the following commands as non-privileged user
#===================================================
USER seluser
WORKDIR /home/seluser

#=============================
# sudo by default from now on
#=============================
USER root

#=========================================================
# Python3 for Supervisor and other stuff
#=========================================================
# Note Python3 fails installing mozInstall==1.12 with
#  NameError: name 'file' is not defined
# After install, make some useful symlinks that are expected to exist
RUN apt -qqy update \
  && apt -qqy --no-install-recommends install \
    python3 \
    python3-pip \
    python3-dev \
    python3-openssl \
    libssl-dev libffi-dev \
  && pip3 install --no-cache --upgrade pip==9.0.3 \
  && pip3 install --no-cache setuptools \
  && pip3 install --no-cache numpy \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean
RUN cd /usr/local/bin \
  && { [ -e easy_install ] || ln -s easy_install-* easy_install; } \
  && ln -s idle3 idle \
  && ln -s pydoc3 pydoc \
  && ln -s python3 python \
  && ln -s python3-config python-config \
  && rm -rf /usr/bin/python \
  && ln -s /usr/bin/python3 /usr/bin/python \
  && python --version \
  && pip --version

#====================
# Supervisor install
#====================
# TODO: Upgrade to supervisor stable 4.0 as soon as is released
# Check every now and then if version 4 is finally the stable one
#  https://pypi.python.org/pypi/supervisor
#  https://github.com/Supervisor/supervisor
# RUN apt -qqy update \
#   && apt -qqy install \
#     supervisor \
# 2018-09-28 commit: 837c159ae51f3b, supervisor/version.txt: 4.0.0.dev0
# 2018-06-01 commit: ec495be4e28c69, supervisor/version.txt: 4.0.0.dev0
# 2017-10-21 commit: 3f04badc3237f0, supervisor/version.txt: 4.0.0.dev0
# 2017-05-30 commit: 946d9cf3be4db3, supervisor/version.txt: 4.0.0.dev0
ENV RUN_DIR="/var/run/sele"
RUN SHA="837c159ae51f3bf12c1d30a8cb44f3450611983c" \
  && pip install --no-cache \
      "https://github.com/Supervisor/supervisor/zipball/${SHA}" || \
     pip install --no-cache \
      "https://github.com/Supervisor/supervisor/zipball/${SHA}" \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean

#================
# Font libraries
#================
# ttf-ubuntu-font-family
#   Ubuntu Font Family, sans-serif typeface hinted for clarity
# Removed packages:
# xfonts-100dpi
# xfonts-75dpi
# Regarding fonts-liberation see:
#  https://github.com/SeleniumHQ/docker-selenium/issues/383#issuecomment-278367069
RUN apt -qqy update \
  && apt -qqy --no-install-recommends install \
    libfontconfig \
    libfreetype6 \
    xfonts-cyrillic \
    xfonts-scalable \
    fonts-liberation \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    ttf-ubuntu-font-family \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean

#============================
# Xvfb X virtual framebuffer
#============================
# xvfb: Xvfb or X virtual framebuffer is a display server
#  + implements the X11 display server protocol
#  + performs all graphical operations in memory
RUN apt -qqy update \
  && apt -qqy --no-install-recommends install \
    xorg \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean


# Creating base directory for Xvfb
RUN sudo mkdir -p /tmp/.X11-unix /tmp/.ICE-unix
# Permissions related to the X system
RUN sudo chmod 1777 /tmp/.X11-unix /tmp/.ICE-unix
# Set owner to root
RUN sudo chown -R root /tmp/.X11-unix /tmp/.ICE-unix


#=========
# fluxbox
# A fast, lightweight and responsive window manager
#=========
# xfce4-notifyd allows `notify-send` notifications
RUN apt -qqy update \
  && apt -qqy install \
    fluxbox \
    xfce4-notifyd

#========
# ffmpeg
#========
# MP4Box (gpac) to clean the video credits to @taskworld @dtinth
# ffmpeg (ffmpeg): Is a better alternative to Pyvnc2swf
#   (use in Ubuntu >= 15) packages: ffmpeg
RUN apt -qqy update \
  && apt -qqy install \
    gpac \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean
#
##-----------------#
## Mozilla
##-----------------#
## Install all Firefox dependencies
## Adding libasound2 and others, credits to @jackTheRipper
##  https://github.com/SeleniumHQ/docker-selenium/pull/418
#    # libasound2 \
#    # libpulse-dev \
#    # xul-ext-ubufox \
#RUN apt -qqy update \
#  && apt -qqy --no-install-recommends install \
#    `apt-cache depends firefox | awk '/Depends:/{print$2}'` \
#  && rm -rf /var/lib/apt/lists/* \
#  && apt -qyy clean
#
ENV FF_LANG="en-US" \
    FF_BASE_URL="https://archive.mozilla.org/pub" \
    FF_PLATFORM="linux-x86_64" \
    FF_INNER_PATH="firefox/releases"

ARG FF_VER="74.0"

ENV FF_COMP="firefox-${FF_VER}.tar.bz2"
ENV FF_URL="${FF_BASE_URL}/${FF_INNER_PATH}/${FF_VER}/${FF_PLATFORM}/${FF_LANG}/${FF_COMP}"
RUN cd /opt \
  && wget -nv "${FF_URL}" -O "firefox.tar.bz2" \
  && bzip2 -d "firefox.tar.bz2" \
  && tar xf "firefox.tar" \
  && rm "firefox.tar" \
  && ln -fs /opt/firefox/firefox /usr/bin/firefox \
  && chown -R seluser:seluser /opt/firefox \
  && chmod -R 777 /opt/firefox

LABEL selenium_firefox_version "${FF_VER}"

#===============
# Google Chrome
#===============
# TODO: Use Google fingerprint to verify downloads
#  https://www.google.de/linuxrepositories/

ARG CHROME_VER="81.0.4044.138"

ENV CHROME_URL="https://dl.google.com/linux/direct" \
    GREP_ONLY_NUMS_VER="[0-9.]{2,20}"

ENV CHROME_EXEC="http://dl.google.com/linux/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VER}-1_amd64.deb"

LABEL selenium_chrome_version="${CHROME_VER}"

RUN apt -qqy update \
  && mkdir -p chrome-deb \
  && wget -nv "${CHROME_EXEC}" \
          -O "./chrome-deb/google-chrome-stable_current_amd64.deb" \
  && apt -qyy --no-install-recommends install \
        "./chrome-deb/google-chrome-stable_current_amd64.deb" \
  && rm "./chrome-deb/google-chrome-stable_current_amd64.deb"

RUN  rm -rf ./chrome-deb \
  && apt -qyy autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean \
  && export CH_STABLE_VER=$(/usr/bin/google-chrome --version | grep -iEo "${GREP_ONLY_NUMS_VER}") \
  && echo "CH_STABLE_VER:'${CH_STABLE_VER}' vs CHROME_VER:'${CHROME_VER}'" \
  && [ "${CH_STABLE_VER}" = "${CHROME_VER}" ] || fail

# We have a wrapper for /opt/google/chrome/google-chrome
RUN mv /opt/google/chrome/google-chrome /opt/google/chrome/google-chrome-base
COPY lib/* /usr/lib/

#===================================================
# Run the following commands as non-privileged user
#===================================================
USER seluser

#=================
# Supervisor conf
#=================
COPY supervisor/etc/supervisor/supervisord.conf /etc/supervisor/
COPY **/etc/supervisor/conf.d/* /etc/supervisor/conf.d/

#======
# Envs
#======
ENV DEFAULT_SUPERVISOR_HTTP_PORT="19001"
ENV FIREFOX_VERSION="${FF_VER}" \
  USE_SELENIUM="3" \
  CHROME_FLAVOR="stable" \
  DEBUG="false" \
  PICK_ALL_RANDOM_PORTS="false" \
  RANDOM_PORT_FROM="23100" \
  RANDOM_PORT_TO="29999" \
  USER="seluser" \
  HOME="/home/seluser" \
  LIB_UTILS="/usr/lib" \
  MEM_JAVA_PERCENT=80 \
  WAIT_FOREGROUND_RETRY="2s" \
  XVFB_STARTRETRIES=0 \
  XMANAGER_STARTSECS=2 \
  XMANAGER_STARTRETRIES=3 \
  WAIT_TIMEOUT="45s" \
  SCREEN_WIDTH=1366 \
  SCREEN_HEIGHT=768 \
  SCREEN_MAIN_DEPTH=24 \
  SCREEN_SUB_DEPTH=32 \
  DISP_N="-1" \
  MAX_DISPLAY_SEARCH=99 \
  SCREEN_NUM=0 \
  SELENIUM_HUB_PROTO="http" \
  SELENIUM_HUB_HOST="127.0.0.1" \
  # Unfortunately selenium is missing a -bind setting so -host
  # is used multipurpose forcing us to set it now to 0.0.0.0
  # to match the binding meaning in oposed to host meaning
  CHROME_ARGS="--no-sandbox --disable-setuid-sandbox --disable-gpu --disable-infobars" \
  CHROME_ADDITIONAL_ARGS="" \
  CHROME_VERBOSELOGGING="true" \
  no_proxy=localhost \
  XVFB_CLI_OPTS_TCP="-nolisten tcp -nolisten inet6" \
  XVFB_CLI_OPTS_BASE="-ac -r -cc 4 -accessx -xinerama" \
  XVFB_CLI_OPTS_EXT="+extension Composite +extension RANDR +extension GLX" \
  SUPERVISOR_HTTP_PORT="${DEFAULT_SUPERVISOR_HTTP_PORT}" \
  SUPERVISOR_HTTP_USERNAME="supervisorweb" \
  SUPERVISOR_HTTP_PASSWORD="somehttpbasicauthpwd" \
  SUPERVISOR_REQUIRED_SRV_LIST="xmanager" \
  SUPERVISOR_NOT_REQUIRED_SRV_LIST1="ignoreMe" \
  SUPERVISOR_NOT_REQUIRED_SRV_LIST2="ignoreMe" \
  SLEEP_SECS_AFTER_KILLING_SUPERVISORD=3 \
  SUPERVISOR_STOPWAITSECS=20 \
  SUPERVISOR_STOPSIGNAL=TERM \
  SUPERVISOR_KILLASGROUP="false" \
  SUPERVISOR_STOPASGROUP="false" \
  LOG_LEVEL="info" \
  DISABLE_ROLLBACK="false" \
  LOGFILE_MAXBYTES=10MB \
  LOGFILE_BACKUPS=5 \
  LOGS_DIR="/var/log/cont" \
  VIDEO="true" \
  CHROME="true" \
  FIREFOX="true" \
  FFMPEG_FRAME_RATE=10 \
  FFMPEG_CODEC_ARGS="-vcodec libx264 -preset ultrafast -pix_fmt yuv420p" \
  FFMPEG_FINAL_CRF=0 \
  FFMPEG_DRAW_MOUSE=1 \
  VIDEO_TMP_FILE_EXTENSION="mkv" \
  VIDEO_FILE_EXTENSION="mp4" \
  MP4_INTERLEAVES_MEDIA_DATA_CHUNKS_SECS="500" \
  VIDEO_FILE_NAME="video" \
  VIDEO_BEFORE_STOP_SLEEP_SECS="1" \
  VIDEO_AFTER_STOP_SLEEP_SECS="0.5" \
  VIDEO_STOPWAITSECS="50" \
  VIDEO_CONVERSION_MAX_WAIT="20s" \
  VIDEO_MP4_FIX_MAX_WAIT="8s" \
  VIDEO_WAIT_VID_TOOL_PID_1st_sig_UP_TO_SECS="6s" \
  VIDEO_WAIT_VID_TOOL_PID_2nd_sig_UP_TO_SECS="2s" \
  VIDEO_WAIT_VID_TOOL_PID_3rd_sig_UP_TO_SECS="1s" \
  VIDEO_STOP_1st_sig_TYPE="SIGTERM" \
  VIDEO_STOP_2nd_sig_TYPE="SIGINT" \
  VIDEO_STOP_3rd_sig_TYPE="SIGKILL" \
  WAIT_TIME_OUT_VIDEO_STOP="20s" \
  VIDEOS_DIR="/home/seluser/videos" \
  XMANAGER="fluxbox" \
  FLUXBOX_START_MAX_RETRIES=5 \
  TAIL_LOG_LINES="50" \
  SHM_TRY_MOUNT_UNMOUNT="false" \
  SHM_SIZE="512M" \
  ETHERNET_DEVICE_NAME="eth0" \
  XMANAGER_STOP_SIGNAL="TERM" \
  XVFB_STOP_SIGNAL="TERM" \
  XTERM_START="false" \
  XTERM_STOP_SIGNAL="INT" \
  SELENIUM_NODE_FIREFOX_STOP_SIGNAL="TERM" \
  SELENIUM_NODE_CHROME_STOP_SIGNAL="TERM" \
  VIDEO_REC_STOP_SIGNAL="INT" \
  DOCKER_SOCK="/var/run/docker.sock" \
  TEST_SLEEPS="0.1" \
  ZALENIUM="false" \
  SEND_ANONYMOUS_USAGE_INFO="true" \
  LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu/" \
  DEBIAN_FRONTEND="" \
  REMOVE_SELUSER_FROM_SUDOERS_FOR_TESTING="false" \
  DEBCONF_NONINTERACTIVE_SEEN=""

# Moved from entry.sh
ENV SUPERVISOR_PIDFILE="${RUN_DIR}/supervisord.pid" \
    DOCKER_SELENIUM_STATUS="${LOGS_DIR}/docker-selenium-status.log"

USER seluser

#===================================
# Fix dirs (again) and final chores
#===================================
RUN mkdir -p "${VIDEOS_DIR}" \
  && sudo ln -s "${VIDEOS_DIR}" /videos \
  && sudo mkdir -p "${LOGS_DIR}" \
  && sudo mkdir -p "${RUN_DIR}" \
  && sudo fixperms.sh \
  && echo ""

WORKDIR /home/seluser

RUN mkdir -p /home/seluser/bin
COPY package.json .
COPY package-lock.json .
RUN npm ci --production 

#==================
# Install saucectl
#==================
ARG SAUCECTL_VERSION=0.14.0
ENV SAUCECTL_BINARY=saucectl_${SAUCECTL_VERSION}_linux_64-bit.tar.gz
RUN curl -L -o ${SAUCECTL_BINARY} \
  -H "Accept: application/octet-stream" \
  https://github.com/saucelabs/saucectl/releases/download/v${SAUCECTL_VERSION}/${SAUCECTL_BINARY} \
  && tar -xvzf ${SAUCECTL_BINARY} \
#  && mkdir /home/seluser/bin/ \
  && mv ./saucectl /home/seluser/bin/saucectl \
  && rm ${SAUCECTL_BINARY}

COPY --chown=seluser:seluser . .
# Workaround for permissions in CI if run with a different user
RUN chmod 777 -R /home/seluser/


CMD ["./entry.sh"]
