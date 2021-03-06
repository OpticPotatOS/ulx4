[=[
Class: Lang
A class used for dealing with translated messages.
]=]
class ulx.Lang
	@StaticLanguage: nil
	@Mutators: {}

	CurrentLanguage: nil
	BackupLanguage: nil
	Phrases: {}

	parseAndVerifyLangTxt = (txt using nil) ->
		phrases = util.JSONToTable txt
		if not phrases
			return false, "Unable to parse JSON"

		types = tableshape.types
		dictionary = types.map_of types.string, types.string
		valid, err = dictionary\check_value phrases

		if not valid
			return false, err

		return phrases

	loadPhrasesForLang = (lang using nil) ->
		langFiles = ulx.Directory.GetFiles("locale", lang .. ".json", true)
		phraseAccum = {}

		if #langFiles == 0
			return false, "Language files do not exist"

		for langFile in *langFiles
			txt = ulx.File.ReadAllText langFile
			phrases, err = parseAndVerifyLangTxt txt
			if not phrases
				print err
				--log.warn "invalid..." -- TODO
				continue
			ulx.TableX.UnionByKey phraseAccum, phrases, true
		return phraseAccum

	init = ->
		lang = ulx.CoreConfig.Language
		@@StaticLanguage = ulx.Lang lang
		return
	ulx.RegisterInitCallback init

	[=[
	Function: AddMutator
	TODO
	]=]
	@AddMutator: (name, func using nil) ->
		@Mutators[name] = func

	@GetPhrase: (phraseName using nil) ->
		@StaticLanguage\GetPhrase phraseName

	@GetMutatedPhrase: (phraseName, data using nil) ->
		@StaticLanguage\GetMutatedPhrase phraseName, data

	new: (language, backupLanguage using nil) =>
		@SetLanguage language, backupLanguage

	[=[
	Function: SetLanguage
	TODO
	]=]
	SetLanguage: (language, backupLanguage="english" using nil) =>
		ulx.UtilX.CheckArg "Language.SetLanguage", 1, "string", language
		ulx.UtilX.CheckArg "Language.SetLanguage", 2, "string", backupLanguage

		@CurrentLanguage = language\lower!
		@BackupLanguage = backupLanguage\lower!

		primaryPhrases, errPrimary = loadPhrasesForLang @CurrentLanguage

		if @BackupLanguage ~= @CurrentLanguage
			secondaryPhrases, errSecondary = loadPhrasesForLang @BackupLanguage
			if secondaryPhrases
				primaryPhrases = ulx.TableX.UnionByKey secondaryPhrases, primaryPhrases or {}, true

		if not primaryPhrases
			return false, errPrimary

		@Phrases = primaryPhrases
		return true

	[=[
	Function: GetPhrase
	TODO
	]=]
	GetPhrase: (phraseName using nil) =>
		@Phrases[phraseName]

	[=[
	Function: GetMutatedPhrase
	TODO
	]=]
	GetMutatedPhrase: (phraseName, data using nil) =>
		phrase = @GetPhrase phraseName
		if not phrase
			return nil

		mutatedPhrase = phrase\gsub "{.-}", (placeholder using nil) ->
			@processPlaceholder(placeholder, data)
		ulx.UtilX.Trim mutatedPhrase

	-- Receives everything between and including the brackets "{DAMAGE|NonZero:for %i damage}"
	processPlaceholder: (placeholder, data using nil) =>
		curPos = placeholder\find("|", 3, true) or #placeholder -- next pipe or the end bracket
		placeholderName = placeholder\sub(2, curPos-1)

		mutatorFnsAndArgs = {}
		while placeholder\sub(curPos, curPos) == "|"
			nextPos = placeholder\find("|", curPos+2, true) or #placeholder -- next pipe or the end bracket
			functionBlock = placeholder\sub(curPos+1, nextPos-1)
			fn, args = @getFnAndArgs functionBlock, mutated
			table.insert mutatorFnsAndArgs, {fn, args}
			curPos = nextPos

		replacement = data[placeholderName]
		mutated = @pipeMutators replacement, mutatorFnsAndArgs
		if type(mutated) == "table"
			mutated = @listPipeMutators replacement, mutatorFnsAndArgs

		return mutated

	-- Receives a mutator function and all its arguments "NonZero:for %i damage"
	getFnAndArgs: (functionBlock, txt) =>
		curPos = functionBlock\find(":", 2, true) or #functionBlock+1 -- next colon of end of string
		functionName = functionBlock\sub(1, curPos-1)
		args = {}

		while functionBlock\sub(curPos, curPos) == ":"
			nextPos = functionBlock\find(":", curPos+1, true) or #functionBlock+1 -- next colon of end of string
			arg = functionBlock\sub(curPos+1, nextPos-1)
			table.insert args, arg
			curPos = nextPos

		return @@Mutators[functionName], args

	-- Make a string from a list while piping each item
	listPipeMutators: (list, ... using nil) =>
		str = ""
		for i=1, #list-2
			str ..= @pipeMutators(list[i], ...) .. ", "

		if #list > 1
			mutated = @pipeMutators(list[#list-1], ...)
			conjuction = " " .. @GetPhrase("AND") .. " "
			str ..= mutated .. conjuction

		str ..= @pipeMutators(list[#list], ...)
		return str

	-- Send a string through each mutator function with the specified arguments
	pipeMutators: (replacement, mutatorFnsAndArgs using nil) =>
		for mutatorFnAndArgs in *mutatorFnsAndArgs
			fn = mutatorFnAndArgs[1]
			args = mutatorFnAndArgs[2]
			replacement = fn(replacement, unpack(args))
		return replacement
