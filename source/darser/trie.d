module darser.trie;

import darser.rules;
import std.array : front;

import std.stdio;

class Trie {
	import std.array : appender, Appender;
	Trie[] follow;
	RulePart value;
	SubRule subRule;
	string[] subRuleNames;
	string subRuleName;
	string ruleName;

	this() {
	}

	this(RulePart value) {
		this.value = value;
	}

	override string toString() {
		auto app = appender!string();
		foreach(f; follow) {
			f.toString(app, 0);
		}

		return app.data;
	}

	void toString(Appender!string app, int indent) {
		import std.format : formattedWrite;
		import std.array : empty;
		for(int i = 0; i < indent; ++i) {
			formattedWrite(app, " ");
		}
		formattedWrite(app, "%s", this.value.name);
		if(this.follow.empty) {
			formattedWrite(app, " %s\n", this.subRuleName);
		} else {
			formattedWrite(app, "\n");
		}
		foreach(f; this.follow) {
			f.toString(app, indent + 1);
		}
	}
}

void printTrie(Trie t, int indent) {
	import std.stdio;
	for(int i = 0; i < indent; ++i) {
		write(" ");
	}
	if(t.value !is null) {
		writefln("%s %s", t.value.name, t.ruleName);
	} else {
		writeln(t.ruleName);
	}

	foreach(it; t.follow) {
		printTrie(it, indent + 1);
	}
}

Trie[] ruleToTrie(Rule rule) {
	import std.array : back;
	import std.uni : isUpper;
	auto ret = new Trie;

	foreach(subRule; rule.subRules) {
		ruleToTrieRecur(ret, subRule, subRule.elements, rule.name);
	}

	return ret.follow;
}

void ruleToTrieRecur(Trie cur, SubRule sr, RulePart[] rp, string ruleName) {
	import std.algorithm : sort, uniq;
	import std.array : array;
	Trie con;

	// find the con(tinuing) Trie node
	foreach(elem; cur.follow) {
		if(elem.value.name == rp.front.name) {
			con = elem;
		}
	}

	if(con is null) {
		con = new Trie(rp.front);
		con.subRuleName = sr.name;
		cur.follow ~= con;
	}

	con.subRuleNames ~= sr.name;
	con.subRuleNames = con.subRuleNames.sort.uniq.array;

	if(rp.length > 1) {
		ruleToTrieRecur(con, sr, rp[1 .. $], ruleName);
	} else {
		//writefln("maybe something exists already rule '%s' subrule '%s'"
		//		~ " overrite with '%s' '%s'",
		//		con.ruleName, con.subRuleName, sr.name, sr
		//	);
		con.ruleName = ruleName;
		con.subRuleName = sr.name;
		con.subRule = sr;
	}
}
