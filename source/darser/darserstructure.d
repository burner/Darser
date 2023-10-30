module darser.darserstructure;

import std.algorithm.comparison : cmp;
import std.algorithm.sorting : sort;
import std.algorithm.iteration : joiner, map;
import std.algorithm.searching : canFind, find;
import std.algorithm.setops : setIntersection, setDifference;
import std.array : appender, array, back, empty, front, popBack;
import std.conv : to;
import std.stdio : File;
import std.file : readText;
import std.exception : enforce;
import std.format;

import dyaml;

import darser.helper;
import darser.trie;
import darser.rules;
import darser.clioptions;

struct FirstRulePath {
	string[] path;

	string getLast() const {
		enforce(!this.path.empty);
		return this.path.back;
	}

	string getFirst() const {
		enforce(!this.path.empty);
		return this.path.front;
	}

	void add(string s) {
		this.path ~= s;
	}

	bool finished() const {
		enforce(!this.path.empty);
		return isLowerStr(this.path.back);
	}

	int opCmp(ref FirstRulePath other) {
		return cmp(this.path.back, other.path.back);
	}

	string toString() {
		auto app = appender!string();
		formattedWrite(app, "%s", this.path.joiner(" -> "));
		return app.data;
	}

	string toFollowError() {
		if(this.getFirst() != this.getLast()) {
			return format("\"%s -> %s\"", this.getLast(), this.getFirst());
		} else {
			return format("\"%s\"", this.getFirst());
		}
	}
}

class Darser {
	Rule[] rules;
	bool[string][string] firstSets;
	FirstRulePath[][string] expandedFirstSet;
	Rule[string] externRules;

	string filename;

	this(string filename) {
		this.filename = filename;
		this.gen();
		this.genFirstSet();
		this.buildTerminalFirstSets();
	}

	void gen() {
		auto root = Loader.fromFile(this.filename);
		foreach(ref Node it; root) {
			// Node.Pair has a .key and a .value
			auto jt = it.as!(Node.Pair[])();
			foreach(ref kt; jt) {
				if(kt.value.nodeID == NodeID.scalar
						&& kt.value.as!string() == "extern")
				{
					this.externRules[kt.key.as!string()] =
							new Rule(kt.key.as!string(), true);
					continue;
				}
				Rule nr = new Rule(kt.key.as!string());
				auto subRule = kt.value.as!(Node.Pair[])();
				foreach(ref lt; subRule) {
					auto subRuleKey = lt.key.as!string();
					nr.subRules ~= new SubRule(subRuleKey);
					foreach(ref Node subValue; lt.value) {
						nr.subRules.back.elements ~=
							new RulePart(subValue.as!string());
					}
				}
				this.rules ~= nr;
			}
		}

		//foreach(it; this.rules) {
		//	writeln(it.toString());
		//}
	}

	Rule getRuleByName(string rn) {
		foreach(rule; this.rules) {
			if(rule.name == rn) {
				return rule;
			}
		}

		throw new Exception(
			"Rule with name \"" ~ rn ~ "\" could not be found"
		);
	}

	void buildTerminalFirstSets() {
		foreach(rule; this.rules) {
			auto t = this.buildTerminalFirstSet(rule);
			t.sort();
			this.expandedFirstSet[rule.name] = t;
		}

		foreach(erule; this.externRules) {
			this.expandedFirstSet[erule.name] = new FirstRulePath[0];
		}
	}

	Rule getRule(string name) {
		foreach(rule; this.rules) {
			if(rule.name == name) {
				return rule;
			}
		}
		if(name in this.externRules) {
			return this.externRules[name];
		}
		assert(false, "Rule with name " ~ name ~ " not found");
	}

	static void addSubRuleFirst(Rule rule, ref FirstRulePath[] toProcess,
			string[] old = null)
	{
		foreach(subRule; rule.subRules) {
			enforce(!subRule.elements.empty);
			FirstRulePath tmp;
			tmp.path ~= old;
			tmp.add(subRule.elements[0].name);
			if(!canFind(toProcess, tmp)) {
				toProcess ~= tmp;
			}
		}
	}

	FirstRulePath[] buildTerminalFirstSet(Rule rule) {
		FirstRulePath[] toProcess = new FirstRulePath[0];
		addSubRuleFirst(rule, toProcess);

		//FirstRulePath[] ret = new FirstRulePath[0];
		FirstRulePath[string] ret;
		while(!toProcess.empty) {
			FirstRulePath t = toProcess.back;
			//writefln("%s toProcess %s",
			//		toProcess.map!(a => a.getLast()), t
			//	);
			toProcess.popBack();

			if(isLowerStr(t.getLast())) {
				if(t.getLast() !in ret) {
					ret[t.getLast()] = t;
				//if(!canFind(ret, t)) {
					//ret ~= t;
				}
				continue;
			}

			Rule r = this.getRule(t.getLast());
			addSubRuleFirst(r, toProcess, t.path);
		}
		return ret.values;
	}

	void genFirstSet() {
		foreach(rule; this.rules) {
			foreach(subRule; rule.subRules) {
				if(isLowerStr(subRule.elements[0].name)) {
					this.firstSets[rule.name][subRule.elements[0].name] = true;
				}
			}
		}
		//writeln(this.firstSets);
		//this.fillFirstSets();
		//writeln(this.firstSets);
	}

}

