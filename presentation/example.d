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

		return new Definition(DefinitionEnum.O
			, op
		);
	} else if(this.firstFragmentDefinition()) {
		FragmentDefinition frag = this.parseFragmentDefinition();

		return new Definition(DefinitionEnum.F
			, frag
		);
	} else if(this.firstTypeSystemDefinition()) {
		TypeSystemDefinition type = this.parseTypeSystemDefinition();

		return new Definition(DefinitionEnum.T
			, type
		);
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

class Visitor : ConstVisitor {
@safe :
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
