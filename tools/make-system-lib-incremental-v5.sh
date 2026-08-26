#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Build a signed M86 recovery ZIP that replaces selected /system libraries.

Usage:
  device/meizu/m86/tools/make-system-lib-incremental-v5.sh \
    --name NAME \
    --title TITLE \
    --base-label LABEL \
    --output-dir DIR \
    --payload SOURCE:/system/lib/TARGET.so:BASE_SHA256 \
    [--payload SOURCE:/system/lib/TARGET2.so:BASE_SHA256] \
    [--verify /system/lib/UNCHANGED.so:SHA256] \
    [--commit REPOSITORY:COMMIT] \
    [--test-note TEXT] \
    [--force]

The generated installer:
  * accepts the declared base hash or the new payload hash (safe reflash);
  * verifies unchanged files passed with --verify;
  * reuses/remounts the active system mount and never unmounts it;
  * does not touch boot, vendor, Magisk, or files outside /system/lib{,64}.

NAME must contain only lowercase letters, digits, and dashes. SOURCE and output
paths may be relative to the Android source root. Run the tool from any path
inside the Android source tree, or set ANDROID_BUILD_TOP.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

sha256_file() {
    sha256sum "$1" | awk '{print $1}'
}

find_android_top() {
    local candidate

    if [[ -n "${ANDROID_BUILD_TOP:-}" ]]; then
        candidate="$(readlink -f "$ANDROID_BUILD_TOP")"
        [[ -f "$candidate/build/make/core/envsetup.mk" ]] ||
            die "ANDROID_BUILD_TOP is not an Android source tree: $candidate"
        printf '%s\n' "$candidate"
        return
    fi

    candidate="$(readlink -f "$PWD")"
    while [[ "$candidate" != "/" ]]; do
        if [[ -f "$candidate/build/make/core/envsetup.mk" ]]; then
            printf '%s\n' "$candidate"
            return
        fi
        candidate="$(dirname "$candidate")"
    done

    die "cannot locate Android source root; set ANDROID_BUILD_TOP"
}

