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
