# docker-volume-copy

Copy the contents of a Docker volume into another volume.

A Docker volume cannot be renamed. Renaming one means creating a second volume, running a container that mounts both, and copying the contents across. This is that operation with its preconditions checked first: the source must exist and must not be mounted by a running container, and the destination must be empty.

## Usage

```bash
$ ./docker-volume-copy.sh --source postgres_data --dest postgres_data_v18
```

The source is left untouched, so the host holds both volumes once the copy finishes and what becomes of the original is a separate decision.

Every docker command is written to stderr as it runs and stdout stays empty, so a finished run reads as a record of what was done to the host. Any non-zero exit means the copy did not complete, and where docker itself failed its exit code is passed through rather than replaced.

The `docker` CLI needs access to the daemon, through the `docker` group or `sudo`, and the `busybox:stable-glibc` image is pulled on first use unless it is already on the host.

## Behavior

- A destination that does not exist is created as a plain local volume, with no labels and no driver options carried over from the source. A destination that needs them is created with `docker volume create` first and then passed in as an existing empty volume.
- Contents are copied with `cp -a`, which preserves permissions, ownership, timestamps and symlinks. Hard links become separate files and sparse files are expanded, so the destination can use more space than the source.
- A refused copy leaves the host exactly as it was found. A copy that fails after it started can leave the destination holding part of the data, and that destination is left in place rather than removed, so it is yours to inspect and remove.

## License

This project is licensed under the [MIT License](./LICENSE).
