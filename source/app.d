import std.stdio;
import dyaml.all;

import std.typecons : Flag;
import std.format : format;
import std.uni;
import std.array : back, front;
import std.string : indexOf;

alias StoreRulePart = Flag!"StoreRulePart";

class RulePart {
	StoreRulePart storeThis;	
	string name;
	string storeName;

	this(string name) {
		this.name = name;

		auto hashIdx = this.name.indexOf('#');
		if(hashIdx != -1) {
			this.storeThis = StoreRulePart.yes;
			this.storeName = this.name[hashIdx + 1 .. $];
			this.name = this.name[0 .. hashIdx];
		}
	}

	bool terminal() pure const @safe {
		return this.name.front.isUpper();
	}

	bool nonterminal() pure const @safe {
		return this.name.front.isLower();
	}

	override string toString() pure const @safe {
		if(this.storeThis == StoreRulePart.yes) {
			return format("%s#%s", this.name, this.storeName);
		} else {
			return this.name;
		}
	}
}

class SubRule {
	RulePart[] elements;

	string name;

	this(string name) {
		this.name = name;
	}

	override string toString() pure const @safe {
		string rslt = this.name ~ " : ";
		foreach(it; this.elements) {
			rslt ~= it.toString() ~ " ";
		}

		return rslt;
	}
}

class Rule {
	SubRule[] subRules;
	string name;

	this(string name) {
		this.name = name;
	}

	override string toString() pure const @safe {
		string rslt = this.name ~ " : \n";
		foreach(it; this.subRules) {
			rslt ~= "\t" ~ it.toString() ~ "\n";
		}

		return rslt;
	}
}

class Darser {
	Rule[] rules;

	string filename;
	this(string filename) {
		this.filename = filename;
		this.gen();
	}

	void gen() {
		auto root = Loader(this.filename);
		foreach(ref Node it; root) {
			auto jt = it.as!(Node.Pair[])();
			foreach(ref kt; jt) {
				this.rules ~= new Rule(kt.key.as!string());	
				auto subRule = kt.value.as!(Node.Pair[])();
				foreach(ref lt; subRule) {
					auto subRuleKey = lt.key.as!string();
					this.rules.back.subRules ~= new SubRule(subRuleKey);
					foreach(ref Node subValue; lt.value) {
						this.rules.back.subRules.back.elements ~= 
							new RulePart(subValue.as!string());
					}
				}
			}
		}

		foreach(it; this.rules) {
			writeln(it.toString());
		}
	}

	RulePart[string] unique(Rule rule) {
		RulePart[string] ret;
		foreach(it; rule.subRules) {
			foreach(jt; it.elements) {
				if(jt.storeThis == StoreRulePart.yes) {
					ret[jt.storeName] = jt;
				}
			}
		}
		return ret;
	}

	void generateClasses(File.LockingTextWriter ltw) {
		import std.format;
		foreach(rule; this.rules) {
			RulePart[string] uni = this.unique(rule);
			formattedWrite(ltw, "class %s {\n", rule.name);	
			foreach(key, value; uni) {
				formattedWrite(ltw, "\t%s %s;\n", value.name, key);
			}
			formattedWrite(ltw, "}\n");	
		}
	}
}

void main(string[] args) {
	auto darser = new Darser("e.yaml");

	//auto f = File("classes.d", "w");
	darser.generateClasses(stdout.lockingTextWriter());
}
