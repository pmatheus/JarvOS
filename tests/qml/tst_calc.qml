import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/calc.js" as Calc

TestCase {
    name: "Calc"

    function test_the_expression_is_its_own_argv_element() {
        // It comes straight from user typing, so it must never be spliced into
        // a shell string.
        const cmd = Calc.command("2+2; rm -rf /");
        compare(cmd[cmd.length - 1], "2+2; rm -rf /");
    }

    function test_a_leading_dash_expression_is_not_read_as_a_flag() {
        const cmd = Calc.command("-5+3");
        compare(cmd[cmd.length - 2], "--");
    }

    function test_there_is_no_command_for_a_blank_expression() {
        // qalc with no expression drops into its interactive REPL and blocks on
        // stdin forever, inside the shell process. Refusing to build the argv at
        // all is what makes that unreachable: there is no way to spawn qalc
        // without going through command().
        compare(Calc.command(""), null);
        compare(Calc.command("   "), null);
        compare(Calc.command("\n\t "), null);
        compare(Calc.command(undefined), null);
    }

    function test_a_real_expression_still_gets_a_command() {
        verify(Calc.command("2+2") !== null);
    }

    function test_parse_keeps_the_echo_when_printing_the_expression() {
        compare(Calc.parse("2 + 2 = 4\n", true), "2 + 2 = 4");
    }

    function test_parse_drops_the_echo_when_not_printing_the_expression() {
        compare(Calc.parse("2 + 2 = 4\n", false), "4");
    }

    function test_parse_splits_on_the_last_separator_not_the_first() {
        // qalc echoes the expression, and the expression can itself contain an
        // equals sign: "1+1 = 2" comes back as "((1 + 1) = 2) = true".
        compare(Calc.parse("((1 + 1) = 2) = true\n", false), "true");
    }

    function test_parse_handles_an_approximate_result() {
        compare(Calc.parse("5 kilograms ≈ 11 lb + 0.36980975 oz\n", false), "11 lb + 0.36980975 oz");
    }

    function test_a_warning_replaces_the_result_entirely() {
        // qalc prints the warning and then the result anyway; the plugin this
        // replaces returned the message alone. CalcItem colours the text red by
        // looking for the prefix, so the message must survive verbatim and the
        // result must not be appended to it.
        const out = 'warning: Misplaced operator(s) "+" ignored\n2 = 2\n';
        compare(Calc.parse(out, true), 'warning: Misplaced operator(s) "+" ignored');
        compare(Calc.parse(out, false), 'warning: Misplaced operator(s) "+" ignored');
    }

    function test_an_error_replaces_the_result_entirely() {
        compare(Calc.parse("error: Boo.\n1 / 0 = 1 / 0\n", false), "error: Boo.");
    }

    function test_parse_of_empty_output_is_empty() {
        compare(Calc.parse("", true), "");
        compare(Calc.parse("\n\n", false), "");
    }

    function test_a_result_with_no_separator_survives() {
        compare(Calc.parse("4\n", false), "4");
    }
}
