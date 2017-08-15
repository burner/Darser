import std.stdio;
import dyaml;

import std.array : back, front, empty;

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

interface IDarser {

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

	void generateClasses(File.LockingTextWriter ltw, bool customParseFunctions) {
		formatIndent(ltw, 0, "module ast;\n\n");
		formatIndent(ltw, 0, "import std.typecons : RefCounted, refCounted;\n\n");
		if(customParseFunctions) {
			formatIndent(ltw, 0, "public import astcustom;\n\n");
		}
		formatIndent(ltw, 0, "import tokenmodule;\n\n");
		//formatIndent(ltw, 0, "import visitor;\n\n");

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
			string[][] before;
			outer: foreach(it; rule.subRules) {
				string[] tmp;
				foreach(jt; it.elements) {
					if(jt.storeThis == StoreRulePart.yes) {
						if(isLower(jt.name[0])) {
							tmp ~= "Token";
						} else {
							tmp ~= jt.name;
						}
					}
				}
				//writefln("the list %s", tmp);
				inner: foreach(string[] cmp; before) {
					/*writefln("tmp [%(%s %)], cmp [%(%s %)]",
						tmp, cmp
					);*/
					if(cmp.length != tmp.length) {
						//writeln("length inner");
						continue inner;
					}
					foreach(size_t idx, string kt; cmp) {
						if(kt != tmp[idx]) {
							//writeln("not equal length");
							continue inner;
						}
					}
					//writeln("outer");
					continue outer;
				}
				before ~= tmp;
				formattedWrite(ltw, "\tthis(%sEnum ruleSelection", rule.name);
				foreach(jt; it.elements) {
					if(jt.storeThis == StoreRulePart.yes) {
						if(isLower(jt.name[0])) {
							formattedWrite(ltw, ", Token %s", jt.storeName);
						} else {
							formattedWrite(ltw, ", %s %s", 
									jt.name, jt.storeName
							);
						}
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
`	void visit(Visitor vis) {
		vis.accept(this);
	}

	void visit(Visitor vis) const {
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
			//generateVisitor(ltw, rule);
			formattedWrite(ltw, "}\n\n");	
			//formattedWrite(ltw, "alias %1$s = RefCounted!(%1$s);\n\n", rule.name);	
		}
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

	void genVis(bool cns)(File.LockingTextWriter ltw, Rule rule) {
		formatIndent(ltw, 0, "\n");
		if(cns) {
			formatIndent(ltw, 1, "void accept(const(%s) obj) {\n",
				rule.name
			);
		} else {
			formatIndent(ltw, 1, "void accept(%s obj) {\n",
				rule.name
			);
		}

		formatIndent(ltw, 2, "final switch(obj.ruleSelection) {\n");
		foreach(subRule; rule.subRules) {
			formatIndent(ltw, 3, "case %sEnum.%s:\n",
				rule.name, subRule.name
			);
			foreach(elem; subRule.elements) {
				if(elem.storeThis == StoreRulePart.yes) {
					formatIndent(ltw, 4, "obj.%s.visit(this);\n",
						elem.storeName
					);
				}
			}
			formatIndent(ltw, 4, "break;\n");
		}
		formatIndent(ltw, 2, "}\n");
		formatIndent(ltw, 1, "}\n");
	}

	void genDefaultVisitor(File.LockingTextWriter ltw) {
		//formatIndent(ltw, 0, "module visitor;\n\n");
		formatIndent(ltw, 0, "import std.typecons : RefCounted, refCounted;\n\n");
		formatIndent(ltw, 0, "import std.experimental.allocator;\n\n");
		formatIndent(ltw, 0, "import ast;\n");
		formatIndent(ltw, 0, "import tokenmodule;\n\n");
		formatIndent(ltw, 0, "struct Visitor {\n");

		foreach(rule; this.rules) {
			genVis!false(ltw, rule);
			genVis!true(ltw, rule);
		}

		formatIndent(ltw, 0, "}\n");
	}

	void genParse(File.LockingTextWriter ltw, const(size_t) idx,
			const(size_t) off, Trie t, int indent, Trie[] fail)
	{
		if(idx > 0) {
			formattedWrite(ltw, " else ");
		} else {
			this.genIndent(ltw, indent);
		}

		bool isRepeat = false;
		string prefix = "if";

		if(isLower(t.value.name[0])) {
			formattedWrite(ltw, 
				"%s(this.lex.front.type == TokenType.%s) {\n",
				prefix, t.value.name
			);
			if(t.value.storeThis) {
				formatIndent(ltw, indent + 1, "Token %s = this.lex.front;\n",
					t.value.storeName
				);
			}
			formatIndent(ltw, indent + 1, "this.lex.popFront();\n");
		} else {
			formattedWrite(ltw, "%s(this.first%s()) {\n", prefix, t.value.name);
			this.genIndent(ltw, indent + 1);
			if(t.value.storeThis) {
				formattedWrite(ltw, "%1$s %2$s = this.parse%1$s();\n",
						t.value.name, t.value.storeName
				);
			} else {
				formattedWrite(ltw, "this.parse%s();\n", t.value.name);
			}
		}

		foreach(i, it; t.follow) {
			genParse(ltw, i, t.follow.length, it, indent + 1, t.follow);
		}
		
		//if(t.follow.empty && !t.ruleName.empty) {
		if(!t.ruleName.empty) {
			formattedWrite(ltw, "\n");
			genTrieCtor(ltw, t, indent);
		}
		if(t.ruleName.empty) {
			formattedWrite(ltw, "\n");
			genThrow(ltw, indent + 1, t.follow);
		}
		formattedWrite(ltw, "\n");
		formatIndent(ltw, indent, "}");
	}

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
				formattedWrite(ltw, "this.lex.front.type == TokenType.%s",
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

	void genTrieCtor(File.LockingTextWriter ltw, Trie t, int indent)
			const 
	{
		//formatIndent(ltw, indent + 1, "ret.ruleSelection = %1$sEnum.%2$s;\n", 
		//	t.ruleName, t.subRuleName
		//);
		//formatIndent(ltw, indent + 1, "return ret;");
		formatIndent(ltw, indent + 1, "return this.alloc.make!%s(%1$sEnum.%2$s\n",
				t.ruleName, t.subRuleName
			);
		assert(t.subRule !is null);
		foreach(kt; t.subRule.elements) {
			if(kt.storeThis) {
				formatIndent(ltw, indent + 2, ", %s\n", kt.storeName);
			}
		}
		formatIndent(ltw, indent + 1, ");");
	}

	void genThrow(File.LockingTextWriter ltw, int indent, Trie[] fail) {
		formatIndent(ltw, indent, "auto app = AllocAppender!string(this.alloc);\n");
		formatIndent(ltw, indent, "formattedWrite(&app, \n");
		formatIndent(ltw, indent + 1, "\"Was expecting an");
		foreach(htx, ht; fail) {
			if(htx == 0) {
				formattedWrite(ltw, " %s", ht.value.name);
			} else if(htx + 1 == fail.length) {
				formattedWrite(ltw, ", or %s", ht.value.name);
			} else {
				formattedWrite(ltw, ", %s", ht.value.name);
			}
		}
		formattedWrite(ltw, ". Found a '%%s' at %%s:%%s.\", \n");
		formatIndent(ltw, indent + 1, "this.lex.front, this.lex.line, this.lex.column\n");
		formatIndent(ltw, indent, ");\n");
		formatIndent(ltw, indent, "throw this.alloc.make!ParseException(app.data,\n");
		formatIndent(ltw, indent + 1, "__FILE__, __LINE__\n");
		formatIndent(ltw, indent, ");\n");
	}

	void genRule(File.LockingTextWriter ltw, Rule rule) {
		genFirst(ltw, rule);
		auto t = ruleToTrie(rule);
		writeln("Rule Trie Start");
		foreach(it; t) {
			writeln(it.toString());
		}
		//return;
		writeln("Rule Trie Done");
		formatIndent(ltw, 1, "%1$s parse%1$s() {\n", rule.name);
		formatIndent(ltw, 2, "try {\n");
		formatIndent(ltw, 3, "return this.parse%sImpl();\n", rule.name);
		formatIndent(ltw, 2, "} catch(ParseException e) {\n");
		formatIndent(ltw, 3, 
				"throw this.alloc.make!(ParseException)(\n");
		formatIndent(ltw, 4, "\"While parsing a %s an Exception "
				~ "was thrown.\",\n", rule.name
		);
		formatIndent(ltw, 4, "e, __FILE__, __LINE__\n");
		formatIndent(ltw, 3, ");\n");
		formatIndent(ltw, 2, "}\n");
		formatIndent(ltw, 1, "}\n\n");

		formatIndent(ltw, 1, "%1$s parse%1$sImpl() {\n", rule.name);
		//formatIndent(ltw, 2, "%1$s ret = refCounted!%1$s(%1$s());\n", rule.name);
		foreach(i, it; t) {
			genParse(ltw, i, t.length, it, 2, t);
		}
			
		formattedWrite(ltw, "\n");
		genThrow(ltw, 2, t);
		formattedWrite(ltw, "\n");
		formatIndent(ltw, 1, "}\n\n");
	}

	void genParserClass(File.LockingTextWriter ltw, bool customParseFunctions) {
		formatIndent(ltw, 0, "module parser;\n\n");
		formatIndent(ltw, 0, "import std.typecons : RefCounted, refCounted;\n");
		formatIndent(ltw, 0, "import std.experimental.allocator;\n\n");
		formatIndent(ltw, 0, "import std.format : format;\n");
		formatIndent(ltw, 0, "import ast;\n");
		if(customParseFunctions) {
			formatIndent(ltw, 0, "public import parsercustom;\n\n");
		}
		formatIndent(ltw, 0, "import tokenmodule;\n\n");
		formatIndent(ltw, 0, "import lexer;\n\n");
		formatIndent(ltw, 0, "import exception;\n\n");

		formatIndent(ltw, 0, "struct Parser {\n");
		formatIndent(ltw, 1, "import vibe.utils.array : AllocAppender;\n\n");
		formatIndent(ltw, 1, "import std.format : formattedWrite;\n\n");
		formatIndent(ltw, 1, "Lexer lex;\n\n");
		formatIndent(ltw, 1, "IAllocator alloc;\n\n");
		formatIndent(ltw, 1, "this(Lexer lex, IAllocator alloc) {\n");
		formatIndent(ltw, 2, "this.lex = lex;\n");
		formatIndent(ltw, 2, "this.alloc = alloc;\n");
		formatIndent(ltw, 1, "}\n\n");
		this.genRules(ltw);
		formatIndent(ltw, 0, "}\n");
	}

	void genParseException(File.LockingTextWriter ltw) {
		formatIndent(ltw, 0, "module exception;\n\n");

		formatIndent(ltw, 0, "class ParseException : Exception {\n");
		formatIndent(ltw, 1, "int line;\n");
		formatIndent(ltw, 1, "this(string msg) {\n");
		formatIndent(ltw, 2, "super(msg);\n");
		formatIndent(ltw, 1, "}\n\n");
		formatIndent(ltw, 1, "this(string msg, string f, int l) {\n");
		formatIndent(ltw, 2, "super(msg, f, l);\n");
		formatIndent(ltw, 2, "this.line = l;\n");
		formatIndent(ltw, 1, "}\n\n");
		formatIndent(ltw, 1, 
			"this(string msg, ParseException other) {\n"
		);
		formatIndent(ltw, 2, "super(msg, other);\n");
		formatIndent(ltw, 1, "}\n\n");
		formatIndent(ltw, 1, 
			"this(string msg, ParseException other, string f, int l) {\n"
		);
		formatIndent(ltw, 2, "super(msg, f, l, other);\n");
		formatIndent(ltw, 2, "this.line = l;\n");
		formatIndent(ltw, 1, "}\n\n");
		formatIndent(ltw, 1, "override string toString() {\n");
		formatIndent(ltw, 2, "import std.format : format;\n");
		formatIndent(ltw, 2, "return format(\"%%s at %%d:\", super.msg, "
			~ "this.line);\n");
		formatIndent(ltw, 1, "}\n");
		formatIndent(ltw, 0, "}\n");
	}
}


struct Options {
	string inputFile = "graghql.yaml";
	string astOut;
	string parserOut;
	string visitorOut;
	string exceptionOut;
	bool printHelp = false;
	bool customParseFunctions;
}

const(Options) getOptions(string[] args) {
	import std.getopt;
	Options options;

	auto rslt = getopt(args, 
			"i|inputFile", "The grammar input file", &options.inputFile,
			"a|astOut", "The output file for the ast node.", &options.astOut,
			"v|visitorOut", "The output file for the visitor.",
				&options.visitorOut,
			"e|exceptionOut", "The output file for the ParseException.",
				&options.exceptionOut,
			"p|parseOut", "The output file for the parser node.",
				&options.parserOut,
			"c|custom", "Pass if you want/need to provide custom parse functions.",
				&options.customParseFunctions
		);

	if(rslt.helpWanted) {
		defaultGetoptPrinter("", rslt.options);
		options.printHelp = true;
	}

	return options;
}

void main(string[] args) {
	import std.array : empty;

	auto opts = getOptions(args);
	if(opts.printHelp) {
		return;
	}

	auto darser = new Darser(opts.inputFile);

	if(!opts.astOut.empty) {
		auto f = File(opts.astOut, "w");
		darser.generateClasses(f.lockingTextWriter(),
				opts.customParseFunctions);
	} else {
		darser.generateClasses(stdout.lockingTextWriter(),
				opts.customParseFunctions);
	}

	if(!opts.parserOut.empty) {
		auto f = File(opts.parserOut, "w");
		darser.genParserClass(f.lockingTextWriter(), opts.customParseFunctions);
	} else {
		darser.genParserClass(stdout.lockingTextWriter(),
				opts.customParseFunctions);
	}

	if(!opts.visitorOut.empty) {
		auto f = File(opts.visitorOut, "w");
		darser.genDefaultVisitor(f.lockingTextWriter());
	} else {
		darser.genDefaultVisitor(stdout.lockingTextWriter());
	}

	if(!opts.exceptionOut.empty) {
		auto f = File(opts.exceptionOut, "w");
		darser.genParseException(f.lockingTextWriter());
	} else {
		darser.genParseException(stdout.lockingTextWriter());
	}
}

