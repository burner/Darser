module darser.app;

import std.array : appender, array, back, front, empty, popFront, popBack;
import std.conv : to;
import std.exception : enforce;
import std.file : readText;
import std.format;
import std.stdio;
import std.uni : isLower, isUpper;

import darser.rules;
import darser.trie;
import darser.helper;
import darser.clioptions;
import darser.output;
import darser.helper;
import darser.darserstructure;

void main(string[] args) {
	getOptions(args);
	const opts = options;
	if(opts.printHelp) {
		return;
	}

	auto darser = new Darser(opts.inputFile);
	Output output = new ClassBasedOutput(darser);

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
		output.generateClasses(f.lockingTextWriter(), opts.customAstFile);
	} else {
		output.generateClasses(stderr.lockingTextWriter(), opts.customAstFile);
	}

	if(!opts.parserOut.empty) {
		auto f = File(opts.parserOut, "w");
		output.genParserClass(f.lockingTextWriter(), opts.customParseFile);
	} else {
		output.genParserClass(stderr.lockingTextWriter(), opts.customParseFile);
	}

	if(!opts.visitorOut.empty) {
		auto f = File(opts.visitorOut, "w");
		output.genDefaultVisitor(f.lockingTextWriter(), opts.customVisFile);
	} else {
		output.genDefaultVisitor(stderr.lockingTextWriter(), opts.customVisFile);
	}

	if(!opts.treeVisitorOut.empty) {
		auto f = File(opts.treeVisitorOut, "w");
		output.genTreeVisitor(f.lockingTextWriter());
	} else {
		output.genTreeVisitor(stderr.lockingTextWriter());
	}

	if(!opts.exceptionOut.empty) {
		auto f = File(opts.exceptionOut, "w");
		output.genParseException(f.lockingTextWriter());
	} else {
		output.genParseException(stderr.lockingTextWriter());
	}
}

