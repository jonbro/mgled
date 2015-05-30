var postToLeaderboard = function(score){
  // just a stub
}
var EditorConsole = (function(){
  function EditorConsole(){  
  }
  EditorConsole.clear = function(){
    this.setup();
    this.console.html("<div>=========================</div>");
  };
  EditorConsole.append = function(input){
    this.setup();
    return this.console.append(input);
  }
  EditorConsole.setEditorWindow = function(_editor){
    this.editor = _editor;
  }
  EditorConsole.setup = function(){
    if(!this.console)
      this.console = $("#consoletextarea");    
  }
  EditorConsole.appendErrorWithLineLink = function(errorText, line, column){
    this.setup();
    var lineText = "<span class='link'>line "+line+"</span>: ";
    var errorText = "<span class='error'>"+errorText+"</span>";
    var editor = this.editor;
    this.console.append('<div>'+lineText+errorText+'</div>').find('.link').click(function(){
      var i = line;
      editor.scrollIntoView(Math.max(i - 1 - 10, 0));
      editor.scrollIntoView(i - 1);
      editor.focus();
      editor.setCursor(i - 1, column);
    });
  }
  EditorConsole.appendNotice = function(text){
    this.setup();
    this.console.append('<div><span class="notice">'+text+"</span></div>");
  }
  return EditorConsole;
})();
var trace = function(text){
  EditorConsole.appendNotice(text);
}
var ErrorReporter = (function(){
  function ErrorReporter() {}
  ErrorReporter.setSourceMap = function(_sourceMap){
      this.cssourcemap = _sourceMap;
      this.parsedMap = JSON.parse(this.cssourcemap.v3SourceMap);
      this.smc = new sourceMap.SourceMapConsumer(this.parsedMap);
  };
  ErrorReporter.setEditorWindow = function(_editor){
    this.editor = _editor;
  }
  ErrorReporter.handleError = function(e){
      // this fails unless you modify coffee script to something like: sourceURL=file://nothing.js -- because it doesn't handle the coffeescript protocol well
      var stack = stackinfo(e);
      // for some reason everything is off by one. yay!
      var coffeescriptErrorPosition = this.smc.originalPositionFor({
        line: stack[0].line+1,
        column: stack[0].column+1
      });
      console.log(e);
      console.log(coffeescriptErrorPosition);
      var editor = this.editor;
      EditorConsole.clear();
      EditorConsole.appendErrorWithLineLink(e.message, coffeescriptErrorPosition.line, coffeescriptErrorPosition.column);
  }
  return ErrorReporter;
})();
$(function(){
  var thisObj = {};
  var _editorDirty = false;
  var _editorCleanState = "";
  function betterTab(cm) {
    if (cm.somethingSelected()) {
    cm.indentSelection("add");
    } else {
    cm.replaceSelection(cm.getOption("indentWithTabs")? "\t":
      Array(cm.getOption("indentUnit") + 1).join(" "), "end", "+input");
    }
  }

  var editor = CodeMirror.fromTextArea(document.getElementById("code"), {
    extraKeys: { Tab: betterTab, "Ctrl-Space": "autocomplete"},
    lineNumbers: true,
    tabSize: 2,
    mode: {name: "coffeescript"},
    theme: 'solarized dark'
  });
  ErrorReporter.setEditorWindow(editor);
  EditorConsole.setEditorWindow(editor);
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
      setEditorClean();
    });
  }
  $(window).bind('beforeunload', function (e) {
    console.log("should be checking for unload");
    var e = e || window.event;
    var msg = 'You have unsaved changes!';
    if(_editorDirty) {      
      // For IE and Firefox prior to version 4
      if (e) {
        e.returnValue = msg;
      }
      // For Safari
      return msg;
    }
  });

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
      contentType: 'application/json',
      data: JSON.stringify(gistToCreate)
    }).done(function(data){
      var playUrl = 'http://mgled.neocities.org/play.html?p='+data.id;
      EditorConsole.appendNotice('play at <a href="'+playUrl+'">'+playUrl+'</a>');
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
    loadDropDown.append('<option class="loadOption">Load</option>');
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
    EditorConsole.appendNotice("saved game to local storage");
    localStorage["games"] = JSON.stringify(currentSaveArray);
    populateSaveDropdown();
    setEditorClean();
  }
  var checkEditorDirty = function(){
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
  editor.on('keyup', function(e, s){
    // CodeMirror.commands.autocomplete(e);

    // CodeMirror.hint.coffeescript(e);
  });
  $("#saveClickLink").click(function(){
    // need to eval to insert stuff into the global namespace, so we can get the name out
    var cssourcemap = CoffeeScript.compile(editor.doc.getValue(), {sandbox:true, sourceMap:true, filename:"none"});
    // would be nice to not compile everything twice, and I am not really sure how much the sandbox is getting me (if anything)
    ErrorReporter.setSourceMap(cssourcemap);
    try{
      CoffeeScript.eval(editor.doc.getValue(), {sandbox:true, sourceMap:true, filename:"none"});
    }catch(e){
      ErrorReporter.handleError(e);
    }
    saveToStorage();
  });
  $("#shareClickLink").click(function(){
    saveToGist();
  });
  $("#runClickLink").click(function(){
    // take the code in the editor window and run it through coffeescript, then run the game
    try{
      EditorConsole.clear();
      var cssourcemap = CoffeeScript.compile(editor.doc.getValue(), {sandbox:true, sourceMap:true, filename:"none"});
      // would be nice to not compile everything twice, and I am not really sure how much the sandbox is getting me (if anything)
      ErrorReporter.setSourceMap(cssourcemap);
      console.log(cssourcemap);
      CoffeeScript.eval(editor.doc.getValue(), {sandbox:true, sourceMap:true, filename:"none"});
      try{
        // shouldn't have hit errors, so run the game
        EditorConsole.appendNotice('running game');
        Game.initialize();
        if(window && window.initialize)
          window.initialize();
        resize_all();
      }catch(e){
        console.log('handling error I think?');
        console.log(e);
        ErrorReporter.handleError(e);
      }
    }catch(e){
      // dump errors with links to the correct line out to the console
      ErrorReporter.handleError(e);
    }
  });
});