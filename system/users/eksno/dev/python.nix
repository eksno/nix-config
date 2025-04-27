
{ pkgs, ... }:
{
    environment.systemPackages = with pkgs; [
        python312
        python312Packages.black
        python312Packages.isort
        python312Packages.autoflake
        python312Packages.flake8
        python312Packages.onnxruntime
        uv
    ];
}