resolve_source() {
    local source_path="$1"
    if [[ "$source_path" = /* ]]; then
        readlink -f "$source_path"
    else
        readlink -f "$android_top/$source_path"
    fi
}

validate_sha() {
    [[ "$1" =~ ^[0-9a-fA-F]{64}$ ]] || die "invalid SHA-256: $1"
}

validate_target() {
    local target="$1"
    case "$target" in
        /system/lib/*|/system/lib64/*) ;;
        *) die "target must be below /system/lib or /system/lib64: $target" ;;
    esac
    [[ "$target" != *".."* && "$target" != *"|"* && "$target" != *[[:space:]]* ]] ||
        die "unsafe target path: $target"
}

escape_edify() {
    local value="$1"
    [[ "$value" != *$'\n'* && "$value" != *'"'* && "$value" != *'\\'* ]] ||
        die "Edify text cannot contain newlines, quotes, or backslashes: $value"
    printf '%s' "$value"
}

name=""
title=""
base_label=""
output_dir=""
force=0
declare -a payload_specs=()
declare -a verify_specs=()
declare -a commits=()
declare -a test_notes=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name|--title|--base-label|--output-dir|--payload|--verify|--commit|--test-note)
            [[ $# -ge 2 ]] || die "missing value for $1"
            option="$1"
            value="$2"
            shift 2
            case "$option" in
                --name) name="$value" ;;
                --title) title="$value" ;;
                --base-label) base_label="$value" ;;
                --output-dir) output_dir="$value" ;;
                --payload) payload_specs+=("$value") ;;
                --verify) verify_specs+=("$value") ;;
                --commit) commits+=("$value") ;;
                --test-note) test_notes+=("$value") ;;
            esac
            ;;
        --force)
            force=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
done

[[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "invalid or missing --name"
[[ -n "$title" ]] || die "missing --title"
[[ -n "$base_label" ]] || die "missing --base-label"
[[ -n "$output_dir" ]] || die "missing --output-dir"
[[ ${#payload_specs[@]} -gt 0 ]] || die "at least one --payload is required"
escape_edify "$title" >/dev/null
escape_edify "$base_label" >/dev/null

android_top="$(find_android_top)"
if [[ "$output_dir" != /* ]]; then
    output_dir="$android_top/$output_dir"
fi
output_dir="$(readlink -m "$output_dir")"

updater_binary="$android_top/out/target/product/m86/obj/EXECUTABLES/updater_intermediates/updater"
signapk_jar="$android_top/out/host/linux-x86/framework/signapk.jar"
testkey_cert="$android_top/build/make/target/product/security/testkey.x509.pem"
testkey_pk8="$android_top/build/make/target/product/security/testkey.pk8"
conscrypt_dir="$android_top/out/soong/.intermediates/external/conscrypt/libconscrypt_openjdk_jni/linux_glibc_x86_64_shared"

[[ -x "$updater_binary" ]] || die "missing recovery updater; build m86 target files first: $updater_binary"
[[ -f "$signapk_jar" ]] || die "missing signapk.jar: $signapk_jar"
[[ -f "$testkey_cert" && -f "$testkey_pk8" ]] || die "missing Android testkey"
[[ -f "$conscrypt_dir/libconscrypt_openjdk_jni.so" ]] || die "missing host Conscrypt JNI library"

mkdir -p "$output_dir"
zip_name="m86-${name}-no-boot-v5.zip"
final_zip="$output_dir/$zip_name"
idsig="$final_zip.idsig"
readme="$output_dir/README.md"
sums="$output_dir/SHA256SUMS"

if [[ $force -ne 1 ]]; then
    for output in "$final_zip" "$idsig" "$readme" "$sums"; do
        [[ ! -e "$output" ]] || die "output exists (use --force): $output"
    done
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/m86-incremental-v5.XXXXXX")"
cleanup() {
    [[ -n "${work_dir:-}" && "$work_dir" = "${TMPDIR:-/tmp}/m86-incremental-v5."* ]] &&
        rm -rf "$work_dir"
}
trap cleanup EXIT

package_root="$work_dir/package-root"
mkdir -p "$package_root/META-INF/com/google/android" "$package_root/payload/system"
cp "$updater_binary" "$package_root/META-INF/com/google/android/update-binary"
chmod 0755 "$package_root/META-INF/com/google/android/update-binary"

manifest="$package_root/payload-manifest-v5.txt"
: > "$manifest"
declare -a payload_rows=()
declare -a verify_rows=()
declare -A declared_targets=()

for spec in "${payload_specs[@]}"; do
    IFS=: read -r source target base_sha extra <<< "$spec"
    [[ -n "$source" && -n "$target" && -n "$base_sha" && -z "${extra:-}" ]] ||
        die "invalid --payload (expected SOURCE:TARGET:BASE_SHA256): $spec"
    validate_target "$target"
    validate_sha "$base_sha"
    [[ -z "${declared_targets[$target]:-}" ]] || die "duplicate target: $target"
    declared_targets["$target"]=payload
    source="$(resolve_source "$source")"
    [[ -f "$source" && -s "$source" ]] || die "payload source is missing or empty: $source"
    relative="${target#/system/}"
    new_sha="$(sha256_file "$source")"
    destination="$package_root/payload/system/$relative"
    mkdir -p "$(dirname "$destination")"
    cp "$source" "$destination"
    chmod 0644 "$destination"
    printf 'P|%s|%s|%s\n' "$relative" "${base_sha,,}" "$new_sha" >> "$manifest"
    payload_rows+=("$target|${base_sha,,}|$new_sha|$source")
done

for spec in "${verify_specs[@]}"; do
    IFS=: read -r target expected_sha extra <<< "$spec"
    [[ -n "$target" && -n "$expected_sha" && -z "${extra:-}" ]] ||
        die "invalid --verify (expected TARGET:SHA256): $spec"
    validate_target "$target"
    validate_sha "$expected_sha"
    [[ -z "${declared_targets[$target]:-}" ]] || die "duplicate target: $target"
    declared_targets["$target"]=verify
    relative="${target#/system/}"
    printf 'V|%s|%s|%s\n' "$relative" "${expected_sha,,}" "${expected_sha,,}" >> "$manifest"
    verify_rows+=("$target|${expected_sha,,}")
done

installer="$package_root/install-${name}-v5.sh"
cat > "$installer" <<'INSTALLER'
#!/sbin/sh

# Generated by device/meizu/m86/tools/make-system-lib-incremental-v5.sh.
# Reuse the active system mount and never unmount a recovery volume.

payload_root="$1"
manifest="$2"
system_block="/dev/block/platform/15570000.ufs/by-name/system"
system_content_root=""
target_mount=""
target_device=""
target_options=""
staged_list="/tmp/m86-incremental-v5-staged.$$"

[ -d "$payload_root/system" ] || exit 10
[ -s "$manifest" ] || exit 11
: > "$staged_list" || exit 12

cleanup_staged() {
    while IFS= read -r temporary; do
        [ -n "$temporary" ] && rm -f "$temporary"
    done < "$staged_list"
    rm -f "$staged_list"
}
trap cleanup_staged EXIT

anchor_relative=""
while IFS='|' read -r kind relative base_sha new_sha; do
    case "$kind" in
        P|V) anchor_relative="$relative"; break ;;
    esac
done < "$manifest"
[ -n "$anchor_relative" ] || exit 13

find_system_content_root() {
    for root in /system /system_root /mnt/system; do
        for prefix in "" system; do
            if [ -n "$prefix" ]; then
                candidate="$root/$prefix/$anchor_relative"
            else
                candidate="$root/$anchor_relative"
            fi
            if [ -f "$candidate" ]; then
                if command -v readlink >/dev/null 2>&1; then
                    resolved_candidate="$(readlink -f "$candidate" 2>/dev/null)"
                    [ -n "$resolved_candidate" ] && candidate="$resolved_candidate"
                fi
                system_content_root="${candidate%/$anchor_relative}"
                return 0
            fi
        done
    done
    return 1
}

find_system_mount() {
    best_length=0
    while read -r mounted_device mount_point fs_type mount_options remainder; do
        matches=0
        if [ "$mount_point" = "/" ]; then
            matches=1
        else
            case "$system_content_root" in
                "$mount_point"|"$mount_point"/*) matches=1 ;;
            esac
        fi
        if [ "$matches" -eq 1 ]; then
            mount_length=${#mount_point}
            if [ "$mount_length" -gt "$best_length" ]; then
                best_length="$mount_length"
                target_mount="$mount_point"
                target_device="$mounted_device"
                target_options="$mount_options"
            fi
        fi
    done < /proc/mounts
    [ -n "$target_mount" ]
}

if ! find_system_content_root; then
    mounted_system=""
    while read -r mounted_device mount_point fs_type mount_options remainder; do
        case "$mounted_device" in
            "$system_block"|*/by-name/system|*/by-name/SYSTEM)
                mounted_system="$mount_point"
                break
                ;;
        esac
    done < /proc/mounts
    if [ -z "$mounted_system" ]; then
        mkdir -p /system || exit 20
        mount -t ext4 "$system_block" /system || exit 21
    fi
    find_system_content_root || exit 22
fi

# Validate every installed base and every payload before remounting writable.
while IFS='|' read -r kind relative base_sha new_sha; do
    target="$system_content_root/$relative"
    [ -s "$target" ] || exit 23
    case "$kind" in
        P)
            source="$payload_root/system/$relative"
            [ -s "$source" ] || exit 24
            if command -v sha256sum >/dev/null 2>&1; then
                set -- $(sha256sum "$source" 2>/dev/null)
                [ "$1" = "$new_sha" ] || exit 25
                set -- $(sha256sum "$target" 2>/dev/null)
                [ "$1" = "$base_sha" ] || [ "$1" = "$new_sha" ] || exit 26
            fi
            ;;
        V)
            if command -v sha256sum >/dev/null 2>&1; then
                set -- $(sha256sum "$target" 2>/dev/null)
                [ "$1" = "$base_sha" ] || exit 27
            fi
            ;;
        *) exit 28 ;;
    esac
