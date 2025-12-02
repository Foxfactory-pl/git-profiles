#!/usr/bin/env bash

# -------------------------
# Bash utility script for creating a new git "profile" locally.
# https://github.com/Foxfactory-pl/git-profiles
# -------------------------


set -euo pipefail

GLOBAL_GITCONFIG="$HOME/.gitconfig"

NC='\033[0m'
GREEN='\033[0;32m'
GREEN_BOLD='\033[1;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

print_success() {
    echo -e "${GREEN}$1${NC}"
}
print_success_bold() {
    echo -e "${GREEN_BOLD}$1${NC}"
}
print_warning() {
    echo -e "${YELLOW}$1${NC}"
}
print_error() {
    echo -e "${RED}$1${NC}"
}
abort() {
    print_warning "Aborting."
    exit 1
}
print_block() {
    local title="$1"
    local body="$2"

    echo
    print_success "$title"
    echo
    echo "$body"
    echo
}


# Ensure that global gitconfig exists; show warning otherwise
    if [[ ! -f "$GLOBAL_GITCONFIG" ]]; then
        print_error "Warning: global gitconfig file not found in '$GLOBAL_GITCONFIG'."
        print_error "You might need to adjust GLOBAL_GITCONFIG variable to point to the correct location."
    fi


# Ensure that user is in "git" directory; show a warning otherwise
    CURRENT_DIR_NAME="$(basename "$PWD")"
    if [[ "$CURRENT_DIR_NAME" != "git" ]]; then
    print_warning "Warning: current directory is '$CURRENT_DIR_NAME', not 'git'."
    while true; do
        read -r -p "Do you want to continue? (y/n): " answer
        answer="$(echo "$answer" | tr '[:upper:]' '[:lower:]')"
        case "$answer" in
        y|yes)
            break
            ;;
        n|no)
            abort
            ;;
        *)
            print_warning "Invalid answer. Please enter 'y' or 'n' (or 'yes'/'no')."
            ;;
        esac
    done
    fi


# User input

    # Profile name (checking for already existing directory)
    while true; do
        read -r -p "Enter the profile (directory) name: " PROFILE_NAME
        if [[ -z "$PROFILE_NAME" ]]; then
            print_warning "Profile name cannot be empty."
            continue
        fi
        PROFILE_DIR="$PWD/$PROFILE_NAME"

        if [[ -e "$PROFILE_DIR" ]]; then
            print_warning "Directory '$PROFILE_DIR' already exists. Choose a different profile name."
            continue
        fi
        break
    done

    # Git user.name
    read -r -p "Enter the git user.name for this profile (empty for no user.name): " GIT_USER_NAME

    # Git user.email
    while true; do
        read -r -p "Enter the git user.email for this profile: " GIT_USER_EMAIL
        if [[ -n "$GIT_USER_EMAIL" && "$GIT_USER_EMAIL" =~ ^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$ ]]; then
            break
        fi
        print_warning "Invalid email. Please try again."
    done

    # SSH passphrase (optional)
    while true; do
        read -r -s -p "Enter SSH key passphrase (empty for no passphrase): " SSH_PASSPHRASE
        # Enter the same passphrase again (only if not empty)
        if [[ -n "$SSH_PASSPHRASE" ]]; then
            echo
            read -r -s -p "Enter the same passphrase again: " SSH_PASSPHRASE_CONFIRM
            if [[ "$SSH_PASSPHRASE" != "$SSH_PASSPHRASE_CONFIRM" ]]; then
                echo
                print_warning "Passphrases do not match. Please try again."
                continue
            fi
        fi
        break
    done
    echo

    # Whether to create GPG signing key
    CREATE_GPG=""
    while true; do
        read -r -p "Do you want to set up GPG signing key for this profile? (y/n): " create_gpg
        create_gpg="$(echo "$create_gpg" | tr '[:upper:]' '[:lower:]')"

        case "$create_gpg" in
            y|yes)
                CREATE_GPG="yes"
                break
                ;;
            n|no)
                CREATE_GPG="no"
                break
                ;;
            *)
                print_warning "Please enter 'y' or 'n' (or 'yes'/'no')."
                continue
                ;;
        esac
    done

    # GPG passphrase (only if creating GPG key)
    if [[ "$CREATE_GPG" == "yes" ]]; then
        while true; do
            read -r -s -p "Enter GPG key passphrase (empty for no passphrase): " GPG_PASSPHRASE
            # Enter the same passphrase again (only if not empty)
            if [[ -n "$GPG_PASSPHRASE" ]]; then
                echo
                read -r -s -p "Enter the same passphrase again: " GPG_PASSPHRASE_CONFIRM
                if [[ "$GPG_PASSPHRASE" != "$GPG_PASSPHRASE_CONFIRM" ]]; then
                    echo
                    print_warning "Passphrases do not match. Please try again."
                    continue
                fi
            fi
            break
        done
        echo
    fi


