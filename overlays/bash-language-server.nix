# Override bash-language-server to fix memory leaks and CPU spikes
final: prev:
let
  patchFile = ./0001-fix-memory-leaks-and-cpu-spikes.patch;
in
{
  bash-language-server = prev.bash-language-server.overrideAttrs (oldAttrs: {
    # Apply patch manually in postPatch since the build uses pnpm compile
    # and patches need to be applied before TypeScript compilation
    postPatch = (oldAttrs.postPatch or "") + ''
      echo "Applying memory leak and CPU spike fixes..."
      patch -p1 < ${patchFile}
    '';
  });
}
