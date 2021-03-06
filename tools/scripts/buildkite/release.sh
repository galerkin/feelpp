#!/bin/bash

set -euo pipefail
#set -x
if [ -v DOCKER_PASSWORD -a -v DOCKER_LOGIN ]; then
    docker login --username="${DOCKER_LOGIN}" --password="${DOCKER_PASSWORD}";
fi

FEELPP_DIR=@CMAKE_INSTALL_PREFIX@

if [ -f ${FEELPP_DIR}/share/feelpp/scripts/list.sh ]; then 
    LIST=${FEELPP_DIR}/share/feelpp/scripts/list.sh;
else
    LIST=tools/scripts/buildkite/list.sh
fi
    

build="$(basename "$0")"
BRANCH=${BUILDKITE_BRANCH:-develop}
if [ -z ${TARGET:-""} ]; then
    TARGET=ubuntu:17.04
fi
latest=false
noop=false

usage() {
    echo >&2 "usage: $build "
    echo >&2 "              [-t|--target target host os, default: $TARGET]"
    echo >&2 "              [-b|--branch project git branch, default: $BRANCH]"
    echo >&2 "              [--latest true|false, default=$latest]"
    echo >&2 "   ie: $build -t ubuntu:16.10 -b develop --latest true feelpp-libs feelpp-base"
    exit 1
}

fromos=
fromtag=

tag=
while [ -n "$1" ]; do
    case "$1" in
        -t|--target) TARGET="$2" ; shift 2 ;;
        -b|--branch) BRANCH="$2" ; shift 2 ;;
        --latest) latest="$2" ; shift 2 ;;
        --noop) noop="$2" ; shift 2 ;;
        -h|--help) usage ;;
        --) shift ; break ;;
    esac
done

CONTAINERS=${*:-feelpp-libs}
echo $CONTAINERS

tag_from_target() {
    splitfrom=(`echo "$TARGET" | tr ":" "\n"`)
    fromos=${splitfrom[0]}
    fromtag=${splitfrom[1]}

    $LIST | grep "${BRANCH}-${fromos}-${fromtag}"  | while read line ; do
        tokens=($line)
        image=${tokens[0]}
        printf "%s" "$image" 
    done
}
extratags_from_target() {
    splitfrom=(`echo "$TARGET" | tr ":" "\n"`)
    fromos=${splitfrom[0]}
    fromtag=${splitfrom[1]}

    $LIST | grep "${BRANCH}-${fromos}-${fromtag}"  | while read line ; do
        tokens=($line)
        extratags=${tokens[@]:5}
        printf "%s" "${extratags}" 
    done
}

for container in ${CONTAINERS}; do
    echo "--- Pushing Container feelpp/${container}"

    #tag=$(echo "${BRANCH}" | sed -e 's/\//-/g')-$(cut -d- -f 2- <<< $(tag_from_target $TARGET))
    #tag=$(cut -d- -f 2- <<< $(tag_from_target $TARGET))
    tag=$(tag_from_target $TARGET)
        
    echo "--- Pushing feelpp/${container}:$tag"

    if [ "$noop" = "false" ]; then
        docker push "feelpp/${container}:$tag";
    else
        echo "docker push \"feelpp/${container}:$tag\"";
    fi

    
    # if [ "${latest}" = "true" ]; then
    #     echo "--- Tagging ${container}:${tag}"
    #     echo "Tagging feelpp/${container}:$tag as feelpp/${container}:latest"
    #     if [ "$noop" = "false" ]; then
    #         docker tag "feelpp/${container}:$tag" "feelpp/${container}:latest";
    #         docker push  "feelpp/${container}:latest";
    #     else
    #         echo "docker tag \"feelpp/${container}:$tag\" \"feelpp/${container}:latest\"";
    #         echo "docker push  \"feelpp/${container}:latest\"";
    #     fi
    # fi

    if [ "${BRANCH}" = "develop" -o  "${BRANCH}" = "master" ]; then
        #extratags=$(echo "${BRANCH}" | sed -e 's/\//-/g')-$(cut -d- -f 2- <<< $(extratags_from_target $TARGET))
        #extratags=$(cut -d- -f 2- <<< $(extratags_from_target $TARGET))
        extratags=$(extratags_from_target $TARGET)
        for aliastag in ${extratags[@]} ; do
            echo "--- Pushing feelpp/${container}:$aliastag"
            if [ "$noop" = "false" ]; then
                docker tag "feelpp/${container}:$tag" "feelpp/${container}:$aliastag";
                docker push "feelpp/${container}:$aliastag";
            else
                echo "docker tag \"feelpp/${container}:$tag\" \"feelpp/${container}:$aliastag\"";
                echo "docker push \"feelpp/${container}:$aliastag\"";
            fi
        done
    fi
done

echo -e "\033[33;32m--- All tags released!\033[0m"
