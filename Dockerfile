# syntax=docker/dockerfile:1
# --- Compilação segura de rclone do código-fonte ---
FROM golang:1.25 AS rclone_builder

# Define o commit SHA de rclone exato que você deseja instalar (ex: versão v1.69.1)
# NUNCA use apenas a tag, pois tags podem ser deletadas e recriadas maliciosamente.

# v1.75.0 - 9ee9d0a0cafd5e5fe3b271d2280b090ab6e64048
ARG RCLONE_COMMIT_SHA=9ee9d0a0cafd5e5fe3b271d2280b090ab6e64048

WORKDIR /go/src/rclone

# Baixa o repositório oficial, faz o checkout no commit exato verificado e compila
RUN git clone https://github.com/rclone/rclone.git . \
 && git checkout ${RCLONE_COMMIT_SHA} \
 && go build


FROM ubuntu:24.04

ARG HOME_USER
ARG HOME_USER_ID

############################################################################
############################################################################
#####/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\#####
#####\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/#####
#####/\/\                                                          /\/\#####
#####\/\/  ----------------------- INÍCIO  ----------------------  \/\/#####
#####/\/\       Configuração comum entre os ambientes desktop      /\/\#####
#####\/\/                                                          \/\/#####
#####/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\#####
#####\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/#####
############################################################################
############################################################################


############################################################################
#####    Instala o rclone no contexto do sistema                       #####
#####     - instala antes para o mesmo ficar em cache desde o começo   #####
############################################################################
# Copia o binário estático compilado da Etapa 1 com segurança
COPY --from=rclone_builder /go/src/rclone/rclone /usr/local/bin/
# Garante permissões corretas de execução
RUN chown root:root /usr/local/bin/rclone \
 && chmod 755 /usr/local/bin/rclone


############################################################################
#####    Instala dependências básicas                                  #####
#####     - XFCE                                                       #####
#####     - VNC                                                        #####
#####     - entre outras                                               #####
############################################################################
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    tigervnc-common \
    x11-xserver-utils \
    dbus-x11 \
    sudo \
    curl \
    wget \
    ca-certificates \
    libglib2.0-0 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libgtk-3-0 \
    libgbm1 \
    libasound2t64 \
    fonts-liberation \
    xdg-utils \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    llvm \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    git \
    keepassxc \
    xcape \
    xfe \
    filezilla \
    ffmpeg \
    python3-secretstorage \
    python3-keyring && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


############################################################################
#####    Instalar e configurar o suporte a UTF-8 (pt_BR)               #####
############################################################################
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    locales && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen pt_BR.UTF-8 && \
    update-locale LANG=pt_BR.UTF-8

############################################################################
#####    Definir as variáveis de ambiente para garantir que o SO       #####
#####    e as apps usam o UTF-8 (pt_BR)                                #####
############################################################################
ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

