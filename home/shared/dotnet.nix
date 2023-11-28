
{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    dotnet-sdk_7
    dotnetPackages.Nuget
    msbuild
  ];
}
