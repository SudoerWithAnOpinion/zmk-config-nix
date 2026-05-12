# Sudo's zmk-config

This is our personal [ZMK firmware](https://github.com/zmkfirmware/zmk/)
configuration forked from [urob](https://github.com/urob/zmk-config/). 
It contains the configurations and layouts for the various keyboards We build.

The configuration currently builds against `main` of upstream ZMK.

## Local build environment

We streamline Our local build process using `nix`, `direnv` and `just`. This
automatically sets up a virtual development environment with `west`, the
`zephyr-sdk` and all its dependencies when `cd`-ing into the ZMK-workspace. The
environment is _completely isolated_ and won't pollute your system.

### Setup

#### Pre-requisites

1. Install the `nix` package manager:

   ```bash
   # Install Nix with flake support enabled
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
      sh -s -- install --no-confirm

   # Start the nix daemon without restarting the shell
   . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
   ```

2. Install [`direnv`](https://direnv.net/) (and optionally but recommended
   [`nix-direnv`](https://github.com/nix-community/nix-direnv)[^4]) using your
   package manager of choice. E.g., using the `nix` package manager that we just
   installed[^5]:

   ```
   nix profile install nixpkgs#direnv nixpkgs#nix-direnv
   ```

3. Set up the `direnv` [shell-hook](https://direnv.net/docs/hook.html) for your
   shell. E.g., for `bash`:

   ```bash
   # Install the shell-hook
   echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

   # Enable nix-direnv (if installed in the previous step)
   mkdir -p ~/.config/direnv
   echo 'source $HOME/.nix-profile/share/nix-direnv/direnvrc' >> ~/.config/direnv/direnvrc

   # Optional: make direnv less verbose
   echo '[global]\nwarn_timeout = "2m"\nhide_env_diff = true' >> ~/.config/direnv/direnv.toml

   # Source the bashrc to activate the hook (or start a new shell)
   source ~/.bashrc
   ```

#### Set up the workspace

1. Clone _your fork_ of this repository.

   ```bash
   git clone https://github.com/YOUR_USERNAME/zmk-config zmk-config
   ```

2. Enter the workspace and set up the environment.

   ```bash
   # The first time you enter the workspace, you will be prompted to allow direnv
   cd zmk-config

   # Allow direnv for the workspace, which will set up the environment (this takes a while)
   direnv allow

   # Initialize the Zephyr workspace and pull in the ZMK dependencies
   # (same as `west init -l config && west update && west zephyr-export`)
   just init
   ```

### Usage

After following the steps above your workspace should look like this:

```
zmk-workspace
├── config
├── firmware (created after building)
├── modules
├── zephyr
└── zmk
```

#### Building the firmware

To build the firmware, simply type `just build all` from anywhere in the
workspace. This will parse `build.yaml` and build the firmware for all board and
shield combinations listed there.

To only build the firmware for a specific target, use `just build <target>`.
This will build the firmware for all matching board and shield combinations. For
instance, to build the firmware for my Corneish Zen, I can type
`just build zen`, which builds both `corneish_zen_v2_left` and
`corneish_zen_v2_right`. (`just list` shows all valid build targets.)

Additional arguments to `just build` are passed on to `west`. For instance, a
pristine build can be triggered with `just build all -p`.

(For this particular example, there is also a `just clean` recipe, which clears
the build cache. To list all available recipes, type `just`. Bonus tip: `just`
provides
[completion scripts](https://github.com/casey/just?tab=readme-ov-file#shell-completion-scripts)
for many shells.)

#### Drawing the keymap

The build environment packages
[keymap-drawer](https://github.com/caksoylar/keymap-drawer). `just draw` parses
`base.keymap` and draws it to `draw/base.svg`.

#### Devicetree formatter (experimental)

The build environment also packages a (patched and wrapped) version of 
[`dts-linter`](https://github.com/kylebonnici/dts-linter). Usage:
```sh
dts-format [--fix] [--use-tabs] [--tab-width <int>] [filelist]
```
If no `filelist` is provided, `dts-format` will format all `dts`, `dtsi`, `overlay` and `keymap` 
files *anywhere* below the current working directory -- Don't run this at the repo root unless you 
want to format the entire zmk and zephyr base!.

By default, `dts-format` will print a diff. Use the `--fix` flag to apply all changes directly to
the source files. 

Use `--use-tabs` to indent lines with tabs (default is `spaces`) and use `--tab-width` to specify the
number of spaces per indentation level (default is `4`).

To protect manually aligned keymap blocks, guard them by `// dts-format off` and `// dts-format on` comments.

#### Hacking the firmware

To make changes to the ZMK source or any of the modules, simply edit the files
or use `git` to pull in changes.

To switch to any remote branches or tags, use `git fetch` inside a module
directory to make the remote refs locally available. Then switch to the desired
branch with `git checkout <branch>` as usual. You may also want to register
additional remotes to work with or consider making them the default in
`config/west.yml`.

#### Updating the build environment

To update the ZMK dependencies, use `just update`. This will pull in the latest
version of ZMK and all modules specified in `config/west.yml`. Make sure to
commit and push all local changes you have made to ZMK and the modules before
running this command, as this will overwrite them.

To upgrade the Zephyr SDK and Python build dependencies, use `just upgrade-sdk`. (Use with care --
Running this will upgrade all Nix packages and may end up breaking the build environment. When in
doubt, I recommend keeping the environment pinned to `flake.lock`, which is [continuously
tested](https://github.com/urob/zmk-config/actions/workflows/test-build-env.yml) on all systems.)

## Bonus: A (moderately) faster Github Actions Workflow

Using the same Nix-based environment, I have set up a drop-in replacement for
the default ZMK Github Actions build workflow. While mainly a proof-of-concept,
it does run moderately faster, especially with a cold cache.

## Issues and workarounds

Since I switched from QMK to ZMK I have been very impressed with how easy it is
to set up relatively complex layouts in ZMK. For the most parts I don't miss any
functionality (to the contrary, I found that ZMK supports many features natively
that would require complex user-space implementations in QMK). Below are a few
remaining issues:

- ZMK does not yet support "tap-only" combos
  ([#544](https://github.com/zmkfirmware/zmk/issues/544)), requiring a brief
  pause when wanting to chord HRMs that overlap with combo positions. As a
  workaround, I implemented all homerow combos as homerow-mod-combos. This is
  good enough for day-to-day, but does not address all edge cases (eg changing
  active mods).
- Very minor: `&bootloader` doesn't work with stm32 boards like the Planck
  ([#1086](https://github.com/zmkfirmware/zmk/issues/1086))

## Related resources

- The
  [collection](https://github.com/search?q=topic%3Azmk-module+fork%3Atrue+owner%3Aurob+&type=repositories)
  of ZMK modules used in this configuration.
- A ZMK-centric
  [introduction to Git](https://gist.github.com/urob/68a1e206b2356a01b876ed02d3f542c7)
  (useful for maintaining your own ZMK fork with a custom selection of PRs).

[^1]:
    I call it "timer-less", because the large tapping-term makes the behavior
    insensitive to the precise timings. One may say that there is still the
    `require-prior-idle` timeout. However, with both a large tapping-term and
    positional-hold-taps, the behavior is _not_ actually sensitive to the
    `require-prior-idle` timing: All it does is reduce the delay in typing.

[^2]:
    The delay is determined by how quickly a key is released and is not directly
    related to the tapping-term. But regardless of its duration, most people
    still find it noticeable and disruptive.

[^3]:
    E.g, if your WPM is 70 or larger, then the default of 150ms (=10500/70)
    should work well. The rule of thumb is based on an average character length
    of 4.7 for English words. Taking into account 1 extra tap for `space`, this
    yields a minimum `require-prior-idle-ms` of (60 \* 1000) / (5.7 \* x) ≈ 10500
    / x milliseconds. The approximation errs on the safe side, as in practice
    home row taps tend to be faster than average.

[^4]:
    `nix-direnv` provides a vastly improved caching experience compared to only
    having `direnv`, making entering and exiting the workspace instantaneous
    after the first time.

[^5]:
    This will permanently install the packages into your local profile, forgoing
    many of the benefits that make Nix uniquely powerful. A better approach,
    though beyond the scope of this document, is to use `home-manager` to
    maintain your user environment.
