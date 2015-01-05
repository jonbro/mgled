$(function(){
	var thisObj = {};
	var _editorDirty = false;
	var _editorCleanState = "";
	var editor = CodeMirror.fromTextArea(document.getElementById("code"), {
		lineNumbers: true,
		tabSize: 2,
		mode: {name: "coffeescript"}
	});
	thisObj.editor = editor;
	var setEditorClean = function() {
		_editorCleanState = editor.doc.getValue();
		if (_editorDirty===true) {
			$("#saveClickLink").html('SAVE');
			_editorDirty = false;
		}
	}
	var currentGame = "";
	var currentSaveArray;
    function getParameterByName(name) {
        name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
        var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"),
            results = regex.exec(location.search);
        return results == null ? "" : decodeURIComponent(results[1].replace(/\+/g, " "));
    }
	var loadFromGist = function(id){
        $.ajax('https://api.github.com/gists/'+id, {
            type: 'GET',
            context: thisObj
        }).done(function(data){
        	this.editor.setValue(data.files['script.coffee'].content);
        });
	}

	// attempt to load game from the url parameter
	var gistToLoad=getParameterByName("hack");
	if (gistToLoad!==null&&gistToLoad.length>0) {
		var id = gistToLoad.replace(/[\\\/]/,"");
		loadFromGist(id);
		this.editor = editor;
		editor.doc.setValue("loading...");
	} else {
		try {
			// attempt to load the game from local storage
			if(localStorage!==undefined && localStorage["games"] !==undefined){
				currentSaveArray = JSON.parse(localStorage["games"]);
				if(currentSaveArray.length > 0){
					editor.setValue(currentSaveArray[currentSaveArray.length-1].code);
					setEditorClean();
				}
			}
		} catch(ex) {
			
		}
	}
	// should still populate the array with your games that you have made
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
			var playUrl = 'http://jonbro.tk/mlged/play.html?p='+data.id;
			$("#consoletextarea").append('<div>play at <a href="'+playUrl+'">'+playUrl+'</a></div>');
		});
	}
	function dateToReadable(title,time) {
		var year = time.getFullYear();
		var month = time.getMonth()+1;
		var date1 = time.getDate();
		var hour = time.getHours();
		var minutes = time.getMinutes();
		var seconds = time.getSeconds();

		if (month < 10) {
	    	month = "0"+month;
		}
		if (date1 < 10) {
			date1 = "0"+date1;
		}
		if (hour < 10) {
			hour = "0"+hour;
		}
		if (minutes < 10) {
			minutes = "0"+minutes;
		}
		if (seconds < 10) {
			seconds = "0"+seconds;
		}

		var result = hour+":"+minutes+" "+year + "-" + month+"-"+date1+" "+title;
		return result;
	}
	$('#loadDropDown').change(function(eventData){
		var val = $( this ).val();
		for (var i = currentSaveArray.length - 1; i >= 0; i--) {
			var save = currentSaveArray[i];
			var key = dateToReadable(save.title, new Date(save.date));
			if(val == key){
				editor.doc.setValue(save.code);
				setEditorClean();
			}
		}
	});
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
		loadDropDown.empty();
		for (var i = currentSaveArray.length - 1; i >= 0; i--) {
			var save = currentSaveArray[i];
			var optionText = '<option class="loadOption">'+dateToReadable(save.title, new Date(save.date))+'</option>';
			var thisOption = $(optionText);
			thisOption.value = dateToReadable(save.title, new Date(save.date));
			loadDropDown.append(thisOption);
		};
	}
	populateSaveDropdown();
	var saveToStorage = function(){
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
		if (currentSaveArray.length>19) {
			currentSaveArray.splice(0,1);
		}
		currentSaveArray.push(currentGame);
		// only allow 20 things in this list

		localStorage["games"] = JSON.stringify(currentSaveArray);
		populateSaveDropdown();
		setEditorClean();
	}
	var checkEditorDirty = function(){
		console.log(_editorCleanState);
		if (_editorCleanState !== editor.doc.getValue()) {
			$("#saveClickLink").html('SAVE*');
			_editorDirty = true;
		} else {
			$("#saveClickLink").html('SAVE');
			_editorDirty = false;
		}
	}
	editor.on('change', function(){
		checkEditorDirty();
	});
	$("#saveClickLink").click(function(){
		// need to eval to insert stuff into the global namespace, so we can get the name out
		CoffeeScript.eval(editor.doc.getValue(), {sandbox:true, sourceMap:true, filename:"none"});
		saveToStorage();
	});
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
				saveToStorage();
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