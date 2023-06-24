#!/bin/bash
{
    echo "alias ll='ls -alF'"
    echo "alias tf='terraform'"
    echo "alias tffmt='terraform fmt -recursive'"
} >> ~/.bashrc
