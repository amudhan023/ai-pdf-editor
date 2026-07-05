#!/bin/bash
# Fixture benchmark/accuracy harness (P0-08). Emits one JSON object per
# invocation to stdout; a non-zero exit means the suite found a real failure.
#
# Suites actually implemented today, and why the others aren't:
#   corpus-open           Fixtures/pdf-corpus/manifest.json rows + malformed
#                          rows: file presence + sha256 integrity, per row.
#                          Does NOT open documents through a real PDF engine
#                          (DocEngineHost/PDFium isn't buildable yet on this
#                          machine - tasks/escalations/
#                          E-004-pdfium-build-infeasible-on-this-machine.md,
#                          P0-06 blocked) - that half is honestly reported as
#                          skipped, not faked green.
#   manifest-validate      Schema-shape check of all three Fixtures/*/manifest.json.
#   field-mapping          Structural check of Fixtures/forms/manifest.json's
#                          field_name/label/vault_path rows.
#   generator-determinism  Runs Fixtures/documents/generate.swift twice with
#                          the same seed and requires byte-identical output.
#   render-latency         Perf suite from the task's original scope. Reported
#                          as skipped: no renderer exists yet (same P0-06 gap).
#   xpc-latency            Real round-trip latency via Packages/Platform's
#                          XPCLatencyBench executable (P0-05/ADR-002 baseline)
#                          - same-process anonymous-listener calls, so it
#                          excludes real cross-process Mach IPC overhead.
#
# Usage:
#   Scripts/bench.sh <suite>       run one suite, print its JSON result
#   Scripts/bench.sh --all         run every suite, print an array of results
#   Scripts/bench.sh --self-test   prove each checker fails on a planted defect
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/Fixtures"

sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# ---------------------------------------------------------------------------
# corpus-open
# ---------------------------------------------------------------------------
corpus_open() {
    local manifest="$FIXTURES/pdf-corpus/manifest.json"
    local base="$FIXTURES/pdf-corpus"
    [ -f "$manifest" ] || { echo '{"suite":"corpus-open","status":"fail","error":"manifest missing"}'; return 1; }

    local rows results total=0 passed=0 failed=0
    results="[]"
    while IFS= read -r row; do
        total=$((total + 1))
        local id file expect actual ok note
        id="$(echo "$row" | jq -r '.id')"
        file="$(echo "$row" | jq -r '.file')"
        expect="$(echo "$row" | jq -r '.file_sha256')"
        if [ ! -f "$base/$file" ]; then
            ok=false; note="file not found: $file"
        else
            actual="$(sha256_of "$base/$file")"
            if [ "$actual" = "$expect" ]; then ok=true; note="sha256 match"; else ok=false; note="sha256 MISMATCH (expected $expect, got $actual)"; fi
        fi
        [ "$ok" = true ] && passed=$((passed + 1)) || failed=$((failed + 1))
        results="$(echo "$results" | jq --arg id "$id" --arg file "$file" --argjson ok "$ok" --arg note "$note" \
            '. + [{"id":$id,"file":$file,"sha256_ok":$ok,"engine_open":"skipped_pdfium_unavailable","note":$note}]')"
    done < <(jq -c '.rows[]' "$manifest")

    while IFS= read -r row; do
        total=$((total + 1))
        local id file expect actual ok note
        id="$(echo "$row" | jq -r '.id')"
        file="$(echo "$row" | jq -r '.file')"
        expect="$(echo "$row" | jq -r '.file_sha256')"
        if [ ! -f "$base/$file" ]; then
            ok=false; note="file not found: $file"
        else
            actual="$(sha256_of "$base/$file")"
            if [ "$actual" = "$expect" ]; then ok=true; note="sha256 match (malformed fixture intact)"; else ok=false; note="sha256 MISMATCH (expected $expect, got $actual)"; fi
        fi
        [ "$ok" = true ] && passed=$((passed + 1)) || failed=$((failed + 1))
        results="$(echo "$results" | jq --arg id "$id" --arg file "$file" --argjson ok "$ok" --arg note "$note" \
            '. + [{"id":$id,"file":$file,"sha256_ok":$ok,"kind":"malformed","note":$note}]')"
    done < <(jq -c '.malformed_rows[]?' "$manifest")

    local status; [ "$failed" -eq 0 ] && status="pass" || status="fail"
    jq -n --arg suite "corpus-open" --arg status "$status" --argjson total "$total" --argjson passed "$passed" --argjson failed "$failed" --argjson results "$results" \
        '{suite:$suite,status:$status,total:$total,passed:$passed,failed:$failed,
          skipped_checks:["engine_open (needs DocEngineHost/PDFium, P0-06 not built yet)","page_count live-reparse","text_sha256 live-reparse","render_checksum"],
          results:$results}'
    [ "$failed" -eq 0 ]
}

