module trie;

import rules;

import std.stdio;

class Trie {
	import std.array : appender, Appender;
	Trie[] follow;
	RulePart value;
	SubRule subRule;
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
		writefln("sr %s ret.length %s", subRule, ret.follow.length);
		Trie cur = ret;
		middle: foreach(idx, rp; subRule.elements) {
			writefln("rp.name %s", rp.name);
			foreach(elem; cur.follow) {
				if(isUpper(rp.name[0]) && elem.value.name == rp.name) {
					writefln("\tfoo %s", rp.name);
					cur = elem;
					continue middle;
				} else if(elem.value.name == rp.name 
						&& elem.value.storeName == rp.storeName)
				{
					writefln("\tbar %s", rp.name);
					cur = elem;
					continue middle;
				}
			}

			writefln("bar.name %s", rp.name);
			auto ne = new Trie(rp);
			ne.subRule = subRule;
			if(idx + 1 == subRule.elements.length) {
				ne.ruleName = rule.name;
			}

			cur.follow ~= ne;
			cur = ne;
		}
		cur.subRuleName = subRule.name;
	}

	printTrie(ret, 0);
	//writefln("ret: %s", ret.toString());
	//foreach(it; ret.follow) {
	//	writefln("\t%s", it.value.name);
	//}
	return ret.follow;
}