SSH_DIR="$PROFILE_DIR/.ssh"


# Create profile directories

    # Create profile directory
    mkdir -p "$PROFILE_DIR"

    # Create .ssh subdirectory
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"


# Generate ssh key pair in {profile}/.ssh directory

    # Determine SSH key file path
    SSH_KEY_PATH="$SSH_DIR/id_profile_ssh"

    # Determine SSH key comment (with or without user name)
    if [[ -n "$GIT_USER_NAME" ]]; then
        SSH_KEY_COMMENT="$GIT_USER_NAME <$GIT_USER_EMAIL>"
    else
        SSH_KEY_COMMENT="$GIT_USER_EMAIL"
    fi

    # Generate SSH key pair
    if [[ -z "${SSH_PASSPHRASE:-}" ]]; then
        ssh-keygen -C "$SSH_KEY_COMMENT" -N "" -f "$SSH_KEY_PATH" >/dev/null 2>&1
    else
        ssh-keygen -C "$SSH_KEY_COMMENT" -N "$SSH_PASSPHRASE" -f "$SSH_KEY_PATH" >/dev/null 2>&1
    fi

    if [[ ! -f "$SSH_KEY_PATH" ]] || [[ ! -f "$SSH_KEY_PATH.pub" ]]; then
        print_error "Error creating SSH key pair!"
        abort
    fi
    SSH_PUBLIC_KEY="$(cat "$SSH_KEY_PATH.pub")"

    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_KEY_PATH.pub"


# Generate GPG signing key (if requested)

    if [[ "$CREATE_GPG" == "yes" ]]; then
        USER_ID="$SSH_KEY_COMMENT"

        gpg --quiet \
            --batch \
            --pinentry-mode loopback \
            --passphrase "$GPG_PASSPHRASE" \
            --quick-generate-key "$USER_ID" rsa sign 0 >/dev/null 2>&1

        # Extract GPG key ID
        GPG_KEY_ID="$(gpg --list-secret-keys --with-colons "$USER_ID" | awk -F: '/^sec:/ {print $5; exit}')"

        if [[ -z "$GPG_KEY_ID" ]]; then
            print_error "Failed to generate GPG key."
            abort
        fi

        # Get public key
        GPG_PUBLIC_KEY="$(gpg --armor --export "$GPG_KEY_ID")"

    fi


# Generate .gitconfig file
    GITCONFIG_PATH="$PROFILE_DIR/.gitconfig"
    GITCONFIG_CONTENT="[core]
    sshCommand = ssh -i $SSH_KEY_PATH
    
[user]
    name = $GIT_USER_NAME
    email = $GIT_USER_EMAIL
    "
    if [[ "$CREATE_GPG" == "yes" ]]; then
        GITCONFIG_CONTENT+="signingkey = $GPG_KEY_ID

[commit]
    gpgSign = true

[gpg]
    program = gpg
"
    fi
    echo "$GITCONFIG_CONTENT" > "$GITCONFIG_PATH"


# Add entry to global gitconfig (includeIf)
if ! grep -q "\[includeIf \"gitdir:$PROFILE_DIR/\"\]" "$GLOBAL_GITCONFIG" 2>/dev/null; then
    {
        echo
        echo "[includeIf \"gitdir:$PROFILE_DIR/\"]"
        echo "    path = $PROFILE_DIR/.gitconfig"
    } >> "$GLOBAL_GITCONFIG"
fi


echo
print_success_bold "Profile '$PROFILE_NAME' created successfully!"
print_block \
    "Use the following SSH public key for adding to your git hosting service:" \
    "$SSH_PUBLIC_KEY"

if [[ "$CREATE_GPG" == "yes" ]]; then
    print_success "GPG key ID: $GPG_KEY_ID"
    print_block \
        "Use the following GPG public key for adding to your git hosting service:" \
        "$GPG_PUBLIC_KEY"
fi