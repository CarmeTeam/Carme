#!/usr/bin/env bash

_carme_manager_commands () {
  local opts
  local cur

  opts=$(carme-manager arglist)

  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )

  return 0
}

complete -o nospace -F _carme_manager_commands carme-manager
