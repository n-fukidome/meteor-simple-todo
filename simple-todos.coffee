if Meteor.isServer
  # This code only runs on the server
  # Only publish tasks that are public or belong to the current user
  Meteor.publish 'tasks', ->
    Tasks.find $or: [
      { private: $ne: true }
      { owner: @userId }
      { date: @date}
    ]


if Meteor.isClient
  # This code only runs on the client
  Meteor.subscribe 'tasks'

  Template.body.helpers
    tasks: ->
      query = {}
      if Session.get('onlyMine')
        query["owner"] = Meteor.userId()
      if Session.get('hideCompleted')
        query["checked"] = { $ne: true }
      Tasks.find(query, sort: createdAt: -1)

    hideCompleted: ->
      Session.get 'hideCompleted'
    onlyMine: ->
      Session.get 'onlyMine'
    incompleteCount: ->
      Tasks.find(checked: $ne: true).count()

  Template.body.events
    'submit .new-task': (event) ->
      event.preventDefault()
      text = event.target.text.value
      Meteor.call 'addTask', text
      event.target.text.value = ''
    'change .hide-completed input': (event) ->
      Session.set 'hideCompleted', event.target.checked
      return
    'change .only-mine input': (event) ->
      Session.set 'onlyMine', event.target.checked
      return

  Template.task.helpers
    isOwner: ->
      @owner == Meteor.userId()

  Template.task.events
    'click .toggle-checked': ->
      # Set the checked property to the opposite of its current value
      Meteor.call 'setChecked', @_id, !@checked
      # Tasks.update(this._id, {
      #   $set: {checked: ! this.checked}
      # });
      return
    'click .delete': ->
      Meteor.call 'deleteTask', @_id
      # Tasks.remove(this._id);
      return
    'click .copy': ->
      task = Tasks.findOne(@_id)
      ret = confirm("Do you copy this task(#{task?.text})?")
      return unless ret
      Meteor.call 'copyTask', task

  Template.OwnerForms.helpers
    showDateForm: ->
      Session.get('showDateForm') == this._id
    showChildForm: ->
      Session.get('showChildForm') == this._id

  Template.OwnerForms.events
    'click .toggle-private': ->
      Meteor.call 'setPrivate', @_id, !@private
    'click .show-date': ->
      unless Session.get('showDateForm')
        Session.set 'showDateForm', this._id
      else
        Session.set 'showDateForm', null
    'click .show-child': ->
      unless Session.get('showChildForm')
        Session.set 'showChildForm', this._id
      else
        Session.set 'showChildForm', null
    'click .set-date': (event) ->
      date = event.target.parentNode.children[1].value
      Meteor.call 'setDate', @_id, date
      Session.set 'showDateForm', null
    'submit .new-child-task': (event) ->
      event.preventDefault()
      text = event.target[0].value
      Meteor.call 'addChildTask', text, this
      Session.set 'showChildForm', null

  Accounts.ui.config passwordSignupFields: 'USERNAME_ONLY'

Meteor.methods
  addTask: (text) ->
    if !Meteor.userId()
      throw new (Meteor.Error)('not-authorized')
    Tasks.insert
      text: text
      createdAt: new Date
      owner: Meteor.userId()
      username: Meteor.user().username

  addChildTask: (text, parent) ->
    # if !Meteor.userId()
    #   throw new (Meteor.Error)('not-authorized')
    Tasks.insert
      text: text
      parentId: parent._id
      private: parent.private
      createdAt: new Date
      owner: Meteor.userId()
      username: Meteor.user().username

  copyTask: (task) ->
    if !Meteor.userId()
      throw new (Meteor.Error)('not-authorized')
    Tasks.insert
      text: task.text
      createdAt: new Date
      owner: Meteor.userId()
      username: Meteor.user().username
      date: task.date
    return

  deleteTask: (taskId) ->
    task = Tasks.findOne(taskId)
    if task.private and task.owner != Meteor.userId()
      # If the task is private, make sure only the owner can delete it
      throw new (Meteor.Error)('not-authorized')
    Tasks.remove taskId
    return

  setChecked: (taskId, setChecked) ->
    task = Tasks.findOne(taskId)
    if task.private and task.owner != Meteor.userId()
      # If the task is private, make sure only the owner can check it off
      throw new (Meteor.Error)('not-authorized')
    Tasks.update taskId, $set: checked: setChecked
    return

  setPrivate: (taskId, setToPrivate) ->
    task = Tasks.findOne(taskId)
    # Make sure only the task owner can make a task private
    if task.owner != Meteor.userId()
      throw new (Meteor.Error)('not-authorized')
    Tasks.update taskId, $set: private: setToPrivate
    return

  setDate: (taskId, date) ->
    task = Tasks.findOne(taskId)
    console.log task, date
    if task.owner != Meteor.userId()
      throw new (Meteor.Error)('not-authorized')
    Tasks.update taskId, $set: date: date
    return
