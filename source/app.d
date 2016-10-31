import std.stdio;
import dyaml.all;

import std.array : back, front;

import rules;
import trie;

class Darser {
	import std.format;
	import std.array : empty;
	import std.uni : isLower;
	Rule[] rules;

	string[][string] firstSets;

	string filename;
	this(string filename) {
		this.filename = filename;
		this.gen();
		this.genFirstSet();
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
		void generateEnum(File.LockingTextWriter ltw, Rule rule) {
			formattedWrite(ltw, "enum %sEnum {\n", rule.name);
			foreach(subRule; rule.subRules) {
				formattedWrite(ltw, "\t%s,\n", subRule.name);
			
			}
			formattedWrite(ltw, "}\n\n");
		}
		void generateMembers(File.LockingTextWriter ltw, Rule rule) {
			RulePart[string] uni = this.unique(rule);
			foreach(key, value; uni) {
				if(!value.name.empty && isLower(value.name[0])) {
					formattedWrite(ltw, "\tToken %s;\n", key);
				} else {
					formattedWrite(ltw, "\t%s %s;\n", value.name, key);
				}
			}
			formattedWrite(ltw, "\n");
		}

		void genereateCTors(File.LockingTextWriter ltw, Rule rule) {
			foreach(it; rule.subRules) {
				formattedWrite(ltw, "\tthis(%sEnum ruleSelection", rule.name);
				foreach(jt; it.elements) {
					if(jt.storeThis == StoreRulePart.yes) {
						formattedWrite(ltw, ", %s %s", 
								jt.name, jt.storeName
						);
					}
				}
				formattedWrite(ltw, ") {\n");
				formattedWrite(ltw, "\t\tthis.ruleSelection = ruleSelection;\n");
				foreach(jt; it.elements) {
					if(jt.storeThis == StoreRulePart.yes) {
						formattedWrite(ltw, "\t\tthis.%s = %s;\n", 
								jt.storeName, jt.storeName
						);
					}
				}
				formattedWrite(ltw, "\t}\n\n");
			}
		}

		void generateVisitor(File.LockingTextWriter ltw, Rule rule) {
			formattedWrite(ltw, 
`	final void visit(Visitor vis) {
		vis.accept(this);
	}

	final void visit(Visitor vis) const {
		vis.accept(this);
	}
`
			);

		}
		foreach(rule; this.rules) {
			generateEnum(ltw, rule);
			formattedWrite(ltw, "class %s {\n", rule.name);	
			formattedWrite(ltw, "\t%sEnum ruleSelection;\n", rule.name);	
			generateMembers(ltw, rule);
			genereateCTors(ltw, rule);
			generateVisitor(ltw, rule);
			formattedWrite(ltw, "}\n\n");	
		}
	}

	void genParser(File.LockingTextWriter ltw) {
		formattedWrite(ltw, 
`module parser;

import lexer;

class Parser {
	Lexer lex;

	this(Lexer lex) {
		this.lex = lex;
	}
`);

		this.genRules(ltw);
		formattedWrite(ltw, "}\n\n");
	}

	void genRules(File.LockingTextWriter ltw) {
		foreach(rule;  this.rules) {
			this.genRule(ltw, rule);
		}
	}

	void genIndent(File.LockingTextWriter ltw, int indent) {
		while(indent > 0) {
			formattedWrite(ltw, "\t");
			--indent;
		}
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

	void genFirstSet() {
		foreach(rule; this.rules) {
			this.firstSets[rule.name] = [];
			foreach(subRule; rule.subRules) {
				if(isLower(subRule.elements[0].name[0])) {
					this.firstSets[rule.name] ~= subRule.elements[0].name;
				}
			}
		}
	}

	void genRule(File.LockingTextWriter ltw, Rule rule) {
		auto t = ruleToTrie(rule);
		this.genIndent(ltw, 1);
		formattedWrite(ltw, "%1$s parse%1$s() {\n", rule.name);
		this.genIndent(ltw, 1);
		formattedWrite(ltw, "}\n");
	}
}

void main(string[] args) {
	auto darser = new Darser("e.yaml");

	//auto f = File("classes.d", "w");
	//darser.generateClasses(stdout.lockingTextWriter());

	/*foreach(r; darser.rules) {
		darser.genRule(stdout.lockingTextWriter(), r);
	}*/

	writeln(darser.firstSets);
}

