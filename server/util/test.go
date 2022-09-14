package util

import "github.com/mattermost/mattermost-server/v6/model"

func EmptyAppError() *model.AppError {
	return model.NewAppError("", "", nil, "", 0)
}
