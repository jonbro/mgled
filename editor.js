$(function(){
	var editor = CodeMirror.fromTextArea(document.getElementById("code"), {
		lineNumbers: true,
		tabSize: 2,
		mode: {name: "coffeescript"}
	});
	var currentGame = "";
	var currentSaveArray;
	// attempt to load the game from local storage
	if(localStorage["games"]){
		currentSaveArray = JSON.parse(localStorage["games"]);
		if(currentSaveArray.length > 0)
			editor.setValue(currentSaveArray[currentSaveArray.length-1].code);
	}
	var saveToGist = function(){
		// should check to make sure game compiles fine before doing this
		var gistToCreate = {
			"description" : "title",
			"public" : true,
			"files": {
				"readme.txt" : {
					"content": "Play this game by pasting the script in http://www.???.com/editor.html"
				},
				"script.coffee" : {
					"content": editor.doc.getValue()
				}
			}
		};
		$.ajax('https://api.github.com/gists', {
			type: 'POST',
			data: JSON.stringify(gistToCreate)

		}).done(function(data){
			console.log(data);
		});
	}
	// load in all the prior saved games into the dropdown menu
	// for running the game
	var populateSaveDropdown = function(){
		if (currentSaveArray===undefined) {
			try {
				if (localStorage['games']===undefined) {
					return;
				} else {
						currentSaveArray = JSON.parse(localStorage["games"]);
				}
			} catch (ex) {
				return;
			}
		}
		var loadDropDown = $('#loadDropDown');
		$.each(currentSaveArray, function(i, save){
			console.log(save);
			loadDropDown.append('<option>'+save.title+'</option>');
		});
	}
	$("#shareClickLink").click(function(){
		saveToGist();
	});
	$("#runClickLink").click(function(){
		// take the code in the editor window and run it through coffeescript, then run the game
		try{
			var cssourcemap = CoffeeScript.compile(editor.doc.getValue(), {sandbox:true, sourceMap:true, filename:"none"});
			// would be nice to not compile everything twice, and I am not really sure how much the sandbox is getting me (if anything)
			CoffeeScript.eval(editor.doc.getValue(), {sandbox:true, sourceMap:true, filename:"none"});
			try{
				// store the current game into local storage
				var title = "";
				title = Config.title.join(" ");
				if(title == "" || title == 'MGL.COFFEE'){
					title = 'unnamed';
				}
				var currentGame = {
					title:title,
					code: editor.doc.getValue(),
					date: new Date()
				};
				if(!currentSaveArray){
					currentSaveArray = [];
				}
				currentSaveArray.push(currentGame);
				localStorage["games"] = JSON.stringify(currentSaveArray);
				populateSaveDropdown();
				// shouldn't have hit errors, so run the game
				return Game.initialize();
			}catch(e){
		        var parsedMap = JSON.parse(cssourcemap.v3SourceMap);
		        var smc = new sourceMap.SourceMapConsumer(parsedMap);
		        // this fails unless you modify coffee script to something like: sourceURL=file://nothing.js -- because it doesn't handle the coffeescript protocol well
		        var stack = stackinfo(e);

		        // for some reason everything is off by one. yay!
				var coffeescriptErrorPosition = smc.originalPositionFor({
					line: stack[0].line+1,
					column: stack[0].column+1
				});
				// console.log(err);
				$("#consoletextarea").append('<div>error: '+e.message+' at line: ' + coffeescriptErrorPosition.line +'</div>').click(function(){
					var i = coffeescriptErrorPosition.line;
				    editor.scrollIntoView(Math.max(i - 1 - 10, 0));
				    editor.scrollIntoView(i - 1);
				    editor.focus();
				    editor.setCursor(i - 1, coffeescriptErrorPosition.column);
				});
			}
		}catch(err){
			// dump errors with links to the correct line out to the console
			$("#consoletextarea").append('<div>error: '+err.message+'</div>'); // I don't know if this is working right, or why it is working :/ disconcerting!
		}
	});
});