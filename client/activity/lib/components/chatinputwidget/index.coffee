kd              = require 'kd'
React           = require 'kd-react'
TextArea        = require 'react-autosize-textarea'
EmojiDropup     = require 'activity/components/emojidropup'
ChannelDropup   = require 'activity/components/channeldropup'
EmojiSelector   = require 'activity/components/emojiselector'
ActivityFlux    = require 'activity/flux'
KDReactorMixin  = require 'app/flux/reactormixin'
formatEmojiName = require 'activity/util/formatEmojiName'
Link            = require 'app/components/common/link'
helpers         = require './helpers'

module.exports = class ChatInputWidget extends React.Component

  TAB         = 9
  ENTER       = 13
  ESC         = 27
  LEFT_ARROW  = 37
  UP_ARROW    = 38
  RIGHT_ARROW = 39
  DOWN_ARROW  = 40


  constructor: (props) ->

    super props

    @state = { value : '' }


  getDataBindings: ->

    { getters } = ActivityFlux

    return {
      filteredEmojiList              : getters.filteredEmojiList
      filteredEmojiListSelectedItem  : getters.filteredEmojiListSelectedItem
      filteredEmojiListQuery         : getters.filteredEmojiListQuery
      commonEmojiList                : getters.commonEmojiList
      commonEmojiListFlags           : getters.commonEmojiListFlags
      commonEmojiListSelectedItem    : getters.commonEmojiListSelectedItem
      channels                       : getters.chatInputChannes
      channelsSelectedItem           : getters.chatInputChannelsSelectedItem
      channelsQuery                  : getters.chatInputChannelsQuery
    }


  getDropups: -> [ @refs.emojiDropup, @refs.channelDropup ]


  onChange: (event) ->

    value = event.target.value
    @setState { value }

    textInput   = React.findDOMNode @refs.textInput
    dropupQuery = helpers.getDropupQuery textInput

    @getDropups().forEach (dropup) ->
      dropup.setQuery dropupQuery


  onKeyDown: (event) ->

    switch event.which
      when ENTER
        @onEnter event
      when ESC
        @onEsc event
      when RIGHT_ARROW, DOWN_ARROW, TAB
        @onNextPosition event
      when LEFT_ARROW, UP_ARROW
        @onPrevPosition event


  onEnter: (event) ->

    return  if event.shiftKey

    isDropupEnter = no
    @getDropups().forEach (dropup) ->
      if dropup.isActive()
        dropup.confirmSelectedItem()
        kd.utils.stopDOMEvent event
        isDropupEnter = yes

    unless isDropupEnter
      kd.utils.stopDOMEvent event
      @props.onSubmit? { value: @state.value }
      @setState { value: '' }


  onEsc: (event) ->

    @getDropups().forEach (dropup) ->
      dropup.clearQuery()  if dropup.isActive()


  onNextPosition: (event) ->

    @getDropups().forEach (dropup) ->
      if dropup.isActive()
        stopEvent = dropup.moveToNextPosition()
        kd.utils.stopDOMEvent event  if stopEvent


  onPrevPosition: (event) ->

    @getDropups().forEach (dropup) ->
      if dropup.isActive()
        stopEvent = dropup.moveToPrevPosition()
        kd.utils.stopDOMEvent event  if stopEvent


  onDropupItemConfirmed: (item) ->

    textInput = React.findDOMNode @refs.textInput

    { value, cursorPosition } = helpers.insertDropupItem textInput, item
    @setState { value }

    kd.utils.defer ->
      helpers.setCursorPosition textInput, cursorPosition


  onEmojiSelectorItemConfirmed: ->

    { commonEmojiListSelectedItem, value } = @state

    newValue = value + formatEmojiName commonEmojiListSelectedItem
    @setState { value : newValue }

    textInput = React.findDOMNode this.refs.textInput
    textInput.focus()

    ActivityFlux.actions.emoji.resetCommonListFlags()


  handleEmojiButtonClick: (event) ->

    ActivityFlux.actions.emoji.setCommonListVisibility yes


  renderEmojiDropup: ->

    { filteredEmojiList, filteredEmojiListSelectedItem, filteredEmojiListQuery } = @state

    <EmojiDropup
      items           = { filteredEmojiList }
      selectedItem    = { filteredEmojiListSelectedItem }
      query           = { filteredEmojiListQuery }
      onItemConfirmed = { @bound 'onDropupItemConfirmed' }
      ref             = 'emojiDropup'
    />


  renderEmojiSelector: ->

    { commonEmojiList, commonEmojiListFlags, commonEmojiListSelectedItem } = @state

    <EmojiSelector
      emojis          = { commonEmojiList }
      visible         = { commonEmojiListFlags.get 'visible' }
      selectedEmoji   = { commonEmojiListSelectedItem }
      onItemConfirmed = { @bound 'onEmojiSelectorItemConfirmed' }
    />


  renderChannelDropup: ->

    { channels, channelsSelectedItem, channelsQuery } = @state

    <ChannelDropup
      items           = { channels }
      selectedItem    = { channelsSelectedItem }
      query           = { channelsQuery }
      onItemConfirmed = { @bound 'onDropupItemConfirmed' }
      ref             = 'channelDropup'
    />


  render: ->

    <div className="ChatInputWidget">
      { @renderEmojiSelector() }
      { @renderEmojiDropup() }
      { @renderChannelDropup() }
      <TextArea
        value     = { @state.value }
        onChange  = { @bound 'onChange' }
        onKeyDown = { @bound 'onKeyDown' }
        ref       = 'textInput'
      />
      <Link
        className = "ChatInputWidget-emojiButton"
        onClick   = { @bound 'handleEmojiButtonClick' }
      />
    </div>


React.Component.include.call ChatInputWidget, [KDReactorMixin]