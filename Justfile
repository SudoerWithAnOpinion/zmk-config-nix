[private]
default:
    @just --list --unsorted

config := absolute_path('config')
build := absolute_path('.build')
out := absolute_path('firmware')
draw := absolute_path('draw')

build_matrix := "build.yaml"

# parse build.yaml and filter targets by expression
_parse_targets $expr: _check_yq_version
    #!/usr/bin/env bash
    attrs="[.board, .shield, .snippet, .keymap, .\"extra-conf\", .\"artifact-name\", .\"cmake-args\"]"
    filter="(($attrs | map(. // [.]) | combinations), ((.include // {})[] | $attrs)) | join(\",\")"
    echo "$(yq -r "$filter" {{build_matrix}} | grep -v "^," | grep -i "${expr/#all/.*}")"

# build firmware for single board & shield combination
_build_single $board $shield $snippet $keymap $extra_conf $artifact cmake_args $debug *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="${artifact:-${shield:+${shield// /+}-}${board//\//_}}"
    build_dir="{{ build / '$artifact' }}"
    effective_snippet="$snippet"
    snippet_args=()

    if [[ "$debug" == "1" ]]; then
        if [[ -z "$effective_snippet" ]]; then
            effective_snippet="zmk-usb-logging"
        elif [[ " $effective_snippet " != *" zmk-usb-logging "* ]]; then
            effective_snippet="$effective_snippet zmk-usb-logging"
        fi
    fi

    for snippet_name in $effective_snippet; do
        snippet_args+=( -S "$snippet_name" )
    done

    echo "Building firmware for $artifact..."
    west build -s zmk/app -d "$build_dir" -b $board {{ west_args }} "${snippet_args[@]}" -- \
        -DZMK_CONFIG="{{ config }}" ${shield:+-DSHIELD="$shield"} ${keymap:+-DKEYMAP_FILE="{{ config }}/$keymap.keymap"} ${extra_conf:+-DEXTRA_CONF_FILE="{{ config }}/$extra_conf.conf"} {{ cmake_args }}

    if [[ -f "$build_dir/zephyr/zmk.uf2" ]]; then
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.uf2" "{{ out }}/$artifact.uf2"
    else
        mkdir -p "{{ out }}" && cp "$build_dir/zephyr/zmk.bin" "{{ out }}/$artifact.bin"
    fi

# flash firmware for single board & shield combination
# only needed for boards which do not support UF2
_flash_single $board $shield $artifact:
    #!/usr/bin/env bash
    set -euo pipefail
    artifact="${artifact:-${shield:+${shield// /+}-}${board//\//_}}"
    build_dir="{{ build / '$artifact' }}"

    echo "Flashing firmware for $artifact..."
    west flash -d "$build_dir"

# List build targets. The sed chain removes version and build variants,
# and prints the shield (if given) or otherwise the board name.
[group('build & draw')]
[doc('list build targets')]
list:
    @just build_matrix={{build_matrix}} _parse_targets all \
        | sed 's|[@/][^,]*,|,|' \
        | sed 's|\([^,]*\),\([^,]\+\),.*|\2|' \
        | sed 's|\([^,]*\),,.*|\1|' \
        | sort \
        | column

# build firmware for targets matching <expr>
[group('build & draw')]
build expr *west_args:
    #!/usr/bin/env bash
    set -euo pipefail
    debug=0
    filtered_west_args=()

    set -- {{ west_args }}
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                debug=1
                shift
                ;;
            *)
                filtered_west_args+=("$1")
                shift
                ;;
        esac
    done

    targets=$(just build_matrix={{build_matrix}} _parse_targets {{ expr }})

    [[ -z $targets ]] && echo "No matching targets found. Aborting..." >&2 && exit 1
    echo "$targets" | while IFS=, read -r board shield snippet keymap extra_conf artifact cmake_args; do
        just _build_single "$board" "$shield" "$snippet" "$keymap" "$extra_conf" "$artifact" "$cmake_args" "$debug" "${filtered_west_args[@]}"
    done

