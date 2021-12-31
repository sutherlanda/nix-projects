{
  description = "Project template and utilities in Nix.";
  outputs = { self }: {
    lib = import ./.;
  };
}
