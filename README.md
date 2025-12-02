# git-profiles

Setting up a new git profile shouldn't take more than seconds. This simple, interactive bash utility script automates the process of creating a new git "profile" with its own SSH keys and GPG signing key (optional).

![git-profiles](https://github.com/user-attachments/assets/e19e9bad-0661-4610-90a7-8d6b4b314875)

### What it does?

1. Creates a new directory structure with .ssh keys
2. Generates SSH key pair (using default `ssh-keygen` settings)
3. (Optional) Generates GPG signing key and configures git to use it for signing commits
4. Creates a profile-specific `.gitconfig` file in the profile directory
5. Appends `includeIf` directive to the global gitconfig
6. Prints out public SSH and GPG keys for easy copying into Git hosting services (GitHub, GitLab, etc.)

Newly created profile directory looks like this:
```
myProfile/
├── .gitconfig
└── .ssh
    ├── id_profile_ssh
    └── id_profile_ssh.pub
```

**When inside `myProfile` directory (or any of its subdirectories!) git will use the newly created SSH keys and GPG signing key.**

## Usage

All you need to do is to run the `git_add_profile.sh`. You can either copy-paste the script content into a new file or:

1. Download the script and save it in your `local` bin:
   ```bash
   mkdir -p ~/bin
   sudo curl -sS https://raw.githubusercontent.com/Foxfactory-pl/git-profiles/refs/heads/main/git_add_profile.sh -o /usr/local/bin/git-add-profile
   ```

2. Make it executable:
   ```bash
   sudo chmod +x /usr/local/bin/git-add-profile
   ```

3. Run the script:
   ```bash
   git-add-profile
   ```
 