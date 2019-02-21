import std.stdio;
import std.exception : enforce;
import std.format;
import std.algorithm.iteration : joiner;
import std.conv : to;
import std.array : back, front, empty, popFront, popBack;

import dyaml;

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

bool isLowerStr(string str) {
	import std.exception : enforce;
	import std.uni : isLower;
	enforce(!str.empty);

	return isLower(str[0]);
}

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
		import std.algorithm.comparison : cmp;
		return cmp(this.path.back, other.path.back);
	}

	string toString() {
		import std.array : appender;
		import std.format : formattedWrite;
		import std.algorithm : joiner;

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
	import std.algorithm : setIntersection, setDifference, map;
	import std.array : empty, array;
	import std.uni : isLower, isUpper;
	import std.file : readText;

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
				if(kt.value.isScalar() && kt.value.as!string() == "extern") {
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

	string[] getExpandedFirstSet(string name) {
		if(isLowerStr(name)) {
			return [name];
		} else {
			return expandedFirstSet[name].map!(a => a.getLast()).array;
		}
	}

	static RulePart[string] unique(Rule rule) {
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

	void generateClasses(File.LockingTextWriter ltw, string customParseFilename)
	{
		formatIndent(ltw, 0, "module %sast;\n\n", options.getAstModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());
		formatIndent(ltw, 0, "import %svisitor;\n\n",
				options.getVisitorModule());
		if(!customParseFilename.empty) {
			formatIndent(ltw, 0, readText(customParseFilename));
		}

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
				if(!value.name.empty && isLowerStr(value.name)) {
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
						if(isLowerStr(jt.name)) {
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
						if(isLowerStr(jt.name)) {
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
			generateVisitor(ltw, rule);
			formattedWrite(ltw, "}\n\n");
			//formattedWrite(ltw, "alias %1$s = RefCounted!(%1$s);\n\n", rule.name);
		}
	}

	void genRules(File.LockingTextWriter ltw) {
		auto t = new Trie();
		foreach(rule;  this.rules) {
			foreach(subRule; rule.subRules) {
				ruleToTrieRecur(t, subRule, subRule.elements, rule.name);
			}
			this.genRule(ltw, rule);
		}
		//writeln("\n\n\n\nTrie\n");
		//printTrie(t, 0);
	}

	static void genIndent(File.LockingTextWriter ltw, int indent) {
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

	void buildTerminalFirstSets() {
		import std.algorithm.sorting : sort;
		foreach(rule; this.rules) {
			this.expandedFirstSet[rule.name] =
				this.buildTerminalFirstSet(rule);
			this.expandedFirstSet[rule.name].sort();
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
			toProcess ~= tmp;
		}
	}

	FirstRulePath[] buildTerminalFirstSet(Rule rule) {
		import std.algorithm.searching : canFind, find;
		FirstRulePath[] toProcess = new FirstRulePath[0];
		addSubRuleFirst(rule, toProcess);

		FirstRulePath[] ret = new FirstRulePath[0];
		while(!toProcess.empty) {
			FirstRulePath t = toProcess.back;
			//writefln("%s toProcess %s",
			//		toProcess.map!(a => a.getLast()), t
			//	);
			toProcess.popBack();

			if(isLowerStr(t.getLast())) {
				if(!canFind(ret, t)) {
					ret ~= t;
				}
				continue;
			}

			Rule r = this.getRule(t.getLast());
			addSubRuleFirst(r, toProcess, t.path);
		}
		return ret;
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

	static void genVis(bool cns)(File.LockingTextWriter ltw, Rule rule) {
		formatIndent(ltw, 0, "\n");
		if(cns) {
			formatIndent(ltw, 1, "void enter(const(%1$s) obj) {}\n",
				rule.name
			);
			formatIndent(ltw, 1, "void exit(const(%1$s) obj) {}\n",
				rule.name
			);
		} else {
			formatIndent(ltw, 1, "void enter(%1$s obj) {}\n",
				rule.name
			);
			formatIndent(ltw, 1, "void exit(%1$s obj) {}\n",
				rule.name
			);
		}

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
		formatIndent(ltw, 2, "enter(obj);\n");

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
		formatIndent(ltw, 2, "exit(obj);\n");
		formatIndent(ltw, 1, "}\n");
	}

	static void genTreeVis(File.LockingTextWriter ltw, Rule rule) {
		formatIndent(ltw, 0, "\n");
		formatIndent(ltw, 1, "override void accept(const(%s) obj) {\n",
			rule.name
		);

		formatIndent(ltw, 2, "this.genIndent();\n");
		formatIndent(ltw, 2, "writeln(Unqual!(typeof(obj)).stringof"
			~ ",\":\", obj.ruleSelection);\n");
		formatIndent(ltw, 2, "++this.depth;\n");
		formatIndent(ltw, 2, "super.accept(obj);\n");
		formatIndent(ltw, 2, "--this.depth;\n");
		formatIndent(ltw, 1, "}\n");
	}

	void genDefaultVisitor(File.LockingTextWriter ltw, string customAstFilename)
	{
		formatIndent(ltw, 0, "module %svisitor;\n\n", options.getVisitorModule());
		formatIndent(ltw, 0, "import %sast;\n", options.getAstModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());
		formatIndent(ltw, 0, "class Visitor {\n");

		if(!customAstFilename.empty) {
			formatIndent(ltw, 0, readText(customAstFilename));
		}

		foreach(rule; this.rules) {
			genVis!false(ltw, rule);
			genVis!true(ltw, rule);
		}

		formatIndent(ltw, 0, "}\n");
	}

	void genTreeVisitor(File.LockingTextWriter ltw) {
		formatIndent(ltw, 0, "module %streevisitor;\n\n",
				options.getTreeVisitorModule());
		formatIndent(ltw, 0, "import std.traits : Unqual;\n");
		formatIndent(ltw, 0, "import %sast;\n", options.getAstModule());
		formatIndent(ltw, 0, "import %svisitor;\n", options.getVisitorModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());
		formatIndent(ltw, 0, "class TreeVisitor : Visitor {\n");
		formatIndent(ltw, 1, "import std.stdio : write, writeln;\n\n");
		formatIndent(ltw, 1, "alias accept = Visitor.accept;\n\n");
		formatIndent(ltw, 1, "int depth;\n\n");
		formatIndent(ltw, 1, `this(int d) {
		this.depth = d;
	}

`);
		formatIndent(ltw, 1, `void genIndent() {
		foreach(i; 0 .. this.depth) {
			write("    ");
		}
	}
`);
		foreach(rule; this.rules) {
			genTreeVis(ltw, rule);
		}

		formatIndent(ltw, 0, "}\n");
	}

	void genParse(File.LockingTextWriter ltw, const(string) ruleName,
			const(size_t) idx, const(size_t) off, Trie t, int indent,
			Trie[] fail)
	{
		//writefln("genParse %s %s", t.value.name, t.follow.length);

		if(idx > 0) {
			formattedWrite(ltw, " else ");
		} else {
			formatIndent(ltw, indent, "subRules = [%(%s, %)];\n",
				t.subRuleNames
			);
			genIndent(ltw, indent);
		}

		bool isRepeat = false;

		if(isLowerStr(t.value.name)) {
			formattedWrite(ltw,
				"if(this.lex.front.type == TokenType.%s) {\n",
				t.value.name
			);
			if(t.value.storeThis) {
				formatIndent(ltw, indent + 1, "Token %s = this.lex.front;\n",
					t.value.storeName
				);
			}
			formatIndent(ltw, indent + 1, "this.lex.popFront();\n");
		} else {
			formattedWrite(ltw, "if(this.first%s()) {\n", t.value.name);
			genIndent(ltw, indent + 1);
			if(t.value.storeThis) {
				formattedWrite(ltw, "%1$s %2$s = this.parse%1$s();\n",
						t.value.name, t.value.storeName
				);
			} else {
				formattedWrite(ltw, "this.parse%s();\n", t.value.name);
			}
		}

		// testing first first conflicts
		for(size_t i = 0; i < t.follow.length; ++i) {
			for(size_t j = i + 1; j < t.follow.length; ++j) {
				string[] ifs = this.getExpandedFirstSet(
										t.follow[i].value.name
									);
				string[] jfs = this.getExpandedFirstSet(
										t.follow[j].value.name
									);
				//writefln("FF %s:\n%s\n%s", t.value.name, ifs, jfs);
				enforce(setIntersection(ifs, jfs).empty, format(
						"First first conflict in '%s'\nfollowing '%s' between "
						~ "'%s[%(%s,%)]' and '%s[%(%s,%)]'", ruleName,
						t.value.name, t.follow[i].value.name, ifs,
						t.follow[j].value.name, jfs
					)
				);
			}
		}

		foreach(i, it; t.follow) {
			genParse(ltw, ruleName, i, t.follow.length, it, indent + 1, t.follow);
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

	static void genFirst(File.LockingTextWriter ltw, Rule rule) {
		bool[string] found;
		formatIndent(ltw, 1, "bool first%s() const pure @nogc @safe {\n",
				rule.name
			);
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
			if(isLowerStr(subRule.elements[0].name)) {
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

	static void genTrieCtor(File.LockingTextWriter ltw, Trie t, int indent) {
		//formatIndent(ltw, indent + 1, "ret.ruleSelection = %1$sEnum.%2$s;\n",
		//	t.ruleName, t.subRuleName
		//);
		//formatIndent(ltw, indent + 1, "return ret;");
		formatIndent(ltw, indent + 1, "return new %s(%1$sEnum.%2$s\n",
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
		formatIndent(ltw, indent, "auto app = appender!string();\n");
		formatIndent(ltw, indent, "formattedWrite(app, \n");
		string[] follows;
		foreach(htx, ht; fail) {
			string msg = ht.value.name;
			if(msg in this.expandedFirstSet) {
				follows ~= this.expandedFirstSet[msg]
					.map!(a => a.toFollowError())
					.array;
			} else {
				follows ~= "\"" ~ msg ~ "\"";
			}
		}
		formatIndent(ltw, indent + 1, "\"Found a '%%s' while looking for\", \n");
		formatIndent(ltw, indent + 1, "this.lex.front\n");
		formatIndent(ltw, indent, ");\n");
		formatIndent(ltw, indent, "throw new ParseException(app.data,\n");
		formatIndent(ltw, indent + 1, "__FILE__, __LINE__,\n");
		formatIndent(ltw, indent + 1, "subRules,\n");
		formatIndent(ltw, indent + 1, "[%s]\n",
			follows.joiner(",").to!string()
		);
		formatIndent(ltw, indent, ");\n");
	}

	void genRule(File.LockingTextWriter ltw, Rule rule) {
		genFirst(ltw, rule);
		auto t = ruleToTrie(rule);
		//writeln("Rule Trie Start");
		//foreach(it; t) {
		//	writeln(it.toString());
		//}
		for(size_t i = 0; i < t.length; ++i) {
			for(size_t j = i + 1; j < t.length; ++j) {
				string[] ifs = this.getExpandedFirstSet(
										t[i].value.name
									);
				string[] jfs = this.getExpandedFirstSet(
										t[j].value.name
									);
				//writefln("FF %s:\n%s\n%s", rule.name, ifs, jfs);
				// Same subrules with equal name we can handle
				//if(t[i].value.name == t[j].value.name
				//		|| (isLowerStr(t[i].value.name)
				//			&& isLowerStr(t[j].value.name))
				//) {
				//	continue;
				//}
				auto s = setIntersection(ifs, jfs);
				//writeln(s);
				enforce(s.empty, format(
						"\nFirst first conflict in '%s' between\n"
						~ "'%s:\n\t%(%s\n\t%)'\nand \'%s:\n\t%(%s\n\t%)'\n%s",
						rule.name, t[i].value.name, ifs, t[j].value.name, jfs,
						s)
				);
			}
		}
		//return;
		//writeln("Rule Trie Done");
		formatIndent(ltw, 1, "%1$s parse%1$s() {\n", rule.name);
		formatIndent(ltw, 2, "try {\n");
		formatIndent(ltw, 3, "return this.parse%sImpl();\n", rule.name);
		formatIndent(ltw, 2, "} catch(ParseException e) {\n");
		formatIndent(ltw, 3,
				"throw new ParseException(\n");
		formatIndent(ltw, 4, "\"While parsing a %s an Exception "
				~ "was thrown.\",\n", rule.name
		);
		formatIndent(ltw, 4, "e, __FILE__, __LINE__\n");
		formatIndent(ltw, 3, ");\n");
		formatIndent(ltw, 2, "}\n");
		formatIndent(ltw, 1, "}\n\n");

		formatIndent(ltw, 1, "%1$s parse%1$sImpl() {\n", rule.name);
		formatIndent(ltw, 2, "string[] subRules;\n");
		//formatIndent(ltw, 2, "%1$s ret = refCounted!%1$s(%1$s());\n", rule.name);
		foreach(i, it; t) {
			genParse(ltw, rule.name, i, t.length, it, 2, t);
		}

		formattedWrite(ltw, "\n");
		genThrow(ltw, 2, t);
		formattedWrite(ltw, "\n");
		formatIndent(ltw, 1, "}\n\n");
	}

	void genParserClass(File.LockingTextWriter ltw, string customParseAst) {
		formatIndent(ltw, 0, "module %sparser;\n\n", options.getParserModule());
		formatIndent(ltw, 0, "import std.typecons : RefCounted, refCounted;\n");
		formatIndent(ltw, 0, "import std.format : format;\n");
		formatIndent(ltw, 0, "import %sast;\n", options.getAstModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());
		formatIndent(ltw, 0, "import %slexer;\n\n", options.getLexerModule());
		formatIndent(ltw, 0, "import %sexception;\n\n",
				options.getExceptionModule());

		formatIndent(ltw, 0, "struct Parser {\n");
		formatIndent(ltw, 1, "import std.array : appender;\n\n");
		formatIndent(ltw, 1, "import std.format : formattedWrite;\n\n");
		formatIndent(ltw, 1, "Lexer lex;\n\n");
		formatIndent(ltw, 1, "this(Lexer lex) {\n");
		formatIndent(ltw, 2, "this.lex = lex;\n");
		formatIndent(ltw, 1, "}\n\n");
		this.genRules(ltw);
		if(!customParseAst.empty) {
			formattedWrite(ltw, readText(customParseAst));
		}
		formatIndent(ltw, 0, "}\n");
	}

	static void genParseException(File.LockingTextWriter ltw) {
		string t = `module %sexception;

class ParseException : Exception {
	int line;
	string[] subRules;
	string[] follows;

	this(string msg) {
		super(msg);
	}

	this(string msg, string f, int l, string[] subRules, string[] follows) {
		import std.format : format;
		super(format(
			"%%s [%%(%%s,%%)]: While in subRules [%%(%%s, %%)]",
			msg, follows, subRules), f, l
		);
		this.line = l;
		this.subRules = subRules;
		this.follows = follows;
	}

	this(string msg, ParseException other) {
		super(msg, other);
	}

	this(string msg, ParseException other, string f, int l) {
		super(msg, f, l, other);
		this.line = l;
	}
}
`;
		formattedWrite(ltw, t, options.getExceptionModule());
	}
}

struct Options {
	string inputFile;
	string astOut;
	string astModule;
	string parserOut;
	string parserModule;
	string visitorOut;
	string visitorModule;
	string treeVisitorOut;
	string treeVisitorModule;
	string tokenModule;
	string lexerModule;
	string exceptionOut;
	string exceptionModule;
	bool printHelp;
	string customParseFile;
	string customAstFile;
	string customVisFile;
	string[] expendedFirst;

	string getParserModule() {
		if(this.parserModule.empty) {
			return "";
		} else if(this.parserModule.back == '.') {
			return this.parserModule;
		} else {
			return this.parserModule ~ ".";
		}
	}

	string getExceptionModule() {
		if(this.exceptionModule.empty) {
			return "";
		} else if(this.exceptionModule.back == '.') {
			return this.exceptionModule;
		} else {
			return this.exceptionModule ~ ".";
		}
	}

	string getLexerModule() {
		if(this.lexerModule.empty) {
			return "";
		} else if(this.lexerModule.back == '.') {
			return this.lexerModule;
		} else {
			return this.lexerModule ~ ".";
		}
	}

	string getTreeVisitorModule() {
		if(this.treeVisitorModule.empty) {
			return "";
		} else if(this.treeVisitorModule.back == '.') {
			return this.treeVisitorModule;
		} else {
			return this.treeVisitorModule ~ ".";
		}
	}

	string getTokenModule() {
		if(this.tokenModule.empty) {
			return "";
		} else if(this.tokenModule.back == '.') {
			return this.tokenModule;
		} else {
			return this.tokenModule ~ ".";
		}
	}

	string getVisitorModule() {
		if(this.visitorModule.empty) {
			return "";
		} else if(this.visitorModule.back == '.') {
			return this.visitorModule;
		} else {
			return this.visitorModule ~ ".";
		}
	}

	string getAstModule() {
		if(this.astModule.empty) {
			return "";
		} else if(this.astModule.back == '.') {
			return this.astModule;
		} else {
			return this.astModule ~ ".";
		}
	}
}

Options options;

void getOptions(string[] args) {
	import std.getopt;

	auto rslt = getopt(args,
			"i|inputFile", "The grammar input file", &options.inputFile,
			"a|astOut", "The output file for the ast node.", &options.astOut,
			"b|astModule", "The module name of the ast module.",
				&options.astModule,
			"v|visitorOut", "The output file for the visitor.",
				&options.visitorOut,
			"w|visitorModule", "The module name of the visitor module.",
				&options.visitorModule,
			"t|treeVisitorOut", "The output file for the tree visitor.",
				&options.treeVisitorOut,
			"r|treeVisitorModule", "The module name of the treeVisitor module.",
				&options.treeVisitorModule,
			"u|tokenModule", "The module name of the token module.",
				&options.tokenModule,
			"s|lexerModule", "The module name of the lexer module.",
				&options.lexerModule,
			"e|exceptionOut", "The output file for the ParseException.",
				&options.exceptionOut,
			"g|exceptionModule",
				"The module name of the exception module.",
				&options.exceptionModule,
			"p|parseOut", "The output file for the parser node.",
				&options.parserOut,
			"q|parserModule",
				"The module name of the parserModule module.",
				&options.parserModule,
			"customParse", "Filename of custom parse functions",
				&options.customParseFile,
			"customAst", "Filename of custom AST Classes",
				&options.customAstFile,
			"customVis", "Filename of custom Vistor member functions",
				&options.customVisFile,
			"f|first", "Pass name of rule to get the first set",
				&options.expendedFirst
		);

	if(rslt.helpWanted) {
		defaultGetoptPrinter("", rslt.options);
		options.printHelp = true;
	}
}

void main(string[] args) {
	import std.array : empty;

	getOptions(args);
	const opts = options;
	if(opts.printHelp) {
		return;
	}

	auto darser = new Darser(opts.inputFile);
	foreach(ff; options.expendedFirst) {
		if(ff !in darser.expandedFirstSet) {
			writeln("No rule named '%s' exists", ff);
			continue;
		}
		writefln("ExpandedFirstSet for '%s': {", ff);
		foreach(fs; darser.expandedFirstSet[ff]) {
			writefln("%s", fs);
		}
		writeln("}");
	}

	if(!opts.astOut.empty) {
		auto f = File(opts.astOut, "w");
		darser.generateClasses(f.lockingTextWriter(),
				opts.customAstFile);
	} else {
		darser.generateClasses(stderr.lockingTextWriter(),
				opts.customAstFile);
	}

	if(!opts.parserOut.empty) {
		auto f = File(opts.parserOut, "w");
		darser.genParserClass(f.lockingTextWriter(), opts.customParseFile);
	} else {
		darser.genParserClass(stderr.lockingTextWriter(),
				opts.customParseFile);
	}

	if(!opts.visitorOut.empty) {
		auto f = File(opts.visitorOut, "w");
		darser.genDefaultVisitor(f.lockingTextWriter(), opts.customVisFile);
	} else {
		darser.genDefaultVisitor(stderr.lockingTextWriter(), opts.customVisFile);
	}

	if(!opts.treeVisitorOut.empty) {
		auto f = File(opts.treeVisitorOut, "w");
		darser.genTreeVisitor(f.lockingTextWriter());
	} else {
		darser.genTreeVisitor(stderr.lockingTextWriter());
	}

	if(!opts.exceptionOut.empty) {
		auto f = File(opts.exceptionOut, "w");
		darser.genParseException(f.lockingTextWriter());
	} else {
		darser.genParseException(stderr.lockingTextWriter());
	}
}

