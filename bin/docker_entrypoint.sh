#!/usr/bin/env bash

source /root/.bashrc
export PYENV_ROOT=/root/.pyenv
export NODE_ROOT=/node
export NVM_DIR=$NODE_ROOT/.nvm
export APP_DIR=/app/archivebox
export PATH=$PYENV_ROOT/shims:$PYENV_ROOT/bin:$NODE_ROOT:$NVM_DIR:$PATH

[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

DATA_DIR="${DATA_DIR:-/data}"
ARCHIVEBOX_USER="${ARCHIVEBOX_USER:-archivebox}"
PYTHON_VERSION="${PYTHON_VERSION}"

pyenv global $PYTHON_VERSION
pyenv rehash

# Set the archivebox user UID & GID
if [[ -n "$PUID" && "$PUID" != 0 ]]; then
    usermod -u "$PUID" "$ARCHIVEBOX_USER" > /dev/null 2>&1
fi
if [[ -n "$PGID" && "$PGID" != 0 ]]; then
    groupmod -g "$PGID" "$ARCHIVEBOX_USER" > /dev/null 2>&1
fi


# Set the permissions of the data dir to match the archivebox user
if [[ -d "$DATA_DIR/archive" ]]; then
    # check data directory permissions
    if [[ ! "$(stat -c %u $DATA_DIR/archive)" = "$(id -u archivebox)" ]]; then
        echo "Change in ownership detected, please be patient while we chown existing files"
        echo "This could take some time..."
        chown $ARCHIVEBOX_USER:$ARCHIVEBOX_USER -R "$DATA_DIR"
    fi
else
    # create data directory
    mkdir -p "$DATA_DIR/logs"
    chown -R $ARCHIVEBOX_USER:$ARCHIVEBOX_USER "$DATA_DIR"
fi
chown $ARCHIVEBOX_USER:$ARCHIVEBOX_USER "$DATA_DIR"

# Drop permissions to run commands as the archivebox user
if [[ "$1" == /* || "$1" == "echo" || "$1" == "archivebox" ]]; then
    # arg 1 is a binary, execute it verbatim
    # e.g. "archivebox init"
    #      "/bin/bash"
    #      "echo"
    (
        echo exec gosu "$ARCHIVEBOX_USER" bash -c "python -m gunicorn core.wsgi:application --bind 0.0.0.0:8000 --chdir $APP_DIR --reload --workers 8 --timeout 3600 -k gevent"
    )
    if [ $? != 0 ]
    then
        exec gosu "$ARCHIVEBOX_USER" bash -c "python -m gunicorn core.wsgi:application --bind 0.0.0.0:8000 --chdir $APP_DIR --reload --workers 8 --timeout 3600 -k gevent"
    fi
else
    # no command given, assume args were meant to be passed to archivebox cmd
    # e.g. "add https://example.com"
    #      "manage createsupseruser"
    #      "server 0.0.0.0:8000"
    exec gosu "$ARCHIVEBOX_USER" bash -c "python -m gunicorn core.wsgi:application --bind 0.0.0.0:8000 --chdir $APP_DIR --reload --workers 8 --timeout 3600 -k gevent"
fi
