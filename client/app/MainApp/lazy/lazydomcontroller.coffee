class LazyDomController extends KDController

  fetchCurrentGroup = (callback)->
    {groupEntryPoint} = KD.config
    KD.remote.api.JGroup.one slug: groupEntryPoint, (err, group)=>
      error err if err
      if err then new KDNotificationView
        title : "An error occured, please try again"
      else unless group?
        new KDNotificationView title : "No such group!"
      else callback group

  constructor:->
    super

    @groupViewsAdded   = no
    @profileViewsAdded = no

    @mainController = @getSingleton 'mainController'

    @mainController.on 'AppIsReady', =>
      if @userEnteredFromGroup()
        @addGroupViews()
      else if @userEnteredFromProfile()
        @addProfileViews()

      landingPageSideBar = new LandingPageSideBar

      landingPageSideBar.on "navItemIsClicked", @bound "handleNavigationItemClick"

  hideLandingPage:->

    if @landingView
      @utils.defer =>
        @landingView.setClass "down"
        @utils.wait 300, =>
          @landingView.setClass "out"
          @utils.wait 1200, @landingView.bound "hide"
      # FIXME: GG
      # @landingView.on "transtionEnd", @landingView.bound "hide"

  showLandingPage:(callback = noop)->

    if @landingView
      {contentPanel} = @mainController.mainViewController.getView()
      contentPanel.setClass "no-anim"
      contentPanel.setClass "social"
      @utils.defer =>
        contentPanel.unsetClass "no-anim"
        @landingView.show()
        @utils.defer =>
          @landingView.unsetClass "out"
          @utils.wait 600, =>
            @landingView.unsetClass "down"
            @utils.wait 300, callback

  userEnteredFromGroup:-> KD.config.groupEntryPoint?

  userEnteredFromProfile:-> KD.config.profileEntryPoint?

  addGroupViews:->

    return if @groupViewsAdded
    @groupViewsAdded        = yes
    staticGroupController   = new StaticGroupController
    {@landingView}          = staticGroupController

  addProfileViews:->

    return if @profileViewsAdded
    @profileViewsAdded      = yes
    staticProfileController = new StaticProfileController
    {@landingView}          = staticProfileController

  openPath:(path)->
    @getSingleton('router').handleRoute path
    @hideLandingPage() unless path is '/Logout'

  handleNavigationItemClick:(item, event)->

    mc = @getSingleton 'mainController'
    {action, appPath, title, path, type} = item.getData()
    {loginScreen, mainViewController}    = mc
    {groupEntryPoint, profileEntryPoint} = KD.config

    return @openPath(path) if path

    switch action
      when 'login'
        loginScreen.animateToForm 'login'
      when 'register'
        loginScreen.animateToForm 'register'
      when 'request' then @requestAccess()
      when 'join-group'
        fetchCurrentGroup (group)=>
          group.join (err, response)=>
            error err if err
            if err then new KDNotificationView
              title : "An error occured, please try again"
            else
              new KDNotificationView
                title : "You successfully joined to group!"
              @openPath "/#{groupEntryPoint}/Activity"

      when 'logout'
        mainViewController.getView().hide()
        @openPath '/Logout'

      when 'activity'
        @getSingleton('staticProfileController').emit 'ActivityLinkClicked'

      when 'about'
        @getSingleton('staticProfileController').emit 'AboutLinkClicked'

      when 'topics','members','groups','apps'
        new KDNotificationView
          title : 'This feature is currently disabled'
      when 'home'
        @getSingleton('staticProfileController').emit 'HomeLinkClicked'

  requestAccess:->

    if KD.isLoggedIn()
      fetchCurrentGroup (group)=>
        @getSingleton('groupsController').openPrivateGroup group
    else
      @getSingleton('mainController').loginScreen.animateToForm 'lr'
