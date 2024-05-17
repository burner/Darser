module darser.helper;

import std.array : empty;
import std.conv : to;
import std.exception : enforce;
import std.format : formattedWrite;
import std.uni : isLower, toLower;
import std.stdio : File;

void formatIndent(O,Args...)(ref O o, long indent, string str,
		auto ref Args args)
{
	while(indent > 0) {
		formattedWrite(o, "\t");
		--indent;
	}
	formattedWrite(o, str, args);
}

bool isLowerStr(string str) {
	enforce(!str.empty);

	return isLower(str[0]);
}

string toLowerFirst(string str) {
	if(str.empty) {
		return "";
	}

	dchar f = toLower(str[0]);
	return to!string(f) ~ str[1 .. $];
}

void genIndent(File.LockingTextWriter ltw, int indent) {
	while(indent > 0) {
		formattedWrite(ltw, "\t");
		--indent;
	}
}
