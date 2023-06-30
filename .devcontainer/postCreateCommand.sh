#!/bin/bash
{
    echo "alias ll='ls -alF'"
    echo "alias tf='terraform'"
    echo "alias tffmts='terraform fmt -recursive'"
} >> ~/.bashrc
