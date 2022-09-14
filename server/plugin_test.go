package main

import (
	"errors"
	"io/ioutil"
	"testing"

	"bou.ke/monkey"
	"github.com/mattermost/mattermost-server/v6/model"
	"github.com/mattermost/mattermost-server/v6/plugin/plugintest"
	"github.com/stretchr/testify/assert"

	"github.com/standup-raven/standup-raven/server/config"
)

func TearDown() {
	monkey.UnpatchAll()
}

func TestSetUpBot(t *testing.T) {
	defer TearDown()
	bot := &model.Bot{
		Username:    config.BotUsername,
		DisplayName: config.BotDisplayName,
		Description: "Bot for Standup Raven.",
	}
	p := &Plugin{}
	api := &plugintest.API{}
	api.On("EnsureBotUserUser", bot).Return("botID", nil)
	api.On("GetBundlePath").Return("tmp/", nil)
	monkey.Patch(ioutil.ReadFile, func(filename string) ([]byte, error) {
		return []byte{}, nil
	})
	api.On("SetProfileImage", "botID", []byte{}).Return(nil)
	p.SetAPI(api)
	_, err := p.setUpBot()
	assert.Nil(t, err, "no error should have been produced")
}

func TestSetUpBot_EnsureBotUser_Error(t *testing.T) {
	defer TearDown()
	bot := &model.Bot{
		Username:    config.BotUsername,
		DisplayName: config.BotDisplayName,
		Description: "Bot for Standup Raven.",
	}
	p := &Plugin{}
	api := &plugintest.API{}
	api.On("EnsureBotUser", bot).Return("", errors.New(""))
	p.SetAPI(api)

	_, err := p.setUpBot()
	assert.NotNil(t, err)
}

func TestSetUpBot_GetBundlePath_Error(t *testing.T) {
	defer TearDown()
	bot := &model.Bot{
		Username:    config.BotUsername,
		DisplayName: config.BotDisplayName,
		Description: "Bot for Standup Raven.",
	}
	p := &Plugin{}
	api := &plugintest.API{}
	api.On("EnsureBotUser", bot).Return("botID", nil)
	api.On("GetBundlePath").Return("", errors.New(""))
	p.SetAPI(api)
	_, err := p.setUpBot()
	assert.NotNil(t, err)
}

func TestSetUpBot_Readfile_Error(t *testing.T) {
	defer TearDown()
	bot := &model.Bot{
		Username:    config.BotUsername,
		DisplayName: config.BotDisplayName,
		Description: "Bot for Standup Raven.",
	}
	p := &Plugin{}
	api := &plugintest.API{}
	api.On("EnsureBotUser", bot).Return("botID", nil)
	api.On("GetBundlePath").Return("tmp/", nil)
	p.SetAPI(api)
	monkey.Patch(ioutil.ReadFile, func(filename string) ([]byte, error) {
		return nil, errors.New("")
	})
	_, err := p.setUpBot()
	assert.NotNil(t, err)
}

func TestSetUpBot_SetProfileImage_Error(t *testing.T) {
	defer TearDown()
	bot := &model.Bot{
		Username:    config.BotUsername,
		DisplayName: config.BotDisplayName,
		Description: "Bot for Standup Raven.",
	}
	p := &Plugin{}
	api := &plugintest.API{}
	api.On("EnsureBotUser", bot).Return("botID", nil)
	api.On("GetBundlePath").Return("tmp/", nil)
	monkey.Patch(ioutil.ReadFile, func(filename string) ([]byte, error) {
		return []byte{}, nil
	})
	api.On("SetProfileImage", "botID", []byte{}).Return(&model.AppError{})
	p.SetAPI(api)
	_, err := p.setUpBot()
	assert.NotNil(t, err)
}
