{Model} = require 'bongo'

module.exports = class JInvitationRequest extends Model

  @trait __dirname, '../traits/grouprelated'

  {ObjectRef, daisy, secure}   = require 'bongo'

  {permit} = require './group/permissionset'

  KodingError = require '../error'

  #csvParser = require 'csv'

  @share()

  @set
    indexes           :
      #email           : ['unique','sparse']
      email           : 'sparse'
      status          : 'sparse'
    sharedMethods     :
      static          : ['create'] #,'__importKodingenUsers']
      instance        : [
        'sendInvitation'
        'deleteInvitation'
        'approveInvitation'
        'declineInvitation'
        'acceptInvitationByInvitee'
        'ignoreInvitationByInvitee'
      ]
    schema            :
      email           :
        type          : String
        email         : yes
        required      : no
      koding          :
        username      : String
      kodingen        :
        isMember      : Boolean
        username      : String
        registeredAt  : Date
      requestedAt     :
        type          : Date
        default       : -> new Date
      group           : String
      status          :
        type          : String
        enum          : ['Invalid status', [
          'pending'
          'sent'
          'declined'
          'approved'
          'ignored'
          'accepted'
        ]]
        default       : 'pending'
      invitationType  :
        type          : String
        enum          : ['invalid invitation type',[
          'invitation'
          'basic approval'
        ]]
        default       : 'invitation'

  @resolvedStatuses = [
    'declined'
    'approved'
    'ignored'
    'accepted'
  ]

  @create =({email}, callback)->
    invite = new @ {email}
    invite.save (err)->
      if err
        callback err
      else
        callback null, email

  @__importKodingenUsers =do->
    pathToKodingenCSV = 'kodingen/wp_users.csv'
    (callback)->
      queue = []
      errors = []
      eterations = 0
      csv = csvParser().fromPath pathToKodingenCSV, escape: '\\'
      csv.on 'data', (datum)->
        if datum[0] isnt 'ID'
          deleted = datum.pop()+''
          spam    = datum.pop()+''
          if '1' in [deleted, spam]
            reason = {deleted, spam}
            csv.emit 'error', "this datum is invalid because #{JSON.stringify reason}"
          else
            queue.push ->
              [__id, username, __hashedPassword, __nicename, email, __url, registeredAt] = datum
              inviteRequest = new JInvitationRequest {
                email
                kodingen    : {
                  isMember  : yes
                  username
                  registeredAt: Date.parse registeredAt
                }
              }
              inviteRequest.save queue.next.bind queue
      csv.on 'end', (count)->
        callback "Finished parsing #{count} records, of which #{queue.length} were valid."
        daisy queue
      csv.on 'error', (err)-> errors.push err

  declineInvitation: permit 'send invitations',
    success: (client, callback=->)->
      @update $set:{ status: 'declined' }, callback

  fetchAccount:(callback)->
    JAccount = require './account'
    if @koding?.username
      JAccount.one {'profile.nickname': @koding.username}, callback
    else if @email
      JUser = require './user'
      JUser.one email:@email, (err, user)->
        if err then callback err
        else JAccount.one {'profile.nickname':user.username}, callback
    else
      callback new KodingError """
        Unimplemented: we can't fetch an account from this type of invitation
        """

  approveInvitation: permit 'send invitations',
    success: (client, callback=->)->
      JGroup = require './group'
      JGroup.one { slug: @group }, (err, group)=>
        if err then callback err
        else unless group?
          callback new KodingError "No group! #{@group}"
        else
          @fetchAccount (err, account)=>
            return callback err if err
            group.approveMember account, (err)=>
              return callback err if err
              @update $set:{ status: 'approved' }, (err)=>
                return callback err if err
                @sendRequestApprovedNotification client, group, account, callback

  fetchDataForAcceptOrIgnore: (client, callback)->
    {delegate} = client.connection
    JGroup = require './group'
    JGroup.one slug:@group, (err, group)=>
      if err then callback err
      else unless group?
        callback new KodingError "No group! #{@group}"
      else @fetchAccount (err, account)=>
        if err then callback err
        else if not account
          callback new KodingError "Account ID does not equal caller's ID"
        else if not account._id.equals delegate.getId()
          callback new KodingError "Account ID does not equal caller's ID"
        else callback null, account, group

  acceptInvitationByInvitee: secure (client, callback)->
    @fetchDataForAcceptOrIgnore client, (err, account, group)=>
      if err then callback err
      else
        group.approveMember account, (err)=>
          if err then callback err
          else @update $set:{status:'accepted'}, (err)->
            if err then callback err
            else callback null

  ignoreInvitationByInvitee: secure (client, callback)->
    @fetchDataForAcceptOrIgnore client, (err, account, group)=>
      if err then callback err
      else
        @update $set:{status:'ignored'}, (err)->
          if err then callback err
          else callback null

  deleteInvitation: permit 'send invitations',
    success:(client, rest...)-> @remove rest...

  sendInvitation:(client, callback=->)->
    JUser       = require './user'
    JGroup      = require './group'
    JInvitation = require './invitation'

    JGroup.one slug: @group, (err, group)=>
      if err then callback err
      else unless group?
        callback new KodingError "No group! #{@group}"
      else
        JUser.one email: @email, (err, user)=>
          if err then callback err
          else if not user
            # send invite to non koding user
            JInvitation.createViaGroup client, group, [@email], callback
          else
            @update $set:{'koding.username':user.username}, (err)=>
              if err then callback err
              else
                # send invite to existing koding user
                @sendInviteMailToKodingUser client, user, group, callback

  sendInvitation$: permit 'send invitations',
    success: (client, callback)-> @sendInvitation client, callback

  sendInviteMailToKodingUser:(client, user, group, callback)->
    JAccount          = require './account'
    JMailNotification = require './emailnotification'

    JAccount.one 'profile.nickname': user.username, (err, receiver)=>
      if err then callback err
      else
        {delegate} = client.connection
        JAccount.one _id: delegate.getId(), (err, actor)=>
          if err then callback err
          else
            data =
              actor        : actor
              receiver     : receiver
              event        : 'Invited'
              contents     :
                subject    : ObjectRef(group).data
                actionType : 'invite'
                actorType  : 'admin'
                invite     : ObjectRef(@).data
                admin      : ObjectRef(client).data

            JMailNotification.create data, (err)->
              if err then callback new KodingError "Could not send"
              else
                callback null

  sendRequestNotification:(client, callback)->
    JUser             = require './user'
    JAccount          = require './account'
    JGroup            = require './group'
    JMailNotification = require './emailnotification'

    JGroup.one slug: @group, (err, group)=>
      if err then callback err
      else unless group?
        callback new KodingError "No group! #{@group}"
      else
        {delegate} = client.connection
        JAccount.one _id: delegate.getId(), (err, actor)=>
          if err then callback err
          else
            group.fetchAdmins (err, accounts)=>
              if err then callback err

              for account in accounts when account
                data =
                  actor             : actor
                  receiver          : account
                  event             : 'ApprovalRequested'
                  contents          :
                    subject         : ObjectRef(group).data
                    actionType      : 'approvalRequest'
                    actorType       : 'requester'
                    approvalRequest : ObjectRef(@).data
                    requester       : ObjectRef(actor).data

                JMailNotification.create data, (err)->
                  if err then callback new KodingError "Could not send"
                  else
                    callback null

  sendRequestApprovedNotification:(client, group, account, callback)->
    JAccount          = require './account'
    JMailNotification = require './emailnotification'

    {delegate} = client.connection
    JAccount.one _id: delegate.getId(), (err, actor)=>
      if err then callback err
      else
        data =
          actor             : actor
          receiver          : account
          event             : 'Approved'
          contents          :
            subject         : ObjectRef(group).data
            actionType      : 'approved'
            actorType       : 'requester'
            approved        : ObjectRef(@).data
            requester       : ObjectRef(actor).data

        JMailNotification.create data, (err)->
          if err then callback new KodingError "Could not send"
          else
            callback null
