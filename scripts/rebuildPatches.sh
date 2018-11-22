#!/usr/bin/env bash

(
PS1="$"
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
source "$basedir/scripts/functions.sh"
gitcmd="git -c commit.gpgsign=false -c core.safecrlf=false"

echo "Rebuilding patch files from current fork state..."

function cleanupPatches {
    cd "$1"
    for patch in *.patch; do
        echo "$patch"
        sed -Ei.bak "/^From [a-f0-9]{32,}.*/d" "$patch"
        sed -Ei.bak "/^index [a-f0-9]+\.\.[a-f0-9]+.*/d" "$patch"
        rm "$patch.bak"
        $gitcmd add -A $patch
    done
}

function savePatches {
    what=$1
    what_name=$(basename "$what")
    target=$2
    echo "Formatting patches for $what..."

    cd "$basedir/${what_name}-Patches/"
    if [ -d "$basedir/$target/.git/rebase-apply" ]; then
        # in middle of a rebase, be smarter
        echo "REBASE DETECTED - PARTIAL SAVE"
        last=$(cat "$basedir/$target/.git/rebase-apply/last")
        next=$(cat "$basedir/$target/.git/rebase-apply/next")
        orderedfiles=$(find . -name "*.patch" | sort)
        for i in $(seq -f "%04g" 1 1 $last)
        do
            if [ $i -lt $next ]; then
                rm $(echo "$orderedfiles{@}" | sed -n "${i}p")
            fi
        done
    else
        rm -rf *.patch
    fi

    cd "$basedir/$target"

    $gitcmd format-patch --no-stat -N -o "$basedir/${what_name}-Patches/" upstream/upstream >/dev/null
    cd "$basedir"
    $gitcmd add -A "$basedir/${what_name}-Patches"
    cleanupPatches "$basedir/${what_name}-Patches"
    echo "  Patches saved for $what to $what_name-Patches/"
}

savePatches "$workdir/Spigot/Spigot-API" "Paper-API"
if [ -f "$basedir/Paper-API/.git/patch-apply-failed" ]; then
    echo "$(color 1 31)[[[ WARNING ]]] $(color 1 33)- Not saving Paper-Server as it appears Paper-API did not apply clean.$(colorend)"
    echo "$(color 1 33)If this is a mistake, delete $(color 1 34)Paper-API/.git/patch-apply-failed$(color 1 33) and run rebuild again.$(colorend)"
    echo "$(color 1 33)Otherwise, rerun ./paper patch to have a clean Paper-API apply so the latest Paper-Server can build.$(colorend)"
else
    savePatches "$workdir/Spigot/Spigot-Server" "Paper-Server"
fi
) || exit 1
