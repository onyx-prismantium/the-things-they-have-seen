class_name MockProvider
extends NluProvider

## Answers by exact normalized-string lookup against the object's authored sample_qa
## table. Unknown questions -> huh|none. Lets the whole game be played end-to-end
## with --mock-nlu and no model file present; CI runs mock-only.

func answer(object_def: ObjectDef, normalized_question: String) -> String:
	for qa: SampleQADef in object_def.sample_qa:
		if PromptBuilder.normalize(qa.q) == normalized_question:
			if qa.a == "yes" or qa.a == "no":
				return "%s|%s" % [qa.a, qa.fact]
			return "huh|none"
	return "huh|none"

func is_ready() -> bool:
	return true