done < "$manifest"

find_system_mount || exit 29
case ",$target_options," in
    *,rw,*) ;;
    *)
        mount -o remount,rw "$target_device" "$target_mount" >/dev/null 2>&1 ||
        mount -o remount,rw "$target_mount" >/dev/null 2>&1 ||
        exit 30
        ;;
esac

# Stage and verify all replacements before moving any of them into place.
while IFS='|' read -r kind relative base_sha new_sha; do
    [ "$kind" = "P" ] || continue
    source="$payload_root/system/$relative"
    target="$system_content_root/$relative"
    temporary="$target.m86-incremental-v5.new.$$"
    cp "$source" "$temporary" || exit 31
    chown 0:0 "$temporary" || exit 32
    chmod 0644 "$temporary" || exit 33
    if command -v chcon >/dev/null 2>&1; then
        chcon u:object_r:system_lib_file:s0 "$temporary" || exit 34
    fi
    if command -v cmp >/dev/null 2>&1; then
        cmp "$source" "$temporary" >/dev/null 2>&1 || exit 35
    fi
    printf '%s\n' "$temporary" >> "$staged_list"
done < "$manifest"

while IFS='|' read -r kind relative base_sha new_sha; do
    [ "$kind" = "P" ] || continue
    target="$system_content_root/$relative"
    temporary="$target.m86-incremental-v5.new.$$"
    mv -f "$temporary" "$target" || exit 36
    if command -v sha256sum >/dev/null 2>&1; then
        set -- $(sha256sum "$target" 2>/dev/null)
        [ "$1" = "$new_sha" ] || exit 37
    fi
