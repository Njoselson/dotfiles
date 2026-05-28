# --- PATH ---
if [[ "$(uname)" == "Darwin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
    source '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' 2>/dev/null
fi
export PATH="$HOME/.local/bin:$PATH"

# --- pyenv ---
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

# --- oh-my-zsh (optional — skipped if not installed) ---
if [ -d "$HOME/.oh-my-zsh" ]; then
    export ZSH="$HOME/.oh-my-zsh"
    ZSH_THEME="robbyrussell"
    plugins=(zsh-autosuggestions zsh-vi-mode git)
    autoload -U compinit && compinit
    source $ZSH/oh-my-zsh.sh
fi

# --- Editor ---
export EDITOR=nvim
export VISUAL=nvim

# --- Aliases ---
alias x="exit"
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# ===================== EIQ TUNNEL MANAGEMENT =====================

# --- Autossh settings (resilient over IAP) ---
export AUTOSSH_GATETIME=0
export AUTOSSH_POLL=10
export AUTOSSH_LOGLEVEL=4

# --- VM SSH host aliases (match ~/.ssh/config Host entries) ---
VM_DEV=nate_vm
VM_STG=nate_stage_vm
VM_GPU=nate_gpu_vm
VM_CA=nate_ca_vm
VM_CLAIMS=nate_claims_vm

# --- VM lifecycle ---
alias vm-start="gcloud compute instances start eiq-dev-vm-nathaniel-joselson-standard-1 --zone=us-east4-a --project=eiq-development"
alias vm-stop="gcloud compute instances stop eiq-dev-vm-nathaniel-joselson-standard-1 --zone=us-east4-a --project=eiq-development"
alias vm-stg-start="gcloud compute instances start eiq-stg-vm-nathaniel-joselson-standard-1 --zone=us-east4-a --project=eiq-staging"
alias vm-stg-stop="gcloud compute instances stop eiq-stg-vm-nathaniel-joselson-standard-1 --zone=us-east4-a --project=eiq-staging"
alias vm-gpu-start="gcloud compute instances start eiq-dev-vm-nathaniel-joselson-gpu-1 --zone=us-central1-c --project=eiq-development"
alias vm-gpu-stop="gcloud compute instances stop eiq-dev-vm-nathaniel-joselson-gpu-1 --zone=us-central1-c --project=eiq-development"
alias ca-start="gcloud compute instances start eiq-ca-dev-vm-nathaniel-joselson-7c17 --zone=northamerica-northeast1-b --project=eiq-ca-development"
alias ca-stop="gcloud compute instances stop eiq-ca-dev-vm-nathaniel-joselson-7c17 --zone=northamerica-northeast1-b --project=eiq-ca-development"
alias claims-start="gcloud compute instances start claims-llm-training-4gpu --zone=us-central1-f --project=eiq-development"
alias claims-stop="gcloud compute instances stop claims-llm-training-4gpu --zone=us-central1-f --project=eiq-development"

# --- Background port forwards (unique local ports per VM) ---
alias vm-fwd='autossh -M 0 -f -N -L 3000:localhost:3000 -L 8080:localhost:8080 ${VM_DEV}'
alias vm-fwd-stg='autossh -M 0 -f -N -L 3001:localhost:3000 -L 8081:localhost:8080 ${VM_STG}'
alias vm-fwd-gpu='autossh -M 0 -f -N -L 3002:localhost:3000 -L 8082:localhost:8080 ${VM_GPU}'

# --- DB tunnels (Postgres) ---
alias vm-db='autossh -M 0 -f -N -L 6900:localhost:5432 ${VM_DEV}'
alias vm-db-stop='lsof -nPiTCP:6900 -sTCP:LISTEN -t 2>/dev/null | xargs -I{} kill -TERM {} 2>/dev/null || true'
alias vm-db-stg='autossh -M 0 -f -N -L 6901:localhost:5432 ${VM_STG}'
alias vm-db-stg-stop='lsof -nPiTCP:6901 -sTCP:LISTEN -t 2>/dev/null | xargs -I{} kill -TERM {} 2>/dev/null || true'
alias vm-db-gpu='autossh -M 0 -f -N -L 6902:localhost:5432 ${VM_GPU}'
alias vm-db-gpu-stop='lsof -nPiTCP:6902 -sTCP:LISTEN -t 2>/dev/null | xargs -I{} kill -TERM {} 2>/dev/null || true'

# --- Stop forwards ---
alias vm-fwd-stop='ssh -O exit ${VM_DEV} || true'
alias vm-fwd-stg-stop='ssh -O exit ${VM_STG} || true'
alias vm-fwd-gpu-stop='ssh -O exit ${VM_GPU} || true'

# --- Helpers ---
port() { lsof -nPi :"$1" 2>/dev/null | sed -n '1,10p'; }

kill-fwd() {
    pkill -f "ssh .* -L 3000:localhost:3000" || true
    pkill -f "ssh .* -L 8080:localhost:8080" || true
    pkill -f "ssh .* -L 3001:localhost:3000" || true
    pkill -f "ssh .* -L 8081:localhost:8080" || true
    pkill -f "ssh .* -L 3002:localhost:3000" || true
    pkill -f "ssh .* -L 8082:localhost:8080" || true
}

vm-fwd-status() {
    for p in 3000 8080 3001 8081 3002 8082 6900 6901 6902; do
        echo "== PORT $p =="
        lsof -nPiTCP:$p -sTCP:LISTEN 2>/dev/null | sed -n '1,5p'
    done
}

# --- SSH/tmux sessions ---
alias vm-ssh="ssh -X ${VM_DEV}"
alias vm-stg-ssh="ssh -X ${VM_STG}"
alias vm-gpu-ssh="ssh -X ${VM_GPU}"
alias vm-cpu="ssh -t ${VM_DEV} 'tmux attach -t cpu_tmux || tmux new -s cpu_tmux'"
alias vm-stg-cpu="ssh -t ${VM_STG} 'tmux attach -t cpu_tmux || tmux new -s cpu_tmux'"
alias vm-gpu-cpu="ssh -t ${VM_GPU} 'tmux attach -t cpu_tmux || tmux new -s cpu_tmux'"

# --- One-command workflows (start VM + wait + forward + tmux) ---
vm__wait_ssh() {
    local host="$1"
    echo "Waiting for SSH on ${host}..."
    until ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" true 2>/dev/null; do
        sleep 3
    done
    echo "${host} is reachable."
}

ensure-fwd()     { lsof -nPi :3000 >/dev/null 2>&1 || { echo "Starting 3000/8080"; vm-fwd; }; }
ensure-fwd-stg() { lsof -nPi :3001 >/dev/null 2>&1 || { echo "Starting 3001/8081"; vm-fwd-stg; }; }
ensure-fwd-gpu() { lsof -nPi :3002 >/dev/null 2>&1 || { echo "Starting 3002/8082"; vm-fwd-gpu; }; }

alias vm-work='vm-start && vm__wait_ssh "${VM_DEV}" && ensure-fwd && ssh -t ${VM_DEV} "tmux attach -t cpu_tmux || tmux new -s cpu_tmux"'
alias vm-work-stg='vm-stg-start && vm__wait_ssh "${VM_STG}" && ensure-fwd-stg && ssh -t ${VM_STG} "tmux attach -t cpu_tmux || tmux new -s cpu_tmux"'
alias vm-work-gpu='vm-gpu-start && vm__wait_ssh "${VM_GPU}" && ensure-fwd-gpu && ssh -t ${VM_GPU} "tmux attach -t cpu_tmux || tmux new -s cpu_tmux"'
alias vm-work-ca='ca-start && vm__wait_ssh "${VM_CA}" && ssh -t ${VM_CA} "tmux attach -t cpu_tmux || tmux new -s cpu_tmux"'
alias work-claimsvm='claims-start && vm__wait_ssh "${VM_CLAIMS}" && ssh -t ${VM_CLAIMS} "tmux attach -t cpu_tmux || tmux new -s cpu_tmux"'

# --- FZF ---
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# --- uv ---
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# --- Completion ---
autoload -Uz compinit
zstyle ':completion:*' menu select
fpath+=~/.zfunc

# --- Local overrides (secrets, machine-specific) ---
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
