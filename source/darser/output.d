module darser.output;

import std.algorithm.iteration : joiner, map;
import std.algorithm.setops : setIntersection, setDifference;
import std.array : array, empty;
import std.conv : to;
import std.exception : enforce;
import std.format;
import std.stdio;
import std.file : readText;
import std.uni : isLower, isUpper;

import darser.helper;
import darser.rules;
import darser.clioptions;
import darser.darserstructure;
import darser.trie;

abstract class Output {
	Darser darser;
	this(Darser darser) {
		this.darser = darser;
	}

	abstract void generateClasses(File.LockingTextWriter ltw
			, string customParseFilename);
	abstract void genRules(File.LockingTextWriter ltw);
	abstract void genParseException(File.LockingTextWriter ltw);
	abstract void genParserClass(File.LockingTextWriter ltw, string customParseAst);
	abstract void genTreeVisitor(File.LockingTextWriter ltw);
	abstract void genDefaultVisitor(File.LockingTextWriter ltw
			, string customAstFilename);
}

class DoDBasedOutout : ClassBasedOutput {
	this(Darser darser) {
		super(darser);
	}

	private static string enumType(size_t length) pure {
		if(length < ubyte.max) {
			return "ubyte";
		} else if(length < ushort.max) {
			return "ushort";
		} else if(length < uint.max) {
			return "uint";
		} else if(length < ulong.max) {
			return "ulong";
		}
		enforce(false, "Not reachable");
		assert(false);
	}

	void generateEnum(File.LockingTextWriter ltw, Rule rule) {
		formattedWrite(ltw, "enum %sEnum : %s {\n", rule.name
				, enumType(rule.subRules.length));
		foreach(subRule; rule.subRules) {
			formattedWrite(ltw, "\t%s,\n", subRule.name);

		}
		formattedWrite(ltw, "}\n\n");
	}

	void generateMembers(File.LockingTextWriter ltw, Rule rule) {
		RulePart[string] uni = unique(rule);
		foreach(key, value; uni) {
			if(!value.name.empty && isLowerStr(value.name)) {
				formattedWrite(ltw, "\tuint %sTokenIdx;\n", key);
			} else {
				formattedWrite(ltw, "\tuint %sIdx;\n", value.name, key);
			}
		}
		formattedWrite(ltw, "\n");
	}

	override void generateClasses(File.LockingTextWriter ltw
			, string customParseFilename)
	{
		formatIndent(ltw, 0, "module %sast;\n\n", options.getAstModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());
		formatIndent(ltw, 0, "import %svisitor;\n\n",
				options.getVisitorModule());
		if(options.safe || options.pure_) {
			string t =
					(options.safe ? "@safe " : "")
					~ (options.pure_ ? "pure" : "");
			t = t.empty ? t : t ~ ":";
			formatIndent(ltw, 0, "%s\n\n", t);
		}

		foreach(rule; this.darser.rules) {
			generateEnum(ltw, rule);
			formattedWrite(ltw, "struct %s {\n", rule.name);
			if(options.safe || options.pure_) {
				string t =
						(options.safe ? "@safe " : "")
						~ (options.pure_ ? "pure" : "");
				t = t.empty ? t : t ~ ":";
				formatIndent(ltw, 0, "%s\n\n", t);
			}
			generateMembers(ltw, rule);
			//genereateCTors(ltw, rule);
			//generateVisitor(ltw, rule);
			formattedWrite(ltw, "\t%sEnum ruleSelection;\n", rule.name);
			formattedWrite(ltw, "}\n\n");
			//formattedWrite(ltw, "alias %1$s = RefCounted!(%1$s);\n\n", rule.name);
		}
	}

	override void genParserClass(File.LockingTextWriter ltw
			, string customParseAst)
	{
		formatIndent(ltw, 0, "module %sparser;\n\n", options.getParserModule());
		formatIndent(ltw, 0, "import std.array : appender;\n");
		formatIndent(ltw, 0, "import std.format : formattedWrite;\n");
		formatIndent(ltw, 0, "import std.format : format;\n\n");
		formatIndent(ltw, 0, "import %sast;\n", options.getAstModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());
		formatIndent(ltw, 0, "import %slexer;\n\n", options.getLexerModule());
		formatIndent(ltw, 0, "import %sexception;\n\n",
				options.getExceptionModule());

		formatIndent(ltw, 0, "struct Parser {\n");
		if(options.safe || options.pure_) {
			string t =
					(options.safe ? "@safe " : "")
					~ (options.pure_ ? "pure" : "");
			t = t.empty ? t : t ~ ":";
			formatIndent(ltw, 0, "%s\n\n", t);
		}
		foreach(rule; this.darser.rules) {
			formatIndent(ltw, 1, "%s[] %ss;\n", rule.name, rule.name.toLowerFirst());
		}
		formatIndent(ltw, 1, "Lexer lex;\n\n");
		formatIndent(ltw, 1, "this(Lexer lex) {\n");
		formatIndent(ltw, 2, "this.lex = lex;\n");
		formatIndent(ltw, 1, "}\n\n");
		this.genRules(ltw);
		if(!customParseAst.empty) {
			formattedWrite(ltw, readText(customParseAst));
		}
		formatIndent(ltw, 0, "}\n");
		formatIndent(ltw, 0, "}\n\n");
	}

