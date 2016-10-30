import std.stdio;
import dyaml.all;

import std.format : format;
import std.array : back, front;

import rules;
import trie;

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
		void generateMembers(File.LockingTextWriter ltw, Rule rule) {
			RulePart[string] uni = this.unique(rule);
			foreach(key, value; uni) {
				formattedWrite(ltw, "\t%s %s;\n", value.name, key);
			}
			formattedWrite(ltw, "\n");
		}

		void genereateCTors(File.LockingTextWriter ltw, Rule rule) {
			foreach(it; rule.subRules) {
				bool first = true;
				formattedWrite(ltw, "\tthis(");
				foreach(jt; it.elements) {
					if(jt.storeThis == StoreRulePart.yes) {
						if(first) {
							formattedWrite(ltw, "%s %s", 
									jt.name, jt.storeName
							);
						} else {
							formattedWrite(ltw, ", %s %s", 
									jt.name, jt.storeName
							);
						}
						first = false;
					}
				}
				formattedWrite(ltw, ") {\n");
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
			formattedWrite(ltw, "class %s {\n", rule.name);	
			generateMembers(ltw, rule);
			genereateCTors(ltw, rule);
			generateVisitor(ltw, rule);
			formattedWrite(ltw, "}\n\n");	
		}
	}

	void genRules(File.LockingTextWriter ltw) {
		foreach(rule;  this.rules) {
			this.genRule(ltw, rule);
		}
	}

	void genRule(File.LockingTextWriter ltw, Rule rule) {

	}
}

void main(string[] args) {
	auto darser = new Darser("e.yaml");

	//auto f = File("classes.d", "w");
	darser.generateClasses(stdout.lockingTextWriter());

	foreach(rule; darser.rules) {
		auto t = ruleToTrie(rule);
		writeln(t.toString());
	}
}

