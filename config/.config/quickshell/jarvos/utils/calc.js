.pragma library

// qalc's contract, kept out of QML so it can be unit-tested.
//
// qalc exits 0 for everything — "2+", "(((", "1/0" and plain prose all succeed
// — and never writes to stderr. Diagnostics arrive as "error: "/"warning: "
// lines on stdout instead, which is what makes parsing the output the only way
// to tell a real answer from a partial expression.

// Returns null for a blank expression, which is the guard against the worst
// failure available here: qalc with no expression drops into its interactive
// REPL and blocks on stdin forever, inside the shell process. The refusal lives
// in the argv builder rather than beside the call so it cannot be bypassed —
// there is no way to spawn qalc without going through here.
//
// precision 8 is what the plugin this replaces printed; the CLI defaults to 10
// and would silently lengthen every approximate result. "--" keeps a leading
// dash ("-5+3") from being read as a flag, and the expression is its own argv
// element because it comes straight from user typing.
function command(expr) {
    if (!expr || expr.toString().trim().length === 0)
        return null;
    return ["qalc", "-s", "precision 8", "--", expr];
}

// The plugin returned the diagnostic alone and dropped the result; qalc prints
// both. The plugin's shape is the one reproduced here, because CalcItem decides
// the text colour by looking for those prefixes.
function parse(out, printExpr) {
    if (!out)
        return "";

    const lines = out.toString().split("\n").map(l => l.trim()).filter(l => l.length > 0);
    if (lines.length === 0)
        return "";

    const messages = lines.filter(l => l.startsWith("error: ") || l.startsWith("warning: "));
    if (messages.length > 0)
        return messages.join("\n");

    const line = lines[lines.length - 1];
    return printExpr ? line : result(line);
}

// qalc echoes "<expression> = <result>", or "≈" where the result is
// approximate. The expression can itself contain an equals sign — "1+1 = 2"
// comes back as "((1 + 1) = 2) = true" — so the split is on the last separator.
function result(line) {
    const at = Math.max(line.lastIndexOf(" = "), line.lastIndexOf(" ≈ "));
    return at < 0 ? line : line.slice(at + 3);
}
