class CollaborativeTabbedEditorPane extends CollaborativePane

  constructor: (options = {}, data) ->

    super options, data

    log "i am a CollaborativeTabbedEditorPane"

    @panel            = @getDelegate()
    @workspace        = @panel.getDelegate()
    @sessionKey       = @getOptions().sessionKey or @createSessionKey()
    @workspaceRef     = @workspace.firepadRef.child @sessionKey
    @isJoinedASession = @getOptions().sessionKey
    @openedFiles      = []

    log "joined an old session again, creating new tabbed editor"

    @createEditorTabs()
    return @createEditorInstance()  unless @isJoinedASession
    @recoverOldSessionTabs()

  createEditorTabs: ->
    @tabHandleContainer = new ApplicationTabHandleHolder
      delegate      : @
      addPlusHandle : no

    @tabView = new ApplicationTabView
      delegate           : @
      tabHandleContainer : @tabHandleContainer

  createEditorInstance: (file, content, sessionKey) ->
    if file
      fileIndexInOpenedFiles = @openedFiles.indexOf(file.path)
      if fileIndexInOpenedFiles > -1
        log "same file detected, setting tab acive"
        return  @tabView.showPaneByIndex fileIndexInOpenedFiles + 1

    pane   = new KDTabPaneView
      name : file?.name or "untitled.js"

    editor = new CollaborativeEditorPane {
      delegate : @getDelegate()
      sessionKey
      file
      content
    }

    pane.addSubView editor
    @tabView.addPane pane

    pane.on "KDTabPaneDestroy", =>
      @workspaceRef.once "value", (snapshot) =>
        {tabs} = snapshot.val()
        return unless tabs
        delete tabs[key] for key, value of tabs when value.sessionKey is editor.sessionKey
        @workspaceRef.set "tabs": tabs

      @openedFiles.splice @openedFiles.indexOf(file.path), 1

    workspaceRefData =
      sessionKey : editor.sessionKey

    if file
      workspaceRefData.path = file.path
      @openedFiles.push file.path

    @workspaceRef.child("tabs").push workspaceRefData

    return yes # return something instead of workspaceRef.child

  recoverOldSessionTabs: ->
    @workspaceRef.once "value", (snapshot) =>
      tabs = snapshot.val() and snapshot.val().tabs # not same with {tabs} = snapshot.val()?
      return unless tabs
      for key, value of tabs
        file = FSHelper.createFileFromPath value.path
        @createEditorInstance file, null, value.sessionKey

  openFile: CollaborativeTabbedEditorPane::createEditorInstance

  pistachio: ->
    return """
      {{> @tabHandleContainer}}
      {{> @tabView}}
    """