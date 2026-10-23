pragma Singleton

import QtQuick
import Quickshell

// Arithmetic for the launcher: "2*37", "(3+4)^2/7", or anything after "=".
// A small parser of its own rather than JavaScript's eval, so a query is
// only ever numbers and + - * / % ^ and parentheses.
Singleton {
    id: root

    // The result as text, or null when `query` isn't a sum. Without a
    // leading "=" it has to contain an operator, so a lone number (or an app
    // name) isn't taken for one.
    function result(query) {
        let q = query.trim();
        const forced = q.startsWith("=");
        if (forced)
            q = q.slice(1);
        if (q === "" || !/^[\d\s.+\-*/%^()x×÷]+$/.test(q) || !/\d/.test(q))
            return null;
        if (!forced && !/\d\s*[+\-*/%^x×÷]\s*[-+]?\s*[\d(.]/.test(q))
            return null;
        const v = evaluate(q.replace(/[x×]/g, "*").replace(/÷/g, "/").replace(/\s+/g, ""));
        if (v === null || !isFinite(v))
            return null;
        return String(Number(v.toPrecision(12)));
    }

    // Recursive descent: sum of terms, terms of factors, ^ binding tightest
    // and to the right, unary minus on any factor.
    function evaluate(s) {
        let i = 0;
        function number() {
            const m = /^(\d+\.?\d*|\.\d+)/.exec(s.slice(i));
            if (!m)
                throw "number";
            i += m[0].length;
            return parseFloat(m[0]);
        }
        function primary() {
            if (s[i] === "(") {
                i++;
                const v = sum();
                if (s[i] !== ")")
                    throw "paren";
                i++;
                return v;
            }
            return number();
        }
        function unary() {
            if (s[i] === "-") {
                i++;
                return -unary();
            }
            if (s[i] === "+") {
                i++;
                return unary();
            }
            return power();
        }
        function power() {
            const base = primary();
            if (s[i] === "^") {
                i++;
                return Math.pow(base, unary());
            }
            return base;
        }
        function term() {
            let v = unary();
            while (s[i] === "*" || s[i] === "/" || s[i] === "%") {
                const op = s[i++];
                const r = unary();
                v = op === "*" ? v * r : op === "/" ? v / r : v % r;
            }
            return v;
        }
        function sum() {
            let v = term();
            while (s[i] === "+" || s[i] === "-") {
                const op = s[i++];
                const r = term();
                v = op === "+" ? v + r : v - r;
            }
            return v;
        }
        try {
            const v = sum();
            return i === s.length ? v : null;
        } catch (e) {
            return null;
        }
    }
}