done < "$manifest"

sync
trap - EXIT
rm -f "$staged_list"
exit 0
INSTALLER
chmod 0755 "$installer"

updater_script="$package_root/META-INF/com/google/android/updater-script"
safe_title="$(escape_edify "$title")"
safe_base_label="$(escape_edify "$base_label")"
cat > "$updater_script" <<EOF
assert(getprop("ro.product.device") == "m86" ||
       getprop("ro.build.product") == "m86" ||
       getprop("ro.product.device") == "PRO5" ||
       getprop("ro.build.product") == "PRO5" ||
       getprop("ro.product.device") == "pro5" ||
       getprop("ro.build.product") == "pro5" ||
       getprop("ro.product.device") == "mx5pro" ||
       getprop("ro.build.product") == "mx5pro" ||
       getprop("ro.product.device") == "niux" ||
       getprop("ro.build.product") == "niux" ||
       getprop("ro.product.device") == "NIUX" ||
       getprop("ro.build.product") == "NIUX" ||
       abort("This package is only for Meizu PRO 5 / m86."));

ui_print("$safe_title");
ui_print("Required base: $safe_base_label");
ui_print("Replacing ${#payload_rows[@]} system library file(s)");
ui_print("Verifying ${#verify_rows[@]} unchanged dependency file(s)");
ui_print("Boot image, vendor and Magisk are left untouched");
ui_print("v5 mount logic: reuse system and never unmount it");

package_extract_dir("payload", "/tmp/m86-${name}-payload") ||
    abort("Failed to extract incremental payload");
package_extract_file("payload-manifest-v5.txt", "/tmp/m86-${name}-manifest.txt") ||
    abort("Failed to extract incremental manifest");
package_extract_file("install-${name}-v5.sh", "/tmp/install-${name}-v5.sh") ||
    abort("Failed to extract incremental installer");
set_metadata("/tmp/install-${name}-v5.sh", "uid", 0, "gid", 0, "mode", 0755);
assert(run_program("/tmp/install-${name}-v5.sh",
                   "/tmp/m86-${name}-payload",
                   "/tmp/m86-${name}-manifest.txt") == 0);

ui_print("Incremental update installed");
ui_print("Done. Boot image was not checked or modified.");
EOF

