module rules;

import std.uni;
import std.format : format;
import std.array : back, front;
import std.string : indexOf;
import std.typecons : Flag;
import std.exception : enforce;

import helper;

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
		return this.name.front.isLower();
	}

	bool nonterminal() pure const @safe {
		return this.name.front.isUpper();
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
	bool isExtern;

	this(string name) {
		this.name = name;
	}

	this(string name, bool e) {
		this.name = name;
		this.isExtern = e;
	}

	override string toString() pure const @safe {
		string rslt = this.name ~ " : \n";
		foreach(it; this.subRules) {
			rslt ~= "\t" ~ it.toString() ~ "\n";
		}

		return rslt;
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