# flash firmware for targets matching <expr>
[group('build & draw')]
flash expr: (build expr)
    #!/usr/bin/env bash
    set -euo pipefail
    targets=$(just build_matrix={{build_matrix}} _parse_targets {{ expr }})

    [[ -z $targets ]] && echo "No matching targets found. Aborting..." >&2 && exit 1
    echo "$targets" | while IFS=, read -r board shield snippet artifact cmake_args; do
        just _flash_single "$board" "$shield" "$artifact"
    done

# parse & plot keymap
draw: _check_yq_version
    #!/usr/bin/env bash
    set -euo pipefail

    default_shield='Corne_dongle'
    default_layout_name='layout_0'
    default_drawer_config='config-AkitsuEcho.yaml'
    default_layout_dtsi=''

    requested_keymap="{{ keymap }}"
    effective_keymap="$requested_keymap"
    effective_shield="$default_shield"
    effective_layout_name="$default_layout_name"
    effective_drawer_config="$default_drawer_config"
    effective_layout_dtsi="$default_layout_dtsi"
    render_png=0
    separate_layers=0
    targets_file="{{ draw }}/targets.yaml"

    positional=()
    set -- {{ FLAGS }}
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --png)
                render_png=1
                shift
                ;;
            --separate-layers)
                separate_layers=1
                shift
                ;;
            --shield)
                [[ $# -ge 2 ]] || { echo "Missing value for --shield" >&2; exit 1; }
                effective_shield="$2"
                shift 2
                ;;
            --layout-name)
                [[ $# -ge 2 ]] || { echo "Missing value for --layout-name" >&2; exit 1; }
                effective_layout_name="$2"
                shift 2
                ;;
            --config|--drawer-config)
                [[ $# -ge 2 ]] || { echo "Missing value for --config" >&2; exit 1; }
                effective_drawer_config="$2"
                shift 2
                ;;
            --layout-dtsi)
                [[ $# -ge 2 ]] || { echo "Missing value for --layout-dtsi" >&2; exit 1; }
                effective_layout_dtsi="$2"
                shift 2
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    positional+=("$1")
                    shift
                done
                ;;
            -*)
                echo "Unknown draw option: $1" >&2
                exit 1
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    # Legacy positional compatibility: shield, layout_name, drawer_config, layout_dtsi.
    [[ ${#positional[@]} -ge 1 ]] && effective_shield="${positional[0]}"
    [[ ${#positional[@]} -ge 2 ]] && effective_layout_name="${positional[1]}"
    [[ ${#positional[@]} -ge 3 ]] && effective_drawer_config="${positional[2]}"
    [[ ${#positional[@]} -ge 4 ]] && effective_layout_dtsi="${positional[3]}"

    # If keymap does not exist, treat the first arg as an alias in draw/targets.yaml.
    if [[ ! -f "{{ config }}/$effective_keymap.keymap" && -f "$targets_file" ]]; then
        alias_name="$effective_keymap"
        mapped_keymap=$(yq -r --arg n "$alias_name" '.[$n].keymap // empty' "$targets_file")
        [[ -n "$mapped_keymap" ]] || {
            echo "No keymap file for '$effective_keymap' and no alias entry in $targets_file" >&2
            exit 1
        }

        effective_keymap="$mapped_keymap"
        mapped_shield=$(yq -r --arg n "$alias_name" '.[$n].shield // empty' "$targets_file")
        mapped_layout_name=$(yq -r --arg n "$alias_name" '.[$n].layout_name // empty' "$targets_file")
        mapped_drawer_config=$(yq -r --arg n "$alias_name" '.[$n].drawer_config // empty' "$targets_file")
        mapped_layout_dtsi=$(yq -r --arg n "$alias_name" '.[$n].layout_dtsi // empty' "$targets_file")

        [[ -n "$mapped_shield" ]] && effective_shield="$mapped_shield"
        [[ -n "$mapped_layout_name" ]] && effective_layout_name="$mapped_layout_name"
        [[ -n "$mapped_drawer_config" ]] && effective_drawer_config="$mapped_drawer_config"
        [[ -n "$mapped_layout_dtsi" ]] && effective_layout_dtsi="$mapped_layout_dtsi"
    fi

    draw_dir="{{ draw }}/$effective_keymap"
    keymap_file="{{ config }}/$effective_keymap.keymap"
    keymap_yaml="$draw_dir/$effective_keymap.yaml"
    overview_yaml="$draw_dir/${effective_keymap}_overview.yaml"
    draw_args=()

    convert_svg_to_png() {
        input_svg="$1"
        output_png="$2"
        if command -v inkscape >/dev/null 2>&1; then
            inkscape "$input_svg" --export-type=png --export-filename="$output_png" >/dev/null 2>&1
        elif command -v rsvg-convert >/dev/null 2>&1; then
            rsvg-convert "$input_svg" -o "$output_png"
        else
            echo "PNG conversion requested but neither inkscape nor rsvg-convert is available on PATH." >&2
            echo "Enter the flake dev shell again after pulling dependency updates." >&2
            exit 1
        fi
    }

    mkdir -p "$draw_dir"

    if [[ "$effective_drawer_config" = /* ]]; then
        drawer_config_path="$effective_drawer_config"
    else
        drawer_config_path="{{ draw }}/$effective_drawer_config"
    fi

    [[ -f "$drawer_config_path" ]] || {
        echo "Could not find keymap-drawer config: $drawer_config_path" >&2
        exit 1
    }

    if [[ -n "$effective_layout_dtsi" ]]; then
        if [[ "$effective_layout_dtsi" = /* ]]; then
            layout_dtsi_path="$effective_layout_dtsi"
        else
            layout_dtsi_path="{{ config }}/boards/shields/$effective_layout_dtsi"
        fi
        [[ -f "$layout_dtsi_path" ]] || {
            echo "Could not find layout file: $layout_dtsi_path" >&2
            exit 1
        }
        draw_args+=( -d "$layout_dtsi_path" )
        if [[ -n "$effective_layout_name" ]]; then
            draw_args+=( -l "$effective_layout_name" )
        fi
    elif [[ -n "$effective_shield" ]]; then
        layout_dtsi_path="{{ config }}/boards/shields/$effective_shield/${effective_shield}-layouts.dtsi"
        [[ -f "$layout_dtsi_path" ]] || {
            echo "Could not find layout file: $layout_dtsi_path" >&2
            exit 1
        }
        draw_args+=( -d "$layout_dtsi_path" )
        if [[ -n "$effective_layout_name" ]]; then
            draw_args+=( -l "$effective_layout_name" )
        fi
    fi

    keymap -c "$drawer_config_path" parse -z "$keymap_file" --virtual-layers Combos >"$keymap_yaml"
    yq -Yi '.combos.[].l = ["Combos"]' "$keymap_yaml"
    keymap -c "$drawer_config_path" draw "$keymap_yaml" "${draw_args[@]}" >"$draw_dir/$effective_keymap.svg"

    if [[ "$render_png" -eq 1 ]]; then
        convert_svg_to_png "$draw_dir/$effective_keymap.svg" "$draw_dir/$effective_keymap.png"
    fi

    jq_expr='
        def extract_label: if type == "string" then . else .t end;
        def is_transparent: type == "object" and (.type == "trans" or .type == "held");
        .layers = {
        Base: [
            [.layers.Base, .layers.Nav, .layers.Fn, .layers.Num, .layers.Sys] | transpose[] |
            (.[0] | if type == "string" then {t: .} else . end) as $base |
            (.[1] | if is_transparent then null else extract_label end) as $nav |
            (.[2] | if is_transparent then null else extract_label end) as $fn |
            (.[3] | if is_transparent then null else extract_label end) as $num |
            (.[4] | if is_transparent then null else extract_label end) as $sys |
            $base
            + (if $nav == null then {} else {tr: $nav} end)
            + (if $fn == null then {} else {tl: $fn} end)
            + (if $num == null then {} else {bl: $num} end)
            + (if $sys == null then {} else {br: $sys} end)
        ],
        Combos: .layers.Combos
        } |
        .combos = [.combos[] | .l = ["Combos"]]
    '
    if yq -e '.layers.Base and .layers.Nav and .layers.Fn and .layers.Num and .layers.Sys' "$keymap_yaml" >/dev/null 2>&1; then
        yq -y "$jq_expr" "$keymap_yaml" >"$overview_yaml"
        keymap -c "$drawer_config_path" draw "$overview_yaml" "${draw_args[@]}" >"$draw_dir/${effective_keymap}_overview.svg"
        sed -i '/<text.*class="label"/d' "$draw_dir/${effective_keymap}_overview.svg"
    else
        rm -f "$overview_yaml" "$draw_dir/${effective_keymap}_overview.svg"
        echo "Skipping overview generation: expected layers Base/Nav/Fn/Num/Sys are not present in $effective_keymap." >&2
    fi

    if [[ "$separate_layers" -eq 1 ]]; then
        layer_dir="$draw_dir/layers"
        mkdir -p "$layer_dir"
        while IFS= read -r layer; do
            safe_layer="${layer// /_}"
            layer_svg="$layer_dir/${effective_keymap}_${safe_layer}.svg"
            keymap -c "$drawer_config_path" draw "$keymap_yaml" "${draw_args[@]}" -s "$layer" >"$layer_svg"
            if [[ "$render_png" -eq 1 ]]; then
                convert_svg_to_png "$layer_svg" "$layer_dir/${effective_keymap}_${safe_layer}.png"
            fi
        done < <(yq -r '.layers | keys | .[]' "$keymap_yaml")
    fi

# initialize the west workspace
[group('workspace')]
init:
    west init -l config
    west update --fetch-opt=--filter=blob:none
    west zephyr-export

# synchronize the west workspace (after manifest changes)
[group('workspace')]
sync:
    west update --fetch-opt=--filter=blob:none

# bump west manifest and re-sync the workspace
[group('workspace')]
bump-west: && sync
    pin-west bump

# bump nix toolchain (flake.lock)
[group('workspace')]
bump-nix:
    nix flake update --flake .

# clear build cache and artifacts
[group('cleanup')]
clean:
    rm -rf {{ build }} {{ out }}

# garbage-collect the nix store (system-wide)
[group('cleanup')]
nix-gc:
    nix-collect-garbage --delete-old

# format devicetree files, or a single directory recursively
[group('dev')]
[no-cd]
format *paths:
    #!/usr/bin/env bash
    set -euo pipefail
    paths=({{ paths }})

    if [[ ${#paths[@]} -eq 0 ]]; then
        echo "Usage: just format <file>... | <dir>" >&2
        exit 1
    fi

    for path in "${paths[@]}"; do
        if [[ -d "$path" ]]; then
            if [[ ${#paths[@]} -gt 1 ]]; then
                echo "A directory must be the only argument. Aborting..." >&2
                exit 1
            fi
            cd "$path"
            dts-format --fix
            exit 0
        fi
    done

    dts-format --fix "${paths[@]}"

# run test suites (--auto-accept updates the snapshot)
[group('dev')]
[no-cd]
test $testpath *FLAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    testcase=$(basename "$testpath")
    build_dir="{{ build / "tests" / '$testcase' }}"
    config_dir="{{ '$(pwd)' / '$testpath' }}"
    cd {{ justfile_directory() }}

    if [[ "{{ FLAGS }}" != *"--no-build"* ]]; then
        echo "Running $testcase..."
        rm -rf "$build_dir"
        west build -s zmk/app -d "$build_dir" -b native_sim//zmk_test_mock -- \
            -DCONFIG_ASSERT=y -DZMK_CONFIG="$config_dir"
    fi

    ${build_dir}/zephyr/zmk.exe | sed -e "s/.*> //" |
        tee ${build_dir}/keycode_events.full.log |
        sed -n -f ${config_dir}/events.patterns > ${build_dir}/keycode_events.log
    if [[ "{{ FLAGS }}" == *"--verbose"* ]]; then
        cat ${build_dir}/keycode_events.log
    fi

    if [[ "{{ FLAGS }}" == *"--auto-accept"* ]]; then
        cp ${build_dir}/keycode_events.log ${config_dir}/keycode_events.snapshot
    fi
    diff -auZ ${config_dir}/keycode_events.snapshot ${build_dir}/keycode_events.log

# warn user if they are using golang-yq and not python-yq
[no-exit-message]
_check_yq_version:
    #!/usr/bin/env bash
    if yq --help 2>&1 | grep -qi 'eval'; then
        echo "This script requires python-yq, but PATH contains golang-yq" >&2
        echo "Please install python-yq or use the included nix shell" >&2
        exit 1
    fi
