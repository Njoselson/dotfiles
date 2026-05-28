export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

HISTSIZE=5000
HISTFILESIZE=10000
shopt -s histappend
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# generate completion reply with compgen for known hosts (ssh)

complete -W "$(echo $(grep '^ssh ' ~/.bash_history | sort -u | sed 's/^ssh //'))" ssh

alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias vim='nvim'
alias x='exit'

set -o vi
