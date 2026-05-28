package graph

import (
	"context"
	"fmt"

	"github.com/ai-o11y/backend/data"
	"github.com/ai-o11y/backend/graph/model"
)

// UserResolver resolves the user query.
func (r *Resolver) User(ctx context.Context, email string) (*model.User, error) {
	user, err := data.GetUserByEmail(email)
	if err != nil {
		return nil, fmt.Errorf("user not found")
	}
	return user, nil
}
