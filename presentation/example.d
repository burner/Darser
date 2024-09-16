Definition:
    O: [OperationDefinition#op]
    F: [FragmentDefinition#frag]
    T: [TypeSystemDefinition#type]

class Definition : Node {
@safe :

	DefinitionEnum ruleSelection;
	FragmentDefinition frag;
	TypeSystemDefinition type;
	OperationDefinition op;

	this(DefinitionEnum ruleSelection, OperationDefinition op) {
		this.ruleSelection = ruleSelection;
		this.op = op;
	}

	this(DefinitionEnum ruleSelection, FragmentDefinition frag) {
		this.ruleSelection = ruleSelection;
		this.frag = frag;
	}

	this(DefinitionEnum ruleSelection, TypeSystemDefinition type) {
		this.ruleSelection = ruleSelection;
		this.type = type;
	}

	void visit(Visitor vis) {
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
}

Definition parseDefinitionImpl() {
	if(this.firstOperationDefinition()) {
		OperationDefinition op = this.parseOperationDefinition();

		return new Definition(DefinitionEnum.O, op);
	} else if(this.firstFragmentDefinition()) {
		FragmentDefinition frag = this.parseFragmentDefinition();

		return new Definition(DefinitionEnum.F, frag);
	} else if(this.firstTypeSystemDefinition()) {
		TypeSystemDefinition type = this.parseTypeSystemDefinition();

		return new Definition(DefinitionEnum.T, type);
	}
	auto app = appender!string();
	formattedWrite(app,
		"In 'Definition' found a '%s' while looking for",
		this.lex.front
	);
	throw new ParseException(app.data,
		__FILE__, __LINE__
		, ["lcurly -> SelectionSet","mutation -> OperationType","query -> OperationType","subscription -> OperationType","fragment","directive -> DirectiveDefinition","enum_ -> TypeDefinition","extend -> TypeExtensionDefinition","input -> TypeDefinition","interface_ -> TypeDefinition","scalar -> TypeDefinition","schema -> SchemaDefinition","stringValue -> Description","type -> TypeDefinition","union_ -> TypeDefinition"]
	);
}

bool firstOperationType() const pure @nogc @safe {
	return this.lex.front.type == TokenType.query
		 || this.lex.front.type == TokenType.mutation
		 || this.lex.front.type == TokenType.subscription;
}

class Visitor : ConstVisitor {
	void enter(Definition obj) {}
	void exit(Definition obj) {}

	void accept(Definition obj) {
		enter(obj);
		final switch(obj.ruleSelection) {
			case DefinitionEnum.O:
				obj.op.visit(this);
				break;
			case DefinitionEnum.F:
				obj.frag.visit(this);
				break;
			case DefinitionEnum.T:
				obj.type.visit(this);
				break;
		}
		exit(obj);
	}
}

InlineFragment:
    TDS: [on_, name#tc, Directives#dirs, SelectionSet#ss]
    TS: [on_, name#tc, SelectionSet#ss]
    DS: [Directives#dirs, SelectionSet#ss]
    S: [SelectionSet#ss]

InlineFragment parseInlineFragmentImpl() {
	if(this.lex.front.type == TokenType.on_) {
		this.lex.popFront();
		if(this.lex.front.type == TokenType.name) {
			Token tc = this.lex.front;
			this.lex.popFront();
			if(this.firstDirectives()) {
				Directives dirs = this.parseDirectives();
				if(this.firstSelectionSet()) {
					SelectionSet ss = this.parseSelectionSet();

					return new InlineFragment(InlineFragmentEnum.TDS, tc, dirs, ss);
				}
				throw new ParseException(["lcurly"]);
			} else if(this.firstSelectionSet()) {
				SelectionSet ss = this.parseSelectionSet();

				return new InlineFragment(InlineFragmentEnum.TS, tc, ss);
			}
			throw new ParseException(["at -> Directive","lcurly"]);
		}
		throw new ParseException(["name"]);
	} else if(this.firstDirectives()) {
		Directives dirs = this.parseDirectives();
		if(this.firstSelectionSet()) {
			SelectionSet ss = this.parseSelectionSet();

			return new InlineFragment(InlineFragmentEnum.DS, dirs, ss);
		}
		throw new ParseException(["lcurly"]);
	} else if(this.firstSelectionSet()) {
		SelectionSet ss = this.parseSelectionSet();
		return new InlineFragment(InlineFragmentEnum.S, ss);
	}
	throw new ParseException(["on_","at -> Directive","lcurly"]);
}


struct OperationDefinition {
	uint vdIdx;
	uint otIdx;
	uint dIdx;
	uint ssIdx;
	Token name;
	OperationDefinitionEnum ruleSelection;

struct Parser {
	Document[] documents;
	Definitions[] definitionss;
	Definition[] definitions;
	OperationDefinition[] operationDefinitions;
	SelectionSet[] selectionSets;
	OperationType[] operationTypes;
	Selections[] selectionss;
	Selection[] selections;
	FragmentSpread[] fragmentSpreads;
	InlineFragment[] inlineFragments;
	Field[] fields;
	FieldName[] fieldNames;
	Arguments[] argumentss;
	ArgumentList[] argumentLists;
	Argument[] arguments;
	FragmentDefinition[] fragmentDefinitions;
	Directives[] directivess;
	Directive[] directives;
	VariableDefinitions[] variableDefinitionss;
	VariableDefinitionList[] variableDefinitionLists;
	VariableDefinition[] variableDefinitions;
	Variable[] variables;
	DefaultValue[] defaultValues;
	ValueOrVariable[] valueOrVariables;
	Value[] values;
	Type[] types;

uint parseOperationDefinitionImpl() {
	string[] subRules;
	if(this.firstSelectionSet()) {
		uint ss = this.parseSelectionSet();

		this.operationDefinitions ~= OperationDefinition.ConstructSelSet(ss);
		return cast(uint)(this.operationDefinitions.length - 1);

	} else if(this.firstOperationType()) {
		uint ot = this.parseOperationType();
		if(this.lex.front.type == TokenType.name) {
			Token name = this.lex.front;
			this.lex.popFront();
			if(this.firstVariableDefinitions()) {
				uint vd = this.parseVariableDefinitions();
				if(this.firstDirectives()) {
					uint d = this.parseDirectives();
					if(this.firstSelectionSet()) {
						uint ss = this.parseSelectionSet();

						this.operationDefinitions ~= OperationDefinition.ConstructOT_N_VD(ot, name, vd, d, ss);
						return cast(uint)(this.operationDefinitions.length - 1);

					}

void accept(ref OperationDefinition obj) {
	enter(obj);
	final switch(obj.ruleSelection) {
		case OperationDefinitionEnum.SelSet:
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
		case OperationDefinitionEnum.OT_N_VD:
			this.accept(this.parser.operationTypes[obj.otIdx]);
			obj.name.visit(this);
			this.accept(this.parser.variableDefinitionss[obj.vdIdx]);
			this.accept(this.parser.directivess[obj.dIdx]);
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
		case OperationDefinitionEnum.OT_N_V:
			this.accept(this.parser.operationTypes[obj.otIdx]);
			obj.name.visit(this);
			this.accept(this.parser.variableDefinitionss[obj.vdIdx]);
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
		case OperationDefinitionEnum.OT_N_D:
			this.accept(this.parser.operationTypes[obj.otIdx]);
			obj.name.visit(this);
			this.accept(this.parser.directivess[obj.dIdx]);
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
		case OperationDefinitionEnum.OT_N:
			this.accept(this.parser.operationTypes[obj.otIdx]);
			obj.name.visit(this);
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
		case OperationDefinitionEnum.OT_VD:
			this.accept(this.parser.operationTypes[obj.otIdx]);
			this.accept(this.parser.variableDefinitionss[obj.vdIdx]);
			this.accept(this.parser.directivess[obj.dIdx]);
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
		case OperationDefinitionEnum.OT_V:
			this.accept(this.parser.operationTypes[obj.otIdx]);
			this.accept(this.parser.variableDefinitionss[obj.vdIdx]);
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
		case OperationDefinitionEnum.OT_D:
			this.accept(this.parser.operationTypes[obj.otIdx]);
			this.accept(this.parser.directivess[obj.dIdx]);
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
		case OperationDefinitionEnum.OT:
			this.accept(this.parser.operationTypes[obj.otIdx]);
			this.accept(this.parser.selectionSets[obj.ssIdx]);
			break;
	}
	exit(obj);
}

OperationDefinition:
    SelSet: [SelectionSet#ss]
    OT_N_VD: [OperationType#ot, name#name, VariableDefinitions#vd, Directives#d, SelectionSet#ss]
    OT_N_V: [OperationType#ot, name#name, VariableDefinitions#vd, SelectionSet#ss]
    OT_N_D: [OperationType#ot, name#name, Directives#d, SelectionSet#ss]
    OT_N: [OperationType#ot, name#name, SelectionSet#ss]
    OT_VD: [OperationType#ot, VariableDefinitions#vd, Directives#d, SelectionSet#ss]
    OT_V: [OperationType#ot, VariableDefinitions#vd, SelectionSet#ss]
    OT_D: [OperationType#ot, Directives#d, SelectionSet#ss]
    OT: [OperationType#ot, SelectionSet#ss]

struct OperationDefinitionEnumFirst {
	OperationDefinitionEnum ruleSelection : 4;
	uint vdIdx : 28;
}

struct OperationDefinition {
	OperationDefinitionEnumFirst vdIdx;
	uint otIdx;
	uint dIdx;
	uint ssIdx;
	uint name; // Token should also just a be an index
}

mutation MutateCreatePerson($legalName: LegalNameIn!
		, $knownAsName: KnownAsNameIn!
		, $privateContact: PrivateContactIn!
		, $activeAfter: DateTime
		, $includedInHeadcount: Boolean!) {
	createPerson(legalName: $legalName
			, knownAsName: $knownAsName
			, privateContact: $privateContact
			, activeAfter: $activeAfter
			, includedInHeadcount: $includedInHeadcount) {
		id
	}
}

struct Parser {
	void toDisk(ref File file) {
		static foreach(mem; __traits(allMembers, Parser)) {{
			alias T = typeof(__traits(getMember, Parser, mem));
			static if(isArray!(T)) {
				file.write(cast(uint)__traits(getMember, this, mem).length);
				file.rawWrite(__traits(getMember, this, mem));
			}
		}}
	}

	void fromDisk(ref File file) {
		static foreach(mem; __traits(allMembers, Parser)) {{
			alias T = typeof(__traits(getMember, Parser, mem));
			static if(isArray!(T)) {
				ubyte[4] lenA;
				file.rawRead(lenA[]);
				uint len = cast(uint)(*(cast(uint*)lenA.ptr));
				T[] arr = new T[len];
				file.rawRead(arr);
				__traits(getMember, this, mem) = arr;
			}
		}}
	}
}
