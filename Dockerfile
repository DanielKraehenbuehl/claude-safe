FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  grep \
  coreutils \
  ripgrep \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  xclip \
  xsel \
  expect \
  python3-pip \
  pipx \
  wget \
  curl \
  ca-certificates \
  software-properties-common \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Docker CLI with BuildX
RUN install -m 0755 -d /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
  chmod a+r /etc/apt/keyrings/docker.asc && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt-get update && \
  apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin:/home/node/.local/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

# Enable Docker BuildKit by default
ENV DOCKER_BUILDKIT=1
ENV COMPOSE_DOCKER_CLI_BUILD=1

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Install pre-commit using pipx
RUN pipx install pre-commit

# Pre-configure SSH known_hosts for common git services
RUN mkdir -p /home/node/.ssh && \
    ssh-keyscan -t rsa github.com >> /home/node/.ssh/known_hosts 2>/dev/null && \
    ssh-keyscan -t rsa ssh.dev.azure.com >> /home/node/.ssh/known_hosts 2>/dev/null && \
    ssh-keyscan -t rsa gitlab.com >> /home/node/.ssh/known_hosts 2>/dev/null && \
    ssh-keyscan -t rsa bitbucket.org >> /home/node/.ssh/known_hosts 2>/dev/null && \
    chown -R node:node /home/node/.ssh && \
    chmod 700 /home/node/.ssh && \
    chmod 600 /home/node/.ssh/known_hosts

# Copy and set up scripts (as root)
USER root
COPY setup-clipboard.sh /usr/local/bin/
COPY init-firewall.sh /usr/local/bin/
COPY start-claude.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup-clipboard.sh && \
  chmod +x /usr/local/bin/init-firewall.sh && \
  chmod +x /usr/local/bin/start-claude.sh && \
  /usr/local/bin/setup-clipboard.sh && \
  echo "# Allow node user to run package managers and installers" > /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/apt-get" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/apt" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/dpkg" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/pip3" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/pip" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/pipx" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/add-apt-repository" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/local/share/npm-global/bin/npm" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/bin/docker" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/sbin/groupdel" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/sbin/groupadd" >> /etc/sudoers.d/node-installers && \
  echo "node ALL=(root) NOPASSWD: /usr/sbin/usermod" >> /etc/sudoers.d/node-installers && \
  chmod 0440 /etc/sudoers.d/node-installers && \
  groupadd -f docker && \
  usermod -aG docker node
USER node