############################################################################
#####    Desabilita TODO o monitoramento remoto do GVFS no container   #####
############################################################################
RUN rm -rf /usr/share/gvfs/remote-volume-monitors/*
ENV GVFS_DISABLE_FUSE=1
ENV GIO_USE_VFS=local

############################################################################
#####    Instala o Google Chrome no contexto do sistema                #####
############################################################################
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    dpkg -i google-chrome-stable_current_amd64.deb || apt-get -fy install && \
    rm google-chrome-stable_current_amd64.deb

############################################################################
#####    Instala o VS Code (.deb) no contexto do sistema               #####
############################################################################
RUN wget -O vscode.deb 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64' && \
    dpkg -i vscode.deb || apt-get -fy install && \
    rm vscode.deb


############################################################################
#####    Instala o yt-dlp no contexto do sistema                       #####
#####     - system dependencies: python3-secretstorage and             #####
#####                            python3-keyring                       #####
############################################################################
RUN wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp && \
    chmod a+rx /usr/local/bin/yt-dlp && \
    yt-dlp -U && \
    echo "--js-runtimes node" > /etc/yt-dlp.conf && \
    echo "--cookies-from-browser chrome" >> /etc/yt-dlp.conf

############################################################################
#####    Configura o script yt-audio-download                          #####
############################################################################
COPY <<EOF /usr/local/bin/yt-audio-download
#!/bin/bash
URL=\$1
yt-dlp -x --audio-format mp3 --audio-quality 0 "\$URL"
EOF
RUN chmod +x /usr/local/bin/yt-audio-download


############################################################################
#####    Configuração do usuário                                       #####
#####     - Criar o usuário '$HOME_USER' com UID e GID $HOME_USER_ID   #####
############################################################################
RUN groupadd -g $HOME_USER_ID $HOME_USER && \
    useradd -u $HOME_USER_ID -g $HOME_USER_ID -ms /bin/bash $HOME_USER && \
    echo "$HOME_USER:$HOME_USER" | chpasswd && \
    adduser $HOME_USER sudo
WORKDIR /home/$HOME_USER

############################################################################
#####    Configuração do sudo 'user-full-access'                       #####
#####     - Libera o uso do 'sudo' SEM SENHA para tudo                 #####
############################################################################
# RUN echo "$HOME_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user-full-access && \
#     chmod 0440 /etc/sudoers.d/user-full-access

############################################################################
#####    Configuração do sudo 'cat-pulse-host-cookie'                  #####
#####     - Configura cookie do pulse para usar som                    #####
############################################################################
RUN echo "$HOME_USER ALL=(ALL) NOPASSWD: /usr/bin/cat /tmp/host-cookie" > /etc/sudoers.d/cat-pulse-host-cookie && \
    chmod 0440 /etc/sudoers.d/cat-pulse-host-cookie

# ============> $HOME_USER <============ #
USER $HOME_USER
############################################################################
#####    Instala e configura o Pyenv no contexto do usuário            #####
############################################################################
RUN curl https://pyenv.run | bash
ENV PYENV_ROOT="/home/$HOME_USER/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc && \
    echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc

############################################################################
#####    Instala e configura o NVM no contexto do usuário              #####
############################################################################
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
ENV NVM_DIR="/home/$HOME_USER/.nvm"
RUN echo 'export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
# Install NodeJS in LTS version in NVM (required to use yt-dlp)
RUN bash -c "source \$NVM_DIR/nvm.sh && nvm install --lts"

############################################################################
#####    Configura o VNC no contexto do usuário                        #####
############################################################################
RUN mkdir .vnc && \
    echo "$HOME_USER" | vncpasswd -f > .vnc/passwd && \
    chmod 600 .vnc/passwd

############################################################################
#####    Configura pasta ~/bin do usuário                              #####
############################################################################
RUN mkdir -p ~/bin/ && echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
ENV PATH="$HOME/bin:$PATH"


############################################################################
#####    Configura pasta ~/.bin do usuário                             #####
############################################################################
RUN mkdir -p ~/.bin/ && echo 'export PATH="$HOME/.bin:$PATH"' >> ~/.bashrc
ENV PATH="$HOME/.bin:$PATH"

############################################################################
#####    Cria pasta ~/.config do usuário                               #####
#####     - Necessário para poder adicionar volumes nesse caminho,     #####
#####       caso contrário a pasta fica com ownership do usuário root  #####
#####     - Usado para montar volumes como:                            #####
#####        -> ~/.config/google-chrome                                #####
#####        -> ~/.config/xfce4                                        #####
#####        -> ~/.config/keepassxc                                    #####
############################################################################
RUN mkdir -p ~/.config

############################################################################
#####    Configura xcape para o menu iniciar com whiskermenu           #####
#####     - Necessário para a tecla Start(windows) abrir o menu        #####
############################################################################
RUN mkdir -p ~/.config/autostart/
COPY --chown=$HOME_USER:$HOME_USER ./xcape.desktop .config/autostart/xcape.desktop
# ============> root <============ #
USER root
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y xvfb && \
    \
    # Executa o comando estritamente como o seu usuário comum via runuser
    runuser -l $HOME_USER -c \
    "xvfb-run -a dbus-run-session xfconf-query -c xfce4-keyboard-shortcuts \
     -p '/commands/custom/<Alt>F1' \
     -n -t 'string' \
     -s 'xfce4-popup-whiskermenu'" && \
    \
    # Limpa o sistema e remove o pacote temporário
    apt-get purge -y xvfb && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# ============> $HOME_USER <============ #
USER $HOME_USER

############################################################################
#####    Desabilita configuração easy click                            #####
############################################################################
# ============> root <============ #
USER root
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y xvfb && \
    \
    # Executa o comando estritamente como o seu usuário comum via runuser
    runuser -l $HOME_USER -c \
    "xvfb-run -a dbus-run-session \
     xfconf-query -c xfwm4 -p /general/easy_click -n -t string -s ''" && \
    \
    # Limpa o sistema e remove o pacote temporário
    apt-get purge -y xvfb && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# ============> $HOME_USER <============ #
USER $HOME_USER


############################################################################
#####    Configura arquivo ~/.config/pulse/cookie do usuário           #####
#####     - Necessário para poder ter o arquivo ~/.config/pulse/cookie #####
#####       para que o seu ownership já esteja com o usuário correto   #####
#####       para quando for executado o comando                        #####
#####       `sudo cat /tmp/host-cookie > $HOME/.config/pulse/cookie`   #####
#####       na inicialização do container já fique com pronto para uso #####
############################################################################
RUN mkdir -p ~/.config/pulse && \
    touch ~/.config/pulse/cookie && \
    chown $(id -u):$(id -g) ~/.config/pulse/cookie && \
    chmod 600 ~/.config/pulse/cookie

############################################################################
#####    Configura arquivo ~/.config/pulse/client.conf do usuário      #####
#####     - Necessário som não ser inicializado dentro do container,   #####
#####       podendo usar diretament o cookie configurado no arquivo    #####
#####       `~/.config/pulse/cookie` na inicialização do container     #####
############################################################################
RUN mkdir -p ~/.config/pulse && \
    echo "autospawn = no" > ~/.config/pulse/client.conf && \
    echo "daemon-binary = /bin/true" >> ~/.config/pulse/client.conf

############################################################################
#####    Instala e configura o rootless Docker no contexto do usuário  #####
############################################################################
RUN wget https://download.docker.com/linux/static/stable/x86_64/docker-24.0.7.tgz && \
    tar xzvf docker-24.0.7.tgz && \
    mv docker/* ~/bin/ && \
    rm -rf docker*

############################################################################
#####    Configuração do ~/.vnc/xstartup                               #####
############################################################################
# ============> root <============ #
USER root
# Remove as entradas automáticas do Clipman dentro de xdg padrão
RUN rm -f /etc/xdg/autostart/xfce4-clipman-plugin-autostart.desktop
# ============> $HOME_USER <============ #
USER $HOME_USER
RUN \
    # Remove as entradas automáticas do Clipman dentro da pasta do usuário
    rm -f ~/.config/autostart/xfce4-clipman-plugin-autostart.desktop && \
    \
    # Cria o xstartup com controle absoluto
    echo "#!/bin/sh\n\
    unset SESSION_MANAGER\n\
    unset DBUS_SESSION_BUS_ADDRESS\n\
    \n\
    # Inicia o VNC e o Clipman manualmente e em segundo plano\n\
    vncconfig -nowin &\n\
    xfce4-clipman &\n\
    \n\
    exec startxfce4" > .vnc/xstartup && \
    chmod +x .vnc/xstartup

EXPOSE 5901

ENV TOTAL_LARGURA=1920
ENV MAX_ALTURA=1080


############################################################################
#####    Configura o script google-drive-sync.sh                       #####
############################################################################
# ============> root <============ #
USER root
COPY <<EOF /home/$HOME_USER/bin/google-drive-sync.sh
#!/bin/bash
# Aguarda 10 segundos para dar tempo do sistema e rede subirem no container
sleep 10

if [ ! -f ~/.config/rclone/rclone.conf ]; then
    exit 0
fi

LOCAL_DIRECTORY="\$HOME/drive-${HOME_USER}-desktop-environment"
DRIVE_DIRECTORY="drive-${HOME_USER}-desktop-environment:"

# Executa a primeira sincronização de marcação (obrigatória no bisync)
rclone bisync "\$LOCAL_DIRECTORY" "\$DRIVE_DIRECTORY" --resync

while true; do
  # Executa a sincronização contínua
  rclone bisync "\$LOCAL_DIRECTORY" "\$DRIVE_DIRECTORY"
  
  # Aguarda 1 minutos (60 segundos) antes da próxima checagem
  sleep 60
done

EOF

RUN chown "$HOME_USER:$HOME_USER" /home/$HOME_USER/bin/google-drive-sync.sh && \
    chmod +x /home/$HOME_USER/bin/google-drive-sync.sh
# ============> $HOME_USER <============ #
USER $HOME_USER

############################################################################
#####    Configura o script desktop-entrypoint.sh                      #####
############################################################################
# ============> root <============ #
USER root
COPY <<EOF /home/$HOME_USER/bin/desktop-entrypoint.sh
#!/bin/bash

# 1. Comandos iniciais de cookie
sudo cat /tmp/host-cookie > \$HOME/.config/pulse/cookie

# 2. Inicia o script do rclone em SEGUNDO PLANO (&)
~/bin/google-drive-sync.sh &

# 3. Inicia o VNC em PRIMEIRO PLANO (Sem o '&' no final)
dbus-run-session -- vncserver -fg :1 -geometry \${TOTAL_LARGURA}x\${MAX_ALTURA} -depth 24 -localhost no -SecurityTypes TLSVnc,VncAuth

EOF

RUN chown "$HOME_USER:$HOME_USER" /home/$HOME_USER/bin/desktop-entrypoint.sh && \
    chmod +x /home/$HOME_USER/bin/desktop-entrypoint.sh
# ============> $HOME_USER <============ #
USER $HOME_USER


CMD ["/bin/sh", "-c", "$HOME/bin/desktop-entrypoint.sh"]

############################################################################
############################################################################
#####/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\#####
#####\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/#####
#####/\/\                                                          /\/\#####
#####\/\/       Configuração comum entre os ambientes desktop      \/\/#####
#####/\/\  -----------------------  FIM  -----------------------   /\/\#####
#####\/\/                                                          \/\/#####
#####/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\#####
#####\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/#####
############################################################################
############################################################################