# MLX-C built with Zig

> ⚠️ **Caution**: I've only tested this with Zig v 0.13.0.

This project builds MLX-C with Zig instead of the CMake build system. Meaning that these are not Zig language bindings to MLX-C. 

To create Zig bindings to MLX, there are two steps before arriving at the actual language bindings. [Zig-build-mlx](https://github.com/ErikKaum/zig-build-mlx) builds MLX with Zig, which this project wraps, and then this can be used downstream directly or to create a Zig wrapper ([example repo here]()) around MLX-C. Similarly to how the Swift bindings are built, but swapping CMake for Zig.

![mlx-c-chart](https://github.com/erikkaum/zig-build-mlx-c/blob/main/assets/chart-mlx-c.png?raw=true)

## Supported features

- [ ] Shared libs
- [x] Build examples
- [ ] Use system MLX

Also check [Zig-build-mlx](https://github.com/ErikKaum/zig-build-mlx?tab=readme-ov-file#supported-features) for a list of supported build flags for MLX.

## Usage

Create a `build.zig.zon` like so:

```zig
.{
    .name = "my-project",
    .version = "0.0.0",
    .dependencies = .{
        .mlx_c = .{
            .url = "https://github.com/erikkaum/zig-build-mlx-c/archive/<git-ref-here>.tar.gz",
            .hash = "",
        },
    },
}
```

And in your `build.zig`:

```zig
const mlx_c = b.dependency("mlx_c", .{ .target = target, .optimize = optimize });
exe.linkLibrary(mlx.artifact("mlx_c"));
```
