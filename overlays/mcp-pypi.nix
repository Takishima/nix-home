# Override mcp-pypi to use upstream with Nix flake patch
final: prev:
let
  mcpPypiSrc = prev.fetchFromGitHub {
    owner = "kimasplund";
    repo = "mcp-pypi";
    rev = "f4cf37de80592bd9c66da2a089b176931876bcf2"; # main as of 2025-06-24
    hash = "sha256-WkdULvQMhWCv8MBfHQV+DWwfhTwTOSPLEJhuXiX7Fvo=";
  };

  patchedSrc = prev.applyPatches {
    src = mcpPypiSrc;
    patches = [ ./0001-feat-Add-Nix-flake-to-mcp-pypi.patch ];
  };
in
{
  mcp-pypi = prev.python311Packages.buildPythonPackage {
    pname = "mcp-pypi";
    version = "2.7.1";
    pyproject = true;

    src = patchedSrc;

    build-system = with prev.python311Packages; [
      setuptools
      wheel
    ];

    dependencies = with prev.python311Packages; [
      mcp
      aiohttp
      packaging
      typer
      rich
      pydantic
      defusedxml
    ];

    doCheck = false;

    pythonImportsCheck = [
      "mcp_pypi"
      "mcp_pypi.server"
      "mcp_pypi.client"
      "mcp_pypi.cli"
    ];

    meta = with prev.lib; {
      description = "AI-powered Python package intelligence through MCP";
      homepage = "https://github.com/kimasplund/mcp-pypi";
      license = licenses.mit;
      mainProgram = "mcp-pypi";
    };
  };
}
