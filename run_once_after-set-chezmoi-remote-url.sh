#!/usr/bin/env bash
# vi: set ft=bash

git --git-dir "$(chezmoi source-path)/.git" remote set-url origin git@github.com:andreterroir/dotfiles.git
