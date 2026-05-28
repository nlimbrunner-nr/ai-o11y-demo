package data

import (
	"encoding/json"
	"fmt"

	_ "embed"

	"github.com/ai-o11y/backend/graph/model"
)

//go:embed users.json
var usersJSON []byte

var usersByEmail map[string]*model.User

func init() {
	var users []*model.User
	if err := json.Unmarshal(usersJSON, &users); err != nil {
		panic(fmt.Sprintf("data: failed to parse users.json: %v", err))
	}
	usersByEmail = make(map[string]*model.User, len(users))
	for _, u := range users {
		usersByEmail[u.Email] = u
	}
}

// GetUserByEmail returns the user with the given email, or an error if not found.
func GetUserByEmail(email string) (*model.User, error) {
	u, ok := usersByEmail[email]
	if !ok {
		return nil, fmt.Errorf("user not found: %s", email)
	}
	return u, nil
}
