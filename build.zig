const std = @import("std");

// Build options equivalent to CMake options
const BuildOptions = struct {
    shared_libs: bool,
    build_examples: bool,
    use_system_mlx: bool,
    metal_output_path: []const u8,

    fn fromOptions(b: *std.Build) !BuildOptions {
        const default_rel_dir = "lib/metal";
        const default_path = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ b.install_prefix, default_rel_dir });
        const descprition = try std.fmt.allocPrint(b.allocator, "Absolute path to the metallib. Defaults to {s}", .{default_path});

        return .{
            // TODO check these defaults and align with MLX-C
            .shared_libs = b.option(bool, "shared-libs", "Build mlx as a shared library") orelse false,
            .build_examples = b.option(bool, "build-examples", "Build examples for mlx C") orelse true,
            .use_system_mlx = b.option(bool, "use-system-mlx", "Build mlx as a shared library") orelse false,

            // not used in og MLX but added here to better control the out dir of mlx.metallib (which contains the kernels)
            .metal_output_path = b.option([]const u8, "metal-output-path", descprition) orelse default_path,
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

    const options = try BuildOptions.fromOptions(b);

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

        // Passing the metal output dir like as a build param will do the following
        // - puts the metallib in this location
        // - defines the METAL_PATH macro so that the build artifact knows where to look for them
        // - this ensures that they are in the install_prefix of this library and not in the cache of the dependency
        const mlx = b.dependency("mlx", .{
            .@"metal-output-path" = options.metal_output_path,
        });
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
