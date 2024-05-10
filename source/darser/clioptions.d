module darser.clioptions;

import std.array : back, empty;

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
	bool safe;
	bool pure_;
	bool ddd;

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
				&options.expendedFirst,
			"z|safe", "Mark all generated files as @safe",
				&options.safe,
			"k|pure", "Mark all generated files as pure",
				&options.pure_,
			"d|ddd", "Data driven design parser",
				&options.ddd
		);

	if(rslt.helpWanted) {
		defaultGetoptPrinter("", rslt.options);
		options.printHelp = true;
	}
}
