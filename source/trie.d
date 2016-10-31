module trie;

import rules;

class Trie {
	import std.array : appender, Appender;
	Trie[] follow;
	RulePart value;
	string subRuleName;

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

Trie ruleToTrie(Rule rule) {
	import std.array : back;
	auto ret = new Trie;

	foreach(subRule; rule.subRules) {
		Trie cur = ret;
		middle: foreach(rp; subRule.elements) {
			Trie follow = null;
			foreach(elem; cur.follow) {
				if(elem.value.name == rp.name) {
					cur = elem;
					continue middle;
				}
			}
			if(follow is null) {
				cur.follow ~= new Trie(rp);
				cur = cur.follow.back;
			}
		}
		cur.subRuleName = subRule.name;
	}

	return ret;
}
