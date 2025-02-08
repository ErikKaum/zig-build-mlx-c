const std = @import("std");

// Build options equivalent to CMake options
const BuildOptions = struct {
    shared_libs: bool,
    build_examples: bool,
    use_system_mlx: bool,

    fn fromOptions(b: *std.Build) BuildOptions {
        return .{
            // TODO check these defaults and align with MLX-C
            .shared_libs = b.option(bool, "shared-libs", "Build mlx as a shared library") orelse false,
            .build_examples = b.option(bool, "build-examples", "Build examples for mlx C") orelse true,
            .use_system_mlx = b.option(bool, "use-system-mlx", "Build mlx as a shared library") orelse false,
        };
    }
};

const CPP_FLAGS = [_][]const u8{
    "-std=c++17",
    "-fPIC",
    "-frtti",
    "-fexceptions",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    // TODO: standard optimizer gives a trap exit and null pointer bug, don't know exactly why but I have a hunch
    // const optimize = b.standardOptimizeOption(.{});
    const optimize = std.builtin.OptimizeMode.ReleaseFast;

    const options = BuildOptions.fromOptions(b);

    // Original MLX-C
    const og_mlx_c = b.dependency("mlx-c", .{
        .target = target,
        .optimize = optimize,
    });

    // Zig built MLX-C
    const lib = b.addStaticLibrary(.{
        .name = "mlx-c",
        .target = target,
        .optimize = optimize,
    });

    lib.installHeadersDirectory(og_mlx_c.path("."), ".", .{});
    lib.addIncludePath(og_mlx_c.path("."));

    lib.addCSourceFiles(.{
        .root = og_mlx_c.path("mlx/c"),
        .files = &sources,
        .flags = &CPP_FLAGS,
    });

    lib.linkLibCpp();

    if (options.use_system_mlx) {
        @panic("not implemented");
    } else {
        // TODO the optimization is not passed since it's hardcoded in the zig build of MLX to be ReleaseFast
        const mlx = b.dependency("mlx", .{ .target = target });
        lib.linkLibrary(mlx.artifact("mlx"));
    }

    if (options.build_examples) {
        for (examples) |example_source| {
            const example_name = std.fs.path.stem(example_source);
            const example_exe = b.addExecutable(.{
                .name = example_name,
                .target = target,
                .optimize = optimize,
            });
            example_exe.addCSourceFile(.{ .file = og_mlx_c.path(example_source) });
            example_exe.linkLibrary(lib);

            b.installArtifact(example_exe);
        }
        const copy_step = b.addInstallBinFile(og_mlx_c.path("examples/arrays.safetensors"), "arrays.safetensors");
        b.getInstallStep().dependOn(&copy_step.step);
    }

    b.installArtifact(lib);
}

////////////////////
/// Source files
///////////////////

const sources = [_][]const u8{
    "array.cpp",
    "closure.cpp",
    "compile.cpp",
    "device.cpp",
    "distributed.cpp",
    "distributed_group.cpp",
    "error.cpp",
    "fast.cpp",
    "fft.cpp",
    "io.cpp",
    "linalg.cpp",
    "map.cpp",
    "metal.cpp",
    // object.cpp, This was commented out int the original CMake for some reason
    "ops.cpp",
    "random.cpp",
    "stream.cpp",
    "string.cpp",
    "transforms.cpp",
    "transforms_impl.cpp",
    "vector.cpp",
};

const examples = [_][]const u8{
    "examples/example-closure.c",
    "examples/example-grad.c",
    "examples/example-metal-kernel.c",
    "examples/example-safe-tensors.c",
    "examples/example.c",
};