# ---------------------------------------------------------------------------
# manifest-validate
# ---------------------------------------------------------------------------
validate_one_manifest() {
    local path="$1" kind="$2" fail=0 errors="[]"
    if [ ! -f "$path" ]; then
        echo '{"file":"'"$path"'","ok":false,"errors":["file not found"]}'
        return 1
    fi
    if ! jq -e . "$path" >/dev/null 2>&1; then
        echo '{"file":"'"$path"'","ok":false,"errors":["not valid JSON"]}'
        return 1
    fi
    case "$kind" in
        pdf-corpus)
            jq -e '.schema_version and (.rows | type == "array")' "$path" >/dev/null 2>&1 || { fail=1; errors="$(echo "$errors" | jq '. + ["missing schema_version or rows array"]')"; }
            while IFS= read -r missing; do
                [ -z "$missing" ] && continue
                fail=1; errors="$(echo "$errors" | jq --arg m "$missing" '. + [$m]')"
            done < <(jq -r '.rows[] | select(.id == null or .file == null or .file_sha256 == null) | "row missing id/file/file_sha256: " + (.id // "?")' "$path")
            ;;
        forms)
            jq -e '.schema_version and (.forms | type == "array")' "$path" >/dev/null 2>&1 || { fail=1; errors="$(echo "$errors" | jq '. + ["missing schema_version or forms array"]')"; }
            while IFS= read -r missing; do
                [ -z "$missing" ] && continue
                fail=1; errors="$(echo "$errors" | jq --arg m "$missing" '. + [$m]')"
            done < <(jq -r '.forms[] | select(.id == null or .file == null or (.fields | type != "array")) | "form missing id/file/fields: " + (.id // "?")' "$path")
            while IFS= read -r missing; do
                [ -z "$missing" ] && continue
                fail=1; errors="$(echo "$errors" | jq --arg m "$missing" '. + [$m]')"
            done < <(jq -r '.forms[].fields[] | select(.field_name == null or .label == null or (has("vault_path") | not)) | "field row missing field_name/label/vault_path key: " + (.field_name // "?")' "$path")
            ;;
        documents)
            jq -e '.schema_version and .generator_version and (.seed != null) and (.kinds | type == "array")' "$path" >/dev/null 2>&1 \
                || { fail=1; errors="$(echo "$errors" | jq '. + ["missing schema_version/generator_version/seed/kinds"]')"; }
            ;;
    esac
    jq -n --arg file "$path" --argjson ok "$([ "$fail" -eq 0 ] && echo true || echo false)" --argjson errors "$errors" \
        '{file:$file,ok:$ok,errors:$errors}'
    return $fail
}

manifest_validate() {
    local rc=0 r1 r2 r3
    r1="$(validate_one_manifest "$FIXTURES/pdf-corpus/manifest.json" pdf-corpus)" || rc=1
    r2="$(validate_one_manifest "$FIXTURES/forms/manifest.json" forms)" || rc=1
    r3="$(validate_one_manifest "$FIXTURES/documents/manifest.json" documents)" || rc=1
    local status; [ "$rc" -eq 0 ] && status="pass" || status="fail"
    jq -n --arg suite "manifest-validate" --arg status "$status" --argjson r1 "$r1" --argjson r2 "$r2" --argjson r3 "$r3" \
        '{suite:$suite,status:$status,results:[$r1,$r2,$r3]}'
    return $rc
}

# ---------------------------------------------------------------------------
# field-mapping (structural check of Fixtures/forms/manifest.json rows)
# ---------------------------------------------------------------------------
field_mapping() {
    local manifest="$FIXTURES/forms/manifest.json"
    local bad
    # A non-null vault_path must be lowercase, dot/bracket/underscore only.
    bad="$(jq -r '[.forms[].fields[] | select(.vault_path != null) | select(.vault_path | test("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*(\\[[0-9]+\\])?)*$") | not) | .vault_path] | length' "$manifest")"
    local total mapped unmapped
    total="$(jq '[.forms[].fields[]] | length' "$manifest")"
    mapped="$(jq '[.forms[].fields[] | select(.vault_path != null)] | length' "$manifest")"
    unmapped="$((total - mapped))"
    local status; [ "$bad" -eq 0 ] && status="pass" || status="fail"
    jq -n --arg suite "field-mapping" --arg status "$status" --argjson total "$total" --argjson mapped "$mapped" --argjson unmapped "$unmapped" --argjson malformed_paths "$bad" \
        '{suite:$suite,status:$status,total_fields:$total,mapped_to_vault_path:$mapped,unmapped_or_out_of_scope:$unmapped,malformed_vault_path_strings:$malformed_paths}'
    [ "$bad" -eq 0 ]
}

