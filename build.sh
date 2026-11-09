#!/bin/bash

export PATH="$PATH:/opt/homebrew/bin/:~/.local/bin" &&

brew_path=`brew --prefix` &&

eval "$(/${brew_path}/bin/brew shellenv)" &&

# Run modules on Ansible's own Python; Homebrew's python3 can move ahead of what ansible-core supports.
interpreter="$(brew --prefix ansible)/libexec/bin/python"

ansible-playbook -i "localhost," -c local -e "ansible_python_interpreter='${interpreter}'" playbook.yml "$@"