	override void genParse(File.LockingTextWriter ltw, const(string) ruleName,
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
				formatIndent(ltw, indent + 1, "uint %s = this.lex.frontTokenIndex;\n",
					t.value.storeName
				);
			}
			formatIndent(ltw, indent + 1, "this.lex.popFront();\n");
		} else {
			formattedWrite(ltw, "if(this.first%s()) {\n", t.value.name);
			genIndent(ltw, indent + 1);
			if(t.value.storeThis) {
				formattedWrite(ltw, "uint %2$s = this.parse%1$s();\n",
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
			genThrow(ltw, indent + 1, t.follow, ruleName);
		}
		formattedWrite(ltw, "\n");
		formatIndent(ltw, indent, "}");
	}
}

class ClassBasedOutput : Output {
	this(Darser darser) {
		super(darser);
	}
	override void generateClasses(File.LockingTextWriter ltw
			, string customParseFilename)
	{
		formatIndent(ltw, 0, "module %sast;\n\n", options.getAstModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());
		formatIndent(ltw, 0, "import %svisitor;\n\n",
				options.getVisitorModule());
		if(options.safe || options.pure_) {
			string t =
					(options.safe ? "@safe " : "")
					~ (options.pure_ ? "pure" : "");
			t = t.empty ? t : t ~ ":";
			formatIndent(ltw, 0, "%s\n\n", t);
		}
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
			RulePart[string] uni = unique(rule);
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

	void visit(ConstVisitor vis) {
		vis.accept(this);
	}

	void visit(ConstVisitor vis) const {
		vis.accept(this);
	}
`
			);

		}

		formattedWrite(ltw, "class Node {}\n\n");
		foreach(rule; this.darser.rules) {
			generateEnum(ltw, rule);
			formattedWrite(ltw, "class %s : Node {\n", rule.name);
			if(options.safe || options.pure_) {
				string t =
						(options.safe ? "@safe " : "")
						~ (options.pure_ ? "pure" : "");
				t = t.empty ? t : t ~ ":";
				formatIndent(ltw, 0, "%s\n\n", t);
			}
			formattedWrite(ltw, "\t%sEnum ruleSelection;\n", rule.name);
			generateMembers(ltw, rule);
			genereateCTors(ltw, rule);
			generateVisitor(ltw, rule);
			formattedWrite(ltw, "}\n\n");
			//formattedWrite(ltw, "alias %1$s = RefCounted!(%1$s);\n\n", rule.name);
		}
	}

	override void genRules(File.LockingTextWriter ltw) {
		auto t = new Trie();
		foreach(rule; this.darser.rules) {
			foreach(subRule; rule.subRules) {
				ruleToTrieRecur(t, subRule, subRule.elements, rule.name);
			}
			this.genRule(ltw, rule);
		}
		//writeln("\n\n\n\nTrie\n");
		//printTrie(t, 0);
	}

	override void genParseException(File.LockingTextWriter ltw) {
		string t = "module %sexception;\n\n";
		formattedWrite(ltw, t, options.getExceptionModule());

		formattedWrite(ltw,
`
class ParseException : Exception {
%s
	int line;
	string[] subRules;
	string[] follows;

	this(string msg) {
		super(msg);
	}

	this(string msg, string f, int l, string[] subRules, string[] follows) {
		import std.format : format;
		super(format(
			"%%s [%%(%%s,%%)]: While in subRules [%%(%%s, %%)] at %%s:%%s",
			msg, follows, subRules, f, l), f, l
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
`, (options.safe && options.pure_)
	? "@safe pure:\n"
	: options.safe
		? "@safe:\n"
		: options.pure_ ? "pure:\n" : ""
);
	}

	override void genParserClass(File.LockingTextWriter ltw, string customParseAst) {
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
		if(options.safe || options.pure_) {
			string t =
					(options.safe ? "@safe " : "")
					~ (options.pure_ ? "pure" : "");
			t = t.empty ? t : t ~ ":";
			formatIndent(ltw, 0, "%s\n\n", t);
		}
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

	override void genTreeVisitor(File.LockingTextWriter ltw) {
		formatIndent(ltw, 0, "module %streevisitor;\n\n",
				options.getTreeVisitorModule());
		formatIndent(ltw, 0, "import std.traits : Unqual;\n");
		formatIndent(ltw, 0, "import %sast;\n", options.getAstModule());
		formatIndent(ltw, 0, "import %svisitor;\n", options.getVisitorModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());
		formatIndent(ltw, 0, "class TreeVisitor : ConstVisitor {\n");
		if(options.safe || options.pure_) {
			string t =
					(options.safe ? "@safe " : "")
					~ (options.pure_ ? "pure" : "");
			t = t.empty ? t : t ~ ":";
			formatIndent(ltw, 0, "%s\n\n", t);
		}
		formatIndent(ltw, 1, "import std.stdio : write, writeln;\n\n");
		formatIndent(ltw, 1, "alias accept = ConstVisitor.accept;\n\n");
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
		foreach(rule; this.darser.rules) {
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
			genThrow(ltw, indent + 1, t.follow, ruleName);
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
		formatIndent(ltw, indent + 1, "this.%3$s ~= %s(%1$sEnum.%2$s\n",
				t.ruleName, t.subRuleName, t.ruleName.toLowerFirst()
			);
		assert(t.subRule !is null);
		foreach(kt; t.subRule.elements) {
			if(kt.storeThis) {
				formatIndent(ltw, indent + 2, ", %s\n", kt.storeName);
			}
		}
		formatIndent(ltw, indent + 1, ");\n");
		formatIndent(ltw, indent + 1, "return this.%1$s.length - 1;\n", t.ruleName);
	}

	void genThrow(File.LockingTextWriter ltw, int indent, Trie[] fail,
			string ruleName)
	{
		formatIndent(ltw, indent, "auto app = appender!string();\n");
		formatIndent(ltw, indent, "formattedWrite(app, \n");
		string[] follows;
		foreach(htx, ht; fail) {
			string msg = ht.value.name;
			if(msg in darser.expandedFirstSet) {
				follows ~= darser.expandedFirstSet[msg]
					.map!(a => a.toFollowError())
					.array;
			} else {
				follows ~= "\"" ~ msg ~ "\"";
			}
		}
		formatIndent(ltw, indent + 1,
				"\"In '%s' found a '%%s' while looking for\", \n", ruleName);
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
		formatIndent(ltw, 1, "uint parse%1$s() {\n", rule.name);
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

		formatIndent(ltw, 1, "uint parse%1$sImpl() {\n", rule.name);
		formatIndent(ltw, 2, "string[] subRules;\n");
		//formatIndent(ltw, 2, "%1$s ret = refCounted!%1$s(%1$s());\n", rule.name);
		foreach(i, it; t) {
			genParse(ltw, rule.name, i, t.length, it, 2, t);
		}

		formattedWrite(ltw, "\n");
		genThrow(ltw, 2, t, rule.name);
		formattedWrite(ltw, "\n");
		formatIndent(ltw, 1, "}\n\n");
	}

	string[] getExpandedFirstSet(string name) {
		if(name !is null && isLowerStr(name)) {
			return [name];
		} else {
			enforce(name in this.darser.expandedFirstSet, format("%s not in [%s]", name,
					this.darser.expandedFirstSet.keys));
			return this.darser.expandedFirstSet[name].map!(a => a.getLast()).array;
		}
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

	override void genDefaultVisitor(File.LockingTextWriter ltw, string customAstFilename)
	{
		formatIndent(ltw, 0, "module %svisitor;\n\n", options.getVisitorModule());
		formatIndent(ltw, 0, "import %sast;\n", options.getAstModule());
		formatIndent(ltw, 0, "import %stokenmodule;\n\n",
				options.getTokenModule());

		// Visitor
		formatIndent(ltw, 0, "class Visitor : ConstVisitor {\n");
		if(options.safe || options.pure_) {
			string t =
					(options.safe ? "@safe " : "")
					~ (options.pure_ ? "pure" : "");
			t = t.empty ? t : t ~ ":";
			formatIndent(ltw, 0, "%s\n\n", t);
		}
		formatIndent(ltw, 1, "alias accept = ConstVisitor.accept;\n\n");
		formatIndent(ltw, 1, "alias enter = ConstVisitor.enter;\n\n");
		formatIndent(ltw, 1, "alias exit = ConstVisitor.exit;\n\n");
		if(!customAstFilename.empty) {
			formatIndent(ltw, 0, readText(customAstFilename));
		}
		foreach(rule; this.darser.rules) {
			genVis!false(ltw, rule);
		}
		formatIndent(ltw, 0, "}\n\n");

		// Const Visitor
		formatIndent(ltw, 0, "class ConstVisitor {\n");
		if(options.safe || options.pure_) {
			string t =
					(options.safe ? "@safe " : "")
					~ (options.pure_ ? "pure" : "");
			t = t.empty ? t : t ~ ":";
			formatIndent(ltw, 0, "%s\n\n", t);
		}
		if(!customAstFilename.empty) {
			formatIndent(ltw, 0, readText(customAstFilename));
		}
		foreach(rule; this.darser.rules) {
			genVis!true(ltw, rule);
		}
		formatIndent(ltw, 0, "}\n\n");
	}

}