# ---------------------------------------------------------------------------
# generator-determinism
# ---------------------------------------------------------------------------
generator_determinism() {
    local seed="${1:-42}"
    local gen="$FIXTURES/documents/generate.swift"
    local tmp1 tmp2
    tmp1="$(mktemp -d)"; tmp2="$(mktemp -d)"
    trap 'rm -rf "$tmp1" "$tmp2"' RETURN

    local kind rc=0
    for kind in passport license resume; do
        mkdir -p "$tmp1/$kind" "$tmp2/$kind"
        swift "$gen" --kind "$kind" --count 5 --seed "$seed" --out "$tmp1/$kind" >/dev/null 2>&1 || rc=1
        swift "$gen" --kind "$kind" --count 5 --seed "$seed" --out "$tmp2/$kind" >/dev/null 2>&1 || rc=1
    done

    local diff_output identical
    if diff_output="$(diff -r "$tmp1" "$tmp2" 2>&1)"; then identical=true; else identical=false; fi
    [ "$identical" = true ] && [ "$rc" -eq 0 ] && rc=0 || rc=1

    local status; [ "$rc" -eq 0 ] && status="pass" || status="fail"
    jq -n --arg suite "generator-determinism" --arg status "$status" --argjson seed "$seed" --argjson identical "$identical" --arg diff "$diff_output" \
        '{suite:$suite,status:$status,seed:$seed,byte_identical_across_two_runs:$identical,diff:(if $diff == "" then null else $diff end)}'
    return $rc
}

# ---------------------------------------------------------------------------
# render-latency (perf) — explicit stub, not faked
# ---------------------------------------------------------------------------
render_latency() {
    jq -n '{suite:"render-latency",status:"skipped",
            reason:"No rendering engine exists in this repo yet (DocEngineHost/PDFium, P0-06 blocked by tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md). Nothing to time.",
            budget_ref:"CLAUDE.md SS11 NFR-P2 (cold open < 1s / 100-page PDF)"}'
    return 0
}

# ---------------------------------------------------------------------------
# xpc-latency (P0-05: ADR-002's measured round-trip latency baseline)
# ---------------------------------------------------------------------------
xpc_latency() {
    swift run --package-path "$ROOT/Packages/Platform" -q XPCLatencyBench 2>/dev/null \
        || jq -n '{suite:"xpc-latency",status:"fail",reason:"XPCLatencyBench did not run"}'
}

run_all() {
    local rc=0
    local out="["
    local first=true
    for fn in corpus_open manifest_validate field_mapping generator_determinism render_latency xpc_latency; do
        local r
        r="$($fn)" || rc=1
        [ "$first" = true ] || out+=","
        out+="$r"
        first=false
    done
    out+="]"
    echo "$out" | jq '.'
    return $rc
}

self_test() {
    local rc=0

    # manifest-validate must fail on a manifest missing required keys.
    local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
    echo '{"schema_version":1,"rows":[{"id":"x"}]}' > "$tmp/bad.json"
    if validate_one_manifest "$tmp/bad.json" pdf-corpus >/dev/null 2>&1; then
        echo "SELF-TEST FAILED: manifest-validate did not detect a row missing file/file_sha256." >&2
        rc=1
    else
        echo "bench.sh self-test: manifest-validate correctly rejected a malformed manifest."
    fi

    # corpus-open must fail when a fixture's bytes are tampered (sha256 mismatch).
    local tmpcorpus; tmpcorpus="$(mktemp -d)"
    mkdir -p "$tmpcorpus/starter"
    echo "not the real bytes" > "$tmpcorpus/starter/tampered.pdf"
    echo '{"schema_version":1,"rows":[{"id":"tampered","file":"starter/tampered.pdf","file_sha256":"0000000000000000000000000000000000000000000000000000000000000"}],"malformed_rows":[]}' > "$tmpcorpus/manifest.json"
    local saved_fixtures="$FIXTURES"
    FIXTURES="$tmpcorpus"
    if corpus_open >/dev/null 2>&1; then
        echo "SELF-TEST FAILED: corpus-open did not detect a sha256 mismatch." >&2
        rc=1
    else
        echo "bench.sh self-test: corpus-open correctly rejected a tampered fixture."
    fi
    FIXTURES="$saved_fixtures"
    rm -rf "$tmpcorpus"

    # generator-determinism must actually distinguish different seeds (proves
    # the diff check has teeth, not a rubber stamp).
    local a b
    a="$(mktemp -d)"; b="$(mktemp -d)"
    swift "$FIXTURES/documents/generate.swift" --kind passport --count 3 --seed 1 --out "$a" >/dev/null 2>&1
    swift "$FIXTURES/documents/generate.swift" --kind passport --count 3 --seed 2 --out "$b" >/dev/null 2>&1
    if diff -r "$a" "$b" >/dev/null 2>&1; then
        echo "SELF-TEST FAILED: two different seeds produced identical output (generator is not actually seed-sensitive)." >&2
        rc=1
    else
        echo "bench.sh self-test: generator output correctly differs across different seeds."
    fi
    rm -rf "$a" "$b"

    [ "$rc" -eq 0 ] && echo "bench.sh: all self-tests passed."
    return $rc
}

case "${1:-}" in
    corpus-open) corpus_open ;;
    manifest-validate) manifest_validate ;;
    field-mapping) field_mapping ;;
    generator-determinism) generator_determinism "${2:-42}" ;;
    render-latency) render_latency ;;
    xpc-latency) xpc_latency ;;
    --all) run_all ;;
    --self-test) self_test ;;
    "")
        echo "usage: bench.sh <corpus-open|manifest-validate|field-mapping|generator-determinism|render-latency|xpc-latency> | --all | --self-test" >&2
        exit 2
        ;;
    *)
        echo "bench.sh: unknown suite '$1'" >&2
        exit 2
        ;;
esac
