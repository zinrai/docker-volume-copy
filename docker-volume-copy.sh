#!/usr/bin/env bash
#
# docker-volume-copy.sh: copy the contents of a Docker volume into another one.
#
set -euo pipefail

IMAGE="busybox:stable-glibc"
USAGE="usage: docker-volume-copy.sh --source <volume> --dest <volume>"

src=""
dst=""

while [ $# -gt 0 ]; do
	case "$1" in
	--source)
		[ $# -ge 2 ] || {
			echo "error: --source needs a volume name" >&2
			exit 1
		}
		src="$2"
		shift 2
		;;
	--dest)
		[ $# -ge 2 ] || {
			echo "error: --dest needs a volume name" >&2
			exit 1
		}
		dst="$2"
		shift 2
		;;
	*)
		echo "$USAGE" >&2
		exit 1
		;;
	esac
done

[ -n "$src" ] && [ -n "$dst" ] || {
	echo "$USAGE" >&2
	exit 1
}

# A volume name reaching the command line as "-something", or carrying a colon
# or a slash, changes the structure of the docker invocation instead of only
# naming its target. Docker rejects such a name too, but by then the command
# has already been built around it.
for name in "$src" "$dst"; do
	case "$name" in
	-*)
		echo "error: volume name must not start with a dash: $name" >&2
		exit 1
		;;
	*:* | */*)
		echo "error: volume name must not contain a colon or a slash: $name" >&2
		exit 1
		;;
	esac
done

[ "$src" != "$dst" ] || {
	echo "error: source and destination are the same volume: $src" >&2
	exit 1
}

# docker volume inspect exits non-zero both for an absent volume and for an
# unreachable daemon, so the daemon is checked once up front. Without this, a
# stopped daemon is reported as a missing source volume.
echo "+ docker info" >&2
docker info >/dev/null 2>&1 || {
	echo "error: docker daemon is not available" >&2
	exit 1
}

echo "+ docker volume inspect $src" >&2
docker volume inspect "$src" >/dev/null 2>&1 || {
	echo "error: source volume not found: $src" >&2
	exit 1
}

# The filter returns nothing for a volume that does not exist yet, so the
# destination goes through the same check as the source.
for name in "$src" "$dst"; do
	echo "+ docker ps -q --filter volume=$name" >&2
	containers="$(docker ps -q --filter "volume=$name")"
	[ -z "$containers" ] || {
		echo "error: volume is in use by a running container: $name" >&2
		exit 1
	}
done

echo "+ docker volume inspect $dst" >&2
if docker volume inspect "$dst" >/dev/null 2>&1; then
	echo "+ docker run --rm -v $dst:/vol:ro $IMAGE ls -A /vol" >&2
	contents="$(docker run --rm -v "$dst:/vol:ro" "$IMAGE" ls -A /vol)"
	[ -z "$contents" ] || {
		echo "error: destination volume is not empty: $dst" >&2
		exit 1
	}
else
	echo "+ docker volume create $dst" >&2
	docker volume create "$dst" >/dev/null
fi

echo "+ docker run --rm -v $src:/src:ro -v $dst:/dst $IMAGE cp -a /src/. /dst/" >&2
docker run --rm -v "$src:/src:ro" -v "$dst:/dst" "$IMAGE" cp -a /src/. /dst/