sh -n "$installer"
find "$package_root" -exec touch -t 200901010000 {} +
unsigned_zip="$work_dir/${name}-unsigned.zip"
(
    cd "$package_root"
    zip -X -q -r "$unsigned_zip" META-INF "install-${name}-v5.sh" payload-manifest-v5.txt payload
)

LD_LIBRARY_PATH="$conscrypt_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    java -jar "$signapk_jar" --min-sdk-version 21 --enable-v4 \
    "$testkey_cert" "$testkey_pk8" "$unsigned_zip" "$work_dir/$zip_name" "$work_dir/$zip_name.idsig"

unzip -t "$work_dir/$zip_name" >/dev/null
payload_entry_count="$(unzip -Z1 "$work_dir/$zip_name" | awk '/^payload\/system\// && !/\/$/ { count++ } END { print count + 0 }')"
[[ "$payload_entry_count" -eq "${#payload_rows[@]}" ]] || die "signed ZIP payload count mismatch"
[[ -s "$work_dir/$zip_name.idsig" ]] || die "v4 idsig was not generated"
grep -a -q 'APK Sig Block 42' "$work_dir/$zip_name" || die "APK Signature Block is missing"

for row in "${payload_rows[@]}"; do
    IFS='|' read -r target base_sha new_sha source <<< "$row"
    archived_sha="$(unzip -p "$work_dir/$zip_name" "payload${target}" | sha256sum | awk '{print $1}')"
    [[ "$archived_sha" = "$new_sha" ]] || die "archived payload hash mismatch: $target"
done

mv -f "$work_dir/$zip_name" "$final_zip"
mv -f "$work_dir/$zip_name.idsig" "$idsig"
zip_sha="$(sha256_file "$final_zip")"
idsig_sha="$(sha256_file "$idsig")"

{
    printf '%s  %s\n' "$zip_sha" "$zip_name"
    printf '%s  %s\n' "$idsig_sha" "$zip_name.idsig"
} > "$sums"

{
    printf '# %s\n\n' "$title"
    printf 'Generated by `device/meizu/m86/tools/make-system-lib-incremental-v5.sh`.\n\n'
    printf '## Required base\n\n%s\n\n' "$base_label"
    printf '## Payload\n\n'
    printf '| Target | Required base SHA-256 | New SHA-256 |\n'
    printf '| --- | --- | --- |\n'
    for row in "${payload_rows[@]}"; do
        IFS='|' read -r target base_sha new_sha source <<< "$row"
        printf '| `%s` | `%s` | `%s` |\n' "$target" "$base_sha" "$new_sha"
    done
    if [[ ${#verify_rows[@]} -gt 0 ]]; then
        printf '\n## Verified but not replaced\n\n'
        for row in "${verify_rows[@]}"; do
            IFS='|' read -r target expected_sha <<< "$row"
            printf -- '- `%s`: `%s`\n' "$target" "$expected_sha"
        done
    fi
    if [[ ${#commits[@]} -gt 0 ]]; then
        printf '\n## Source commits\n\n'
        for commit in "${commits[@]}"; do
            printf -- '- `%s`\n' "$commit"
        done
    fi
    printf '\n## Package checksums\n\n'
    printf -- '- `%s`: `%s`\n' "$zip_name" "$zip_sha"
    printf -- '- `%s.idsig`: `%s`\n' "$zip_name" "$idsig_sha"
    printf '\n## Scope and validation\n\n'
    printf '%s\n' '- Reuses/remounts the active system mount and never unmounts it.'
    printf '%s\n' '- Does not modify boot, vendor, Magisk, or files outside `/system/lib{,64}`.'
    printf '%s\n' '- Validates base hashes, payload hashes, shell syntax, ZIP integrity, payload count, APK Signature Block, and v4 idsig.'
    if [[ ${#test_notes[@]} -gt 0 ]]; then
        printf '\n## Device validation notes\n\n'
        for note in "${test_notes[@]}"; do
            printf -- '- %s\n' "$note"
        done
    fi
} > "$readme"

echo "Created: $final_zip"
echo "SHA-256: $zip_sha"
echo "V4 idsig: $idsig"
echo "Payload files: ${#payload_rows[@]}"
