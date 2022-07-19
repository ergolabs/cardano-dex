# SPDX-FileCopyrightText: 2021 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: CC0-1.0

{
  description = "cardano-dex-contracts";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";  

  inputs.haskell-nix.url = "github:input-output-hk/haskell.nix";
  inputs.nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
  inputs.nixpkgs-latest.url = "github:NixOS/nixpkgs?rev=a0a69be4b5ee63f1b5e75887a406e9194012b492";

  inputs.haskell-nix-extra-hackage.url = "github:mlabs-haskell/haskell-nix-extra-hackage?ref=separate-hackages";
  inputs.haskell-nix-extra-hackage.inputs.haskell-nix.follows = "haskell-nix";
  inputs.haskell-nix-extra-hackage.inputs.nixpkgs.follows = "nixpkgs";

  inputs.iohk-nix.url = "github:input-output-hk/iohk-nix";
  inputs.iohk-nix.flake = false;
  # we use sphinxcontrib-haddock input
  inputs.plutus.url = "github:input-output-hk/plutus";
  # https://github.com/input-output-hk/cardano-prelude/pull/163
  inputs.cardano-prelude.url = "github:mlabs-haskell/cardano-prelude?rev=713c7ae79a4d538fcd653c976a652913df1567b9";
  inputs.cardano-prelude.flake = false;
  inputs.cardano-base.url = "github:input-output-hk/cardano-base";
  inputs.cardano-base.flake = false;
  inputs.cardano-crypto.url = "github:input-output-hk/cardano-crypto?rev=07397f0e50da97eaa0575d93bee7ac4b2b2576ec";
  inputs.cardano-crypto.flake = false;
  inputs.haskell-language-server.url = "github:haskell/haskell-language-server";
  inputs.haskell-language-server.flake = false;

  inputs.plutarch.url = "github:plutonomicon/plutarch-plutus?rev=829f7d68f2f07718ae623b546a6b7fde1f2c8689";
  inputs.plutarch.flake = true;

  inputs.secp256k1-haskell.url = "github:haskoin/secp256k1-haskell";
  inputs.secp256k1-haskell.flake = false;

  # https://github.com/protolude/protolude/pull/133#issuecomment-1112150422 RC not uploaded to hackage yet...
  inputs.protolude.url = "github:protolude/protolude";
  inputs.protolude.flake = false;

  # 0.4.5 hasn't been published to Hackage...
  inputs.flat.url = "github:Quid2/flat";
  inputs.flat.flake = false;

  inputs.emanote.url = "github:srid/emanote/master";

  outputs = inputs@{ self, nixpkgs, nixpkgs-latest, iohk-nix, haskell-nix, plutarch, haskell-nix-extra-hackage, flake-utils, ... }:
    let
      supportedSystems = ["x86_64-linux"];

      perSystem = nixpkgs-latest.lib.genAttrs supportedSystems;

      haskellModules = [
        ({ config, pkgs, hsPkgs, ... }: {
          inherit nonReinstallablePkgs; # Needed for a lot of different things
          packages = {
            cardano-binary.doHaddock = false;
            cardano-binary.ghcOptions = [ "-Wwarn" ];
            cardano-crypto-class.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
            cardano-crypto-class.doHaddock = false;
            cardano-crypto-class.ghcOptions = [ "-Wwarn" ];
            cardano-crypto-praos.components.library.pkgconfig = pkgs.lib.mkForce [ [ pkgs.libsodium-vrf ] ];
            cardano-prelude.doHaddock = false; # somehow above options are not applied?
            cardano-prelude.ghcOptions = [ "-Wwarn" ];
          };
        })
      ];

      defaultGhcVersion = "ghc923";

      nonReinstallablePkgs = [
        "array"
        "array"
        "base"
        "binary"
        "bytestring"
        "Cabal"
        "containers"
        "deepseq"
        "directory"
        "exceptions"
        "filepath"
        "ghc"
        "ghc-bignum"
        "ghc-boot"
        "ghc-boot"
        "ghc-boot-th"
        "ghc-compact"
        "ghc-heap"
        # "ghci"
        # "haskeline"
        "ghcjs-prim"
        "ghcjs-th"
        "ghc-prim"
        "ghc-prim"
        "hpc"
        "integer-gmp"
        "integer-simple"
        "mtl"
        "parsec"
        "pretty"
        "process"
        "rts"
        "stm"
        "template-haskell"
        "terminfo"
        "text"
        "time"
        "transformers"
        "unix"
        "Win32"
        "xhtml"
      ];

      fourmoluFor = system: (pkgsFor' system).haskell.packages.ghc922.fourmolu_0_6_0_0;

      myhackages = system: compiler-nix-name: haskell-nix-extra-hackage.mkHackagesFor system compiler-nix-name (
        [
          "${inputs.flat}"
          "${inputs.protolude}"
          "${inputs.cardano-prelude}/cardano-prelude"
          "${inputs.cardano-crypto}"
          "${inputs.cardano-base}/binary"
          "${inputs.cardano-base}/cardano-crypto-class"
          "${inputs.plutus}/plutus-core"
          "${inputs.plutus}/plutus-ledger-api"
          "${inputs.plutus}/plutus-tx"
          "${inputs.plutus}/prettyprinter-configurable"
          "${inputs.plutus}/word-array"
          "${inputs.secp256k1-haskell}"
          "${inputs.plutus}/plutus-tx-plugin" # necessary for FFI tests
        ]
      );

      hlsFor' = compiler-nix-name: pkgs:
        pkgs.haskell-nix.cabalProject' {
          modules = [{
            packages.doExactConfig = true;
            inherit nonReinstallablePkgs;
            reinstallableLibGhc = false;
          }];
          inherit compiler-nix-name;
          src = "${inputs.haskell-language-server}";
          sha256map."https://github.com/pepeiborra/ekg-json"."7a0af7a8fd38045fd15fb13445bdcc7085325460" = "fVwKxGgM0S4Kv/4egVAAiAjV7QB5PBqMVMCfsv7otIQ=";
        };

      hlsFor = compiler-nix-name: system:
        let
          pkgs = pkgsFor system;
          oldGhc = "8107";
        in
        if (compiler-nix-name == "ghc${oldGhc}") then
          pkgs.haskell-language-server.override
            {
              supportedGhcVersions = [ oldGhc ];
            }
        else
          (hlsFor' compiler-nix-name pkgs).hsPkgs.haskell-language-server.components.exes.haskell-language-server;

      applyContractsDep = pkgs: o:
        let h = myhackages pkgs.system o.compiler-nix-name; in
        o // {
          modules = haskellModules ++ h.modules ++ (o.modules or [ ]);
          extra-hackages = h.extra-hackages ++ (o.extra-hackages or [ ]);
          extra-hackage-tarballs = h.extra-hackage-tarballs // (o.extra-hackage-tarballs or { });
          cabalProjectLocal = (o.cabalProjectLocal or "") + (
            ''
              allow-newer:
                cardano-binary:base
                , cardano-crypto-class:base
                , cardano-prelude:base
                , canonical-json:bytestring
                , plutus-core:ral
                , plutus-core:some
                , int-cast:base
                , inline-r:singletons
              constraints:
                OneTuple >= 0.3.1
                , Only >= 0.1
                , QuickCheck >= 2.14.2
                , StateVar >= 1.2.2
                , Stream >= 0.4.7.2
                , adjunctions >= 4.4
                , aeson >= 2.0.3.0
                , algebraic-graphs >= 0.6
                , ansi-terminal >= 0.11.1
                , ansi-wl-pprint >= 0.6.9
                , assoc >= 1.0.2
                , async >= 2.2.4
                , attoparsec >= 0.14.4
                , barbies >= 2.0.3.1
                , base-compat >= 0.12.1
                , base-compat-batteries >= 0.12.1
                , base-orphans >= 0.8.6
                , base16-bytestring >= 1.0.2.0
                , basement >= 0.0.12
                , bifunctors >= 5.5.11
                , bimap >= 0.4.0
                , bin >= 0.1.2
                , boring >= 0.2
                , boxes >= 0.1.5
                , cabal-doctest >= 1.0.9
                , call-stack >= 0.4.0
                , canonical-json >= 0.6.0.0
                , cardano-binary >= 1.5.0
                , cardano-crypto >= 1.1.0
                , cardano-crypto-class >= 2.0.0
                , cardano-prelude >= 0.1.0.0
                , case-insensitive >= 1.2.1.0
                , cassava >= 0.5.2.0
                , cborg >= 0.2.6.0
                , clock >= 0.8.2
                , colour >= 2.3.6
                , comonad >= 5.0.8
                , composition-prelude >= 3.0.0.2
                , concurrent-output >= 1.10.14
                , constraints >= 0.13.2
                , constraints-extras >= 0.3.2.1
                , contravariant >= 1.5.5
                , cryptonite >= 0.29
                , data-default >= 0.7.1.1
                , data-default-class >= 0.1.2.0
                , data-default-instances-containers >= 0.0.1
                , data-default-instances-dlist >= 0.0.1
                , data-default-instances-old-locale >= 0.0.1
                , data-fix >= 0.3.2
                , dec >= 0.0.4
                , dependent-map >= 0.4.0.0
                , dependent-sum >= 0.7.1.0
                , dependent-sum-template >= 0.1.1.1
                , deriving-aeson >= 0.2.8
                , deriving-compat >= 0.6
                , dictionary-sharing >= 0.1.0.0
                , distributive >= 0.6.2.1
                , dlist >= 1.0
                , dom-lt >= 0.2.3
                , double-conversion >= 2.0.2.0
                , erf >= 2.0.0.0
                , exceptions >= 0.10.4
                , extra >= 1.7.10
                , fin >= 0.2.1
                , flat >= 0.4.5
                , foldl >= 1.4.12
                , formatting >= 7.1.3
                , foundation >= 0.0.26.1
                , free >= 5.1.7
                , half >= 0.3.1
                , hashable >= 1.4.0.2
                , haskell-lexer >= 1.1
                , hedgehog >= 1.0.5
                , indexed-traversable >= 0.1.2
                , indexed-traversable-instances >= 0.1.1
                , integer-logarithms >= 1.0.3.1
                , invariant >= 0.5.5
                , kan-extensions >= 5.2.3
                , lazy-search >= 0.1.2.1
                , lazysmallcheck >= 0.6
                , lens >= 5.1
                , lifted-async >= 0.10.2.2
                , lifted-base >= 0.2.3.12
                , list-t >= 1.0.5.1
                , logict >= 0.7.0.3
                , megaparsec >= 9.2.0
                , memory >= 0.16.0
                , microlens >= 0.4.12.0
                , mmorph >= 1.2.0
                , monad-control >= 1.0.3.1
                , mono-traversable >= 1.0.15.3
                , monoidal-containers >= 0.6.2.0
                , mtl-compat >= 0.2.2
                , newtype >= 0.2.2.0
                , newtype-generics >= 0.6.1
                , nothunks >= 0.1.3
                , old-locale >= 1.0.0.7
                , old-time >= 1.1.0.3
                , optparse-applicative >= 0.16.1.0
                , parallel >= 3.2.2.0
                , parser-combinators >= 1.3.0
                , plutus-core >= 0.1.0.0
                , plutus-ledger-api >= 0.1.0.0
                , plutus-tx >= 0.1.0.0
                , pretty-show >= 1.10
                , prettyprinter >= 1.7.1
                , prettyprinter-configurable >= 0.1.0.0
                , primitive >= 0.7.3.0
                , profunctors >= 5.6.2
                , protolude >= 0.3.0
                , quickcheck-instances >= 0.3.27
                , ral >= 0.2.1
                , random >= 1.2.1
                , rank2classes >= 1.4.4
                , recursion-schemes >= 5.2.2.2
                , reflection >= 2.1.6
                , resourcet >= 1.2.4.3
                , safe >= 0.3.19
                , safe-exceptions >= 0.1.7.2
                , scientific >= 0.3.7.0
                , semialign >= 1.2.0.1
                , semigroupoids >= 5.3.7
                , semigroups >= 0.20
                , serialise >= 0.2.4.0
                , size-based >= 0.1.2.0
                , some >= 1.0.3
                , split >= 0.2.3.4
                , splitmix >= 0.1.0.4
                , stm >= 2.5.0.0
                , strict >= 0.4.0.1
                , syb >= 0.7.2.1
                , tagged >= 0.8.6.1
                , tasty >= 1.4.2.1
                , tasty-golden >= 2.3.5
                , tasty-hedgehog >= 1.1.0.0
                , tasty-hunit >= 0.10.0.3
                , temporary >= 1.3
                , terminal-size >= 0.3.2.1
                , testing-type-modifiers >= 0.1.0.1
                , text-short >= 0.1.5
                , th-abstraction >= 0.4.3.0
                , th-compat >= 0.1.3
                , th-expand-syns >= 0.4.9.0
                , th-extras >= 0.0.0.6
                , th-lift >= 0.8.2
                , th-lift-instances >= 0.1.19
                , th-orphans >= 0.13.12
                , th-reify-many >= 0.1.10
                , th-utilities >= 0.2.4.3
                , these >= 1.1.1.1
                , time-compat >= 1.9.6.1
                , transformers-base >= 0.4.6
                , transformers-compat >= 0.7.1
                , type-equality >= 1
                , typed-process >= 0.2.8.0
                , unbounded-delays >= 0.1.1.1
                , universe-base >= 1.1.3
                , unliftio-core >= 0.2.0.1
                , unordered-containers >= 0.2.16.0
                , uuid-types >= 1.0.5
                , vector >= 0.12.3.1
                , vector-algorithms >= 0.8.0.4
                , void >= 0.7.3
                , wcwidth >= 0.0.2
                , witherable >= 0.4.2
                , wl-pprint-annotated >= 0.1.0.1
                , word-array >= 0.1.0.0
                , secp256k1-haskell >= 0.6
                , inline-r >= 0.10.5
                , plutarch
            ''
          );
        };

      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ haskell-nix.overlay (import "${iohk-nix}/overlays/crypto") ];
        # This only does bad things for us...
        # inherit (haskell-nix) config;
      };
      pkgsFor' = system: import nixpkgs-latest { inherit system; };

      projectForGhc = compiler-nix-name: system:
        let
          pkgs = pkgsFor system;
          pkgs' = pkgsFor' system;
          pkgSet = pkgs.haskell-nix.cabalProject' (applyContractsDep pkgs {
            src = ./.;
            inherit compiler-nix-name;
            shell = {
              withHoogle = true;

              exactDeps = true;

              # We use the ones from Nixpkgs, since they are cached reliably.
              # Eventually we will probably want to build these with haskell.nix.
              nativeBuildInputs = [
                pkgs'.cabal-install
                pkgs'.hlint
                pkgs'.haskellPackages.cabal-fmt
                (fourmoluFor system)
                pkgs'.nixpkgs-fmt
                pkgSet.hsPkgs.hspec-discover.components.exes.hspec-discover
                (hlsFor compiler-nix-name system)
              ];
            };
          });
        in
        pkgSet;

      projectFor = projectForGhc defaultGhcVersion;
      projectFor810 = projectForGhc "ghc8107";

      # DON'T FORGET TO PUT YOUR PACKAGE NAME HERE, REMOVING `throw`
      packageName = "cardano-dex-contracts";

      flakeApp2Derivation = system: appName:
        (pkgsFor system).runCommand appName { } "${self.apps.${system}.${appName}.program} | tee $out";

    in {

      inherit hlsFor hlsFor' builtins;

      projectMatrix = {
        ghc9 = perSystem projectFor;
        ghc810 = perSystem projectFor810;
      };

      # Default build configuration.
      project = self.projectMatrix.ghc9;

      flake = perSystem (system: self.project.${system}.flake { });

      haddockProject = self.project;

      ghc810Flake = perSystem (system: self.projectMatrix.ghc810.${system}.flake { });

      packages = perSystem (system: self.flake.${system}.packages );

      overlay = (final: prev: {
        haskell-hello = final.haskellPackages.callCabal2nix "cardano-dex-contracts" ./. {};
      });

      check = perSystem (system:
        (pkgsFor system).runCommand "combined-test"
          {
            checksss = builtins.attrValues self.checks.${system};
          } ''
          echo $checksss
          touch $out
        ''
      );
      
      devShells = perSystem (system:
      {
        "ghc9" = self.flake.${system}.devShell;
      });

      devShell = perSystem (system: self.devShells.${system}."ghc9");
    };
}
