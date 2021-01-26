let
  sources = import ./nix/sources.nix;
  pkgs = import sources.dapptools {};
in
  pkgs.mkShell {
    buildInputs = with pkgs; [ dapp seth hevm niv ethsign ];
    DAPP_SOLC = if pkgs.stdenv.isDarwin
                then (toString ./solc-macos-0.7.5)
                else (toString ./solc-linux-0.7.5);
  }