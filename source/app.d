import std.stdio;
import dyaml.all;

import std.array : back, front;

import rules;
import trie;

void formatIndent(O,Args...)(ref O o, long indent, string str, 
		auto ref Args args)
{
	import std.format : formattedWrite;
	while(indent > 0) {
		formattedWrite(o, "\t");
		--indent;
	}
	formattedWrite(o, str, args);
}

class Darser {
	import std.format;
	import std.array : empty;
	import std.uni : isLower, isUpper;
	Rule[] rules;

	bool[string][string] firstSets;

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

	void fillFirstSets() {
		repeat: do {
			foreach(rule; this.rules) {
				foreach(subRule; rule.subRules) {
					if(isUpper(subRule.elements[0].name[0])) {
						long oldSize = rule.name in this.firstSets ? 
							this.firstSets[rule.name].length : 0;
						if(subRule.elements[0].name in this.firstSets) {
							foreach(key;
									this.firstSets[subRule.elements[0].name].byKey())
							{
								this.firstSets[rule.name][key] = true;
							}
						}
						long newSize = rule.name in this.firstSets ? 
							this.firstSets[rule.name].length : 0;
						if(newSize > oldSize) {
							goto repeat;
						}
					}
				}
			}
		} while(false);
	}

	void genFirstSet() {
		foreach(rule; this.rules) {
			foreach(subRule; rule.subRules) {
				if(isLower(subRule.elements[0].name[0])) {
					this.firstSets[rule.name][subRule.elements[0].name] = true;
				}
			}
		}
		//writeln(this.firstSets);
		//this.fillFirstSets();
		//writeln(this.firstSets);
	}

	void genRule(File.LockingTextWriter ltw, Rule rule) {
		void genFirst(File.LockingTextWriter ltw, Rule rule) {
			bool[string] found;
			formatIndent(ltw, 1, "bool first%s() const {\n", rule.name);
			formatIndent(ltw, 2, "return ");

			bool first = true;
			foreach(subRule; rule.subRules) {
				if(subRule.elements[0].name in found) {
					continue;
				}
				if(!first) {
					formattedWrite(ltw, "\n");
					formatIndent(ltw, 3, " || ");
				}
				if(isLower(subRule.elements[0].name[0])) {
					formattedWrite(ltw, "this.lex.first.type == TokenType.%s",
						subRule.elements[0].name
					);
				} else {
					formattedWrite(ltw, "this.first%s()",
						subRule.elements[0].name
					);

				}
				found[subRule.elements[0].name] = true;
				first = false;
			}
			formattedWrite(ltw, ";\n\t}\n\n");
		}

		genFirst(ltw, rule);

		void genTrieCtor(File.LockingTextWriter ltw, Trie t, int indent)
				const 
		{
			formatIndent(ltw, indent + 1, "return new %s(%1$sEnum.%s", 
				t.subRuleName , t.ruleName
			);
			foreach(kt; t.subRule.elements) {
				if(kt.storeThis) {
					formattedWrite(ltw, ", %s", kt.storeName);
				}
			}
			formattedWrite(ltw, ");");
		}

		void genParse(File.LockingTextWriter ltw, const(size_t) idx,
				const(size_t) off, Trie t, int indent, Trie[] fail) 
		{
			if(idx > 0) {
				formattedWrite(ltw, " else ");
			} else {
				this.genIndent(ltw, indent);
			}
			if(isLower(t.value.name[0])) {
				if(t.value.storeThis) {
					formattedWrite(ltw, "Token %s = this.lex.front;\n",
						t.value.storeName
					);
					formatIndent(ltw, indent, "if(%1$s.type == TokenType.%s) {\n",
						t.value.storeName, t.value.name
					);
					formatIndent(ltw, indent + 1, "this.lex.popFront();\n");
				} else {
					formattedWrite(ltw, 
						"if(this.token.front.type == TokenType.%s) {\n",
						t.value.name
					);
					formatIndent(ltw, indent + 1, "this.lex.popFront();\n");
				}
				foreach(i, it; t.follow) {
					genParse(ltw, i, t.follow.length, it, indent + 1, t.follow);
				}
				if(t.follow.empty) {
					genTrieCtor(ltw, t, indent);
				}
				formattedWrite(ltw, "\n");
			} else {
				formattedWrite(ltw, "if(this.first%s()) {\n", t.value.name);
				this.genIndent(ltw, indent + 1);
				if(t.value.storeThis) {
					formattedWrite(ltw, "%1$s %2$s = this.parse%1$s();\n",
							t.value.name, t.value.storeName
					);
				} else {
					formattedWrite(ltw, "this.parse%s();\n", t.value.name);
				}
				foreach(i, it; t.follow) {
					genParse(ltw, i, t.follow.length, it, indent + 1, t.follow);
				}
				if(t.follow.empty) {
					genTrieCtor(ltw, t, indent);
				}
				formattedWrite(ltw, "\n");
			}
			formatIndent(ltw, indent, "}");
			if(idx + 1 == off) {
				formattedWrite(ltw, "\n");
				formatIndent(ltw, indent, "throw new Exception(\"Was expecting an");
				foreach(htx, ht; fail) {
					if(htx == 0) {
						formattedWrite(ltw, " %s", ht.value.name);
					} else if(htx + 1 == fail.length) {
						formattedWrite(ltw, ", or %s", ht.value.name);
					} else {
						formattedWrite(ltw, ", %s", ht.value.name);
					}
				}
				formattedWrite(ltw, ".\");");
				
			}
		}

		auto t = ruleToTrie(rule);
		foreach(it; t) {
			writeln(it.toString());
		}
		formatIndent(ltw, 1, "%1$s parse%1$s() {\n", rule.name);
		formatIndent(ltw, 2, "try {\n");
		formatIndent(ltw, 3, "return this.parse%sImpl();\n", rule.name);
		formatIndent(ltw, 2, "} catch(ParseException e) {\n");
		formatIndent(ltw, 3, 
				"throw new ParseException(\"While parsing a %s an Exception "
				~ "was thrown.\", e);\n", rule.name
		);
		formatIndent(ltw, 2, "}\n");
		formatIndent(ltw, 1, "}\n\n");

		formatIndent(ltw, 1, "%1$s parse%1$sImpl() {\n", rule.name);
		foreach(i, it; t) {
			genParse(ltw, i, t.length, it, 2, t);
		}
			
		formattedWrite(ltw, "\n");
		formatIndent(ltw, 1, "}\n\n");
	}
}

void main(string[] args) {
	auto darser = new Darser("e.yaml");

	//auto f = File("classes.d", "w");
	darser.generateClasses(stdout.lockingTextWriter());

	/*foreach(r; darser.rules) {
		darser.genRule(stdout.lockingTextWriter(), r);
	}*/

	darser.genRules(stdout.lockingTextWriter());
}

