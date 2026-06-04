# Bazel `--watchfs` stale `BUILD.bazel` (`.bazelignore` + `local_path_override`)

Minimal reproduction of a `--watchfs` correctness bug on macOS.

When a directory is listed in `.bazelignore` and also backs a module through `local_path_override`,
Bazel's macOS file watcher stops delivering change events for that directory. Edits to its
`BUILD.bazel` are missed, the cached file size goes stale, and the next build fails while loading the
package:

```
ERROR: error loading package '@@nested+//': File '.../external/nested+/BUILD.bazel' is unexpectedly longer than N bytes
```

## Layout

- `nested/` — a module added via `local_path_override` that is also listed in `.bazelignore`.
- `helper/` — a second module (not ignored) whose constant `nested/BUILD.bazel` loads.
- root `//:r` depends on `@nested//:m`.

## Reproduce

```
./repro.sh
```

The script builds `//:r` (which warms the watcher and caches the size of `nested/BUILD.bazel`), then
changes two files behind the watcher — it bumps `VERSION` in `helper/consts.bzl` to force `@nested` to
reload, and appends a line to `nested/BUILD.bazel` to grow it — and builds `//:r` again. The second
build fails with the error above. The script then restores the two files.

A `bazel shutdown` followed by a rebuild clears the stale state, which is why the failure looks
intermittent in day-to-day work.

## Why

On macOS, `MacOSXFsEventsDiffAwareness` passes the `.bazelignore` prefixes to
`FSEventStreamSetExclusionPaths`, so the watcher never receives events under `nested/`. Because
`nested/` also backs `@nested` (the external repo is a symlink that resolves back into the workspace),
its `BUILD.bazel` is still read by Bazel but is never invalidated. The cached `FileValue` keeps the old
size, and `readWithKnownFileSize` fails on the next package load. This behaviour was introduced in: https://github.com/bazelbuild/bazel/pull/26921/changes/7c14bfabc80a975f2ef45a23e82a815598ba8d80.

If you set the Bazel version to 8.5.0 in the .bazelversion file, the build will succeed.

