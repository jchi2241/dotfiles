#!/bin/bash
# Safe git push - rejects force pushes

for arg in "$@"; do
    case "$arg" in
        --force|-f|--force-with-lease)
            echo "ERROR: Force push is not allowed. Ask the user to run it manually if needed."
            exit 1
            ;;
    esac
done

exec git push "$@"
