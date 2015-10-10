Tasks = new (Mongo.Collection)('tasks')

if Meteor.isServer
  # This code only runs on the server
  # Only publish tasks that are public or belong to the current user
  Meteor.publish 'tasks', ->
    Tasks.find $or: [
      { private: $ne: true }
      { owner: @userId }
    ]

if Meteor.isClient
  # This code only runs on the client
  Meteor.subscribe 'tasks'

  Template.body.helpers
    tasks: ->
      if Session.get('hideCompleted')
        # If hide completed is checked, filter tasks
        Tasks.find { checked: $ne: true }, sort: createdAt: -1
      else
        # Otherwise, return all of the tasks
        Tasks.find {}, sort: createdAt: -1
    hideCompleted: ->
      Session.get 'hideCompleted'
    incompleteCount: ->
      Tasks.find(checked: $ne: true).count()

  Template.body.events
    'submit .new-task': (event) ->
      # Prevent default browser form submit
      event.preventDefault()
      # Get value from form element
      text = event.target.text.value
      # Insert a task into the collection
      Meteor.call 'addTask', text
      # Clear form
      event.target.text.value = ''
      return
    'change .hide-completed input': (event) ->
      Session.set 'hideCompleted', event.target.checked
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
    'click .toggle-private': ->
      Meteor.call 'setPrivate', @_id, !@private
      return

  Accounts.ui.config passwordSignupFields: 'USERNAME_ONLY'

Meteor.methods
  addTask: (text) ->
    # Make sure the user is logged in before inserting a task
    if !Meteor.userId()
      throw new (Meteor.Error)('not-authorized')
    Tasks.insert
      text: text
      createdAt: new Date
      owner: Meteor.userId()
      username: Meteor.user().username
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
